// BaselineManager.swift
// 基线管理 — 保存审查结果快照，支持跨版本对比（diff），
// 用于追踪系统安全状态的变化趋势。

import Foundation

/// 基线管理器：保存和对比审查结果，追踪安全状态变化
struct BaselineManager: Sendable {
    /// 报告存储根目录（已展开 ~）
    private let baseDir: String

    /// 初始化基线管理器
    /// - Parameter baseDir: 报告存储目录，默认 ~/.macaudit/reports
    init(baseDir: String = "~/.macaudit/reports") {
        self.baseDir = (baseDir as NSString).expandingTildeInPath
    }

    /// 确保报告存储目录存在，不存在则递归创建
    private func ensureDir() throws {
        try FileManager.default.createDirectory(
            atPath: baseDir,
            withIntermediateDirectories: true
        )
    }

    /// 将审查结果 JSON 保存为带时间戳的文件，返回文件完整路径
    /// - Parameter jsonString: 审查结果的 JSON 字符串
    /// - Returns: 保存的文件路径
    func save(_ jsonString: String) throws -> String {
        try ensureDir()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "audit_\(formatter.string(from: Date())).json"
        let path = "\(baseDir)/\(filename)"
        try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// 获取最近一次报告的完整路径
    func lastReport() -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return nil
        }
        let jsonFiles = files.filter { $0.hasPrefix("audit_") && $0.hasSuffix(".json") }.sorted()
        guard let last = jsonFiles.last else { return nil }
        return "\(baseDir)/\(last)"
    }

    /// 获取倒数第二个报告路径（用于 diff 对比）
    func previousReport() -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return nil
        }
        let jsonFiles = files.filter { $0.hasPrefix("audit_") && $0.hasSuffix(".json") }.sorted()
        guard jsonFiles.count >= 2 else { return nil }
        return "\(baseDir)/\(jsonFiles[jsonFiles.count - 2])"
    }

    /// 对比两份报告，识别修复、退化和状态变化
    /// - Parameters:
    ///   - oldPath: 旧报告文件路径
    ///   - newPath: 新报告文件路径
    /// - Returns: DiffReport，解析失败返回 nil
    static func diff(oldPath: String, newPath: String) -> DiffReport? {
        guard let oldData = FileManager.default.contents(atPath: oldPath),
              let newData = FileManager.default.contents(atPath: newPath),
              let oldJson = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any],
              let newJson = try? JSONSerialization.jsonObject(with: newData) as? [String: Any],
              let oldResults = oldJson["results"] as? [[String: Any]],
              let newResults = newJson["results"] as? [[String: Any]]
        else { return nil }

        // MARK: - 按 checkId 建立索引

        let oldMap = Dictionary(uniqueKeysWithValues:
            oldResults.compactMap { r -> (String, String)? in
                guard let id = r["checkId"] as? String,
                      let status = r["status"] as? String else { return nil }
                return (id, status)
            })
        let newMap = Dictionary(uniqueKeysWithValues:
            newResults.compactMap { r -> (String, String)? in
                guard let id = r["checkId"] as? String,
                      let status = r["status"] as? String else { return nil }
                return (id, status)
            })

        var fixed: [(String, String)] = []     // (checkId, name) 从 fail → pass
        var regressed: [(String, String)] = []  // 从 pass → fail
        var changed: [(String, String, String, String)] = [] // (id, name, old, new)

        let newNames = Dictionary(uniqueKeysWithValues:
            newResults.compactMap { r -> (String, String)? in
                guard let id = r["checkId"] as? String,
                      let name = r["name"] as? String else { return nil }
                return (id, name)
            })

        for (id, newStatus) in newMap {
            let name = newNames[id] ?? id
            guard let oldStatus = oldMap[id] else { continue }
            if oldStatus == newStatus { continue }

            if oldStatus == "fail" && newStatus == "pass" {
                fixed.append((id, name))
            } else if oldStatus == "pass" && newStatus == "fail" {
                regressed.append((id, name))
            } else if oldStatus != newStatus {
                changed.append((id, name, oldStatus, newStatus))
            }
        }

        // MARK: - 新增和删除的检查项

        let added = Set(newMap.keys).subtracting(oldMap.keys)
        let removed = Set(oldMap.keys).subtracting(newMap.keys)

        let oldSummary = oldJson["summary"] as? [String: Any]
        let newSummary = newJson["summary"] as? [String: Any]

        return DiffReport(
            oldTotal: oldSummary?["total"] as? Int ?? 0,
            newTotal: newSummary?["total"] as? Int ?? 0,
            fixed: fixed,
            regressed: regressed,
            changed: changed,
            added: added.count,
            removed: removed.count
        )
    }

    /// 列出所有已保存的报告文件名（按时间排序）
    func listReports() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return []
        }
        return files.filter { $0.hasPrefix("audit_") && $0.hasSuffix(".json") }.sorted()
    }
}

