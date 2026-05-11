import Foundation

/// 基线管理：保存和对比审查结果
struct BaselineManager: Sendable {
    private let baseDir: String

    init(baseDir: String = "~/.macaudit/reports") {
        self.baseDir = (baseDir as NSString).expandingTildeInPath
    }

    /// 确保目录存在
    private func ensureDir() throws {
        try FileManager.default.createDirectory(
            atPath: baseDir,
            withIntermediateDirectories: true
        )
    }

    /// 保存结果 JSON 到时间戳文件
    func save(_ jsonString: String) throws -> String {
        try ensureDir()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "audit_\(formatter.string(from: Date())).json"
        let path = "\(baseDir)/\(filename)"
        try jsonString.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// 获取最近的报告路径
    func lastReport() -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return nil
        }
        let jsonFiles = files.filter { $0.hasPrefix("audit_") && $0.hasSuffix(".json") }.sorted()
        guard let last = jsonFiles.last else { return nil }
        return "\(baseDir)/\(last)"
    }

    /// 获取倒数第二个报告（用于 diff）
    func previousReport() -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return nil
        }
        let jsonFiles = files.filter { $0.hasPrefix("audit_") && $0.hasSuffix(".json") }.sorted()
        guard jsonFiles.count >= 2 else { return nil }
        return "\(baseDir)/\(jsonFiles[jsonFiles.count - 2])"
    }

    /// 对比两个报告
    static func diff(oldPath: String, newPath: String) -> DiffReport? {
        guard let oldData = FileManager.default.contents(atPath: oldPath),
              let newData = FileManager.default.contents(atPath: newPath),
              let oldJson = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any],
              let newJson = try? JSONSerialization.jsonObject(with: newData) as? [String: Any],
              let oldResults = oldJson["results"] as? [[String: Any]],
              let newResults = newJson["results"] as? [[String: Any]]
        else { return nil }

        // 按 checkId 建立索引
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

        // 新增和删除的检查项
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

    /// 报告列表
    func listReports() -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: baseDir) else {
            return []
        }
        return files.filter { $0.hasPrefix("audit_") && $0.hasSuffix(".json") }.sorted()
    }
}

/// Diff 报告
struct DiffReport: Sendable {
    let oldTotal: Int
    let newTotal: Int
    let fixed: [(String, String)]       // 修复的 (id, name)
    let regressed: [(String, String)]   // 退化的
    let changed: [(String, String, String, String)] // (id, name, old, new)
    let added: Int
    let removed: Int

    var hasChanges: Bool {
        !fixed.isEmpty || !regressed.isEmpty || !changed.isEmpty || added > 0 || removed > 0
    }

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
}