/// Diff 报告，记录两次审查之间的状态变化
struct DiffReport: Sendable {
    /// 旧报告检测项总数
    let oldTotal: Int
    /// 新报告检测项总数
    let newTotal: Int
    /// 修复的 (checkId, name) 从 fail -> pass
    let fixed: [(String, String)]
    /// 退化的 (checkId, name) 从 pass -> fail
    let regressed: [(String, String)]
    /// 其他状态变化的 (id, name, oldStatus, newStatus)
    let changed: [(String, String, String, String)]
    /// 新增检测项数量
    let added: Int
    /// 移除检测项数量
    let removed: Int

    /// 是否存在任何变化
    var hasChanges: Bool {
        !fixed.isEmpty || !regressed.isEmpty || !changed.isEmpty || added > 0 || removed > 0
    }

    /// 将 Diff 报告格式化输出到终端
    func printReport() {
        Layout.print(ANSIColor.bold.wrap("\n  === Diff 报告 ===\n"))

        if !hasChanges {
            Layout.print(ANSIColor.green.wrap("  无变化"))
            return
        }

        if oldTotal != newTotal {
            Layout.print("  检测项: \(oldTotal) → \(newTotal)")
        }
        if added > 0 { print("  新增: \(added) 项") }
        if removed > 0 { print("  移除: \(removed) 项") }

        if !fixed.isEmpty {
            Layout.print(ANSIColor.green.wrap("\n  修复 (\(fixed.count) 项):"))
            for (_, name) in fixed {
                Layout.print(ANSIColor.green.wrap("    ✓ \(name)"))
            }
        }

        if !regressed.isEmpty {
            Layout.print(ANSIColor.red.wrap("\n  退化 (\(regressed.count) 项):"))
            for (_, name) in regressed {
                Layout.print(ANSIColor.red.wrap("    ✗ \(name)"))
            }
        }

        if !changed.isEmpty {
            Layout.print(ANSIColor.yellow.wrap("\n  状态变化 (\(changed.count) 项):"))
            for (_, name, old, new) in changed {
                Layout.print(ANSIColor.yellow.wrap("    ! \(name): \(old) → \(new)"))
            }
        }
        Layout.printEmpty()
    }

    /// 将 Diff 报告序列化为 JSON 字符串
    func toJSON() -> String {
        let detailsDict: [String: Any] = [
            "fixed": fixed.map { ["id": $0.0, "name": $0.1] },
            "regressed": regressed.map { ["id": $0.0, "name": $0.1] },
            "changed": changed.map { ["id": $0.0, "name": $0.1, "oldStatus": $0.2, "newStatus": $0.3] },
        ]
        let dict: [String: Any] = [
            "hasChanges": hasChanges,
            "oldTotal": oldTotal,
            "newTotal": newTotal,
            "fixed": fixed.count,
            "regressed": regressed.count,
            "changed": changed.count,
            "added": added,
            "removed": removed,
            "details": detailsDict,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
