// ReportGenerator.swift
// 报告生成器 — 将审计结果转换为 Markdown 或 JSON 格式报告，
// 包含系统信息、分模块详情、统计摘要和可修复项列表。

import Foundation

/// 报告生成器，支持 Markdown 和 JSON 两种输出格式
struct ReportGenerator: Sendable {

    /// 生成 Markdown 格式的审查报告
    /// - Parameters:
    ///   - results: 审计结果数组
    ///   - modules: 审计模块列表
    ///   - version: macOS 版本
    ///   - device: 设备类型
    ///   - duration: 审计总耗时
    /// - Returns: Markdown 格式的报告字符串
    static func generateMarkdown(
        results: [AuditResult],
        modules: [any AuditModule],
        version: MacOSVersion?,
        device: DeviceType,
        duration: Duration
    ) -> String {
        var md = ""
        let now = ISO8601DateFormatter().string(from: Date())

        md += "# MacAudit 系统审查报告\n\n"
        md += "| 项目 | 值 |\n|------|----|\n"
        md += "| 生成时间 | \(now) |\n"
        md += "| 系统版本 | \(version?.displayName ?? "未知") (\(MacOSVersion.versionString)) |\n"
        md += "| 设备类型 | \(device.displayName) |\n"
        md += "| MacAudit | v0.2.13 |\n\n"

        // MARK: - 总摘要

        let total = results.count
        let pass = results.filter { $0.status == .pass }.count
        let fail = results.filter { $0.status == .fail }.count
        let warn = results.filter { $0.status == .warn }.count
        let info = results.filter { $0.status == .info }.count
        let skip = results.filter { $0.status == .skip }.count
        let err = results.filter { $0.status == .error }.count
        let secs = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18

        md += "## 摘要\n\n"
        md += "| 指标 | 数量 |\n|------|:----:|\n"
        md += "| 总计 | \(total) |\n"
        md += "| 通过 | \(pass) |\n"
        md += "| 失败 | \(fail) |\n"
        md += "| 警告 | \(warn) |\n"
        md += "| 信息 | \(info) |\n"
        md += "| 跳过 | \(skip) |\n"
        md += "| 错误 | \(err) |\n"
        md += "| 耗时 | \(String(format: "%.1f", secs))s |\n\n"

        // MARK: - 按模块分组

        // 按模块 ID 分组（使用 AuditResult.moduleId，无需硬编码映射）
        let grouped = Dictionary(grouping: results) { $0.moduleId }

        for module in modules {
            guard let moduleResults = grouped[module.id], !moduleResults.isEmpty else { continue }

            let mFail = moduleResults.filter { $0.status == .fail }.count
            let mWarn = moduleResults.filter { $0.status == .warn }.count

            md += "## \(module.name) (\(moduleResults.count) 项"
            if mFail > 0 { md += ", \(mFail) 失败" }
            if mWarn > 0 { md += ", \(mWarn) 警告" }
            md += ")\n\n"

            md += "| 状态 | 风险 | 检测项 | 值 |\n"
            md += "|:----:|:----:|--------|----|\n"

            for r in moduleResults {
                let status = r.status.symbol
                let risk = r.riskLevel.label
                let val = (r.actualValue ?? r.error ?? "N/A")
                    .replacingOccurrences(of: "|", with: "\\|")
                    .replacingOccurrences(of: "\n", with: " ")
                md += "| \(status) | \(risk) | \(r.checkName) | \(val) |\n"
            }
            md += "\n"
        }

        // MARK: - 可修复项摘要

        // fail 状态且有期望值的项
        let fixable = results.filter { $0.status == .fail && $0.expectedValue != nil }
        if !fixable.isEmpty {
            md += "## 可修复项摘要\n\n"
            md += "> 使用 `macaudit --fix` 自动修复 safe/low 风险项，或使用交互式菜单进行分级优化。\n\n"
            md += "| 模块 | 检测项 | 实际值 | 期望值 |\n"
            md += "|------|--------|--------|--------|\n"
            for r in fixable.sorted(by: { $0.riskLevel > $1.riskLevel }) {
                let actual = (r.actualValue ?? "N/A")
                    .replacingOccurrences(of: "|", with: "\\|")
                    .replacingOccurrences(of: "\n", with: " ")
                let expected = (r.expectedValue ?? "")
                    .replacingOccurrences(of: "|", with: "\\|")
                md += "| \(r.moduleId) | \(r.checkName) | \(actual) | \(expected) |\n"
            }
            md += "\n"
        }

        return md
    }

    /// 生成 JSON 格式的审查报告
    /// - Parameters:
    ///   - results: 审计结果数组
    ///   - modules: 审计模块列表
    ///   - version: macOS 版本
    ///   - device: 设备类型
    ///   - duration: 审计总耗时
    ///   - diffJSON: 可选的 Diff 报告 JSON（会嵌入到输出中）
    /// - Returns: JSON 格式的报告字符串
    static func generateJSON(
        results: [AuditResult],
        modules: [any AuditModule],
        version: MacOSVersion?,
        device: DeviceType,
        duration: Duration,
        diffJSON: String? = nil
    ) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let secs = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18

        let systemDict: [String: Any] = [
            "macosVersion": MacOSVersion.versionString,
            "macosName": version?.rawValue ?? "unknown",
            "deviceType": device.rawValue,
        ]

        let summaryDict: [String: Any] = [
            "total": results.count,
            "pass": results.filter { $0.status == .pass }.count,
            "fail": results.filter { $0.status == .fail }.count,
            "warn": results.filter { $0.status == .warn }.count,
            "info": results.filter { $0.status == .info }.count,
            "skip": results.filter { $0.status == .skip }.count,
            "error": results.filter { $0.status == .error }.count,
            "durationSeconds": round(secs * 10) / 10,
        ]

        let resultsArray: [[String: Any]] = results.map { r in
            var item: [String: Any] = [
                "checkId": r.checkId,
                "name": r.checkName,
                "moduleId": r.moduleId,
                "status": r.status.rawValue,
                "riskLevel": r.riskLevel.label.lowercased(),
                "message": r.message,
            ]
            if let actual = r.actualValue { item["actualValue"] = actual }
            if let expected = r.expectedValue { item["expectedValue"] = expected }
            if let error = r.error { item["error"] = error }
            return item
        }

        var dict: [String: Any] = [
            "version": "0.2.13",
            "timestamp": now,
            "system": systemDict,
            "summary": summaryDict,
            "results": resultsArray,
        ]

        if let diffJSON {
            if let diffData = diffJSON.data(using: .utf8),
               let diffObj = try? JSONSerialization.jsonObject(with: diffData) as? [String: Any] {
                dict["diff"] = diffObj
            }
        }

        // 手动序列化（避免 JSONSerialization 排序问题）
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// 将内容写入文件（自动展开 ~ 路径，原子写入）
    /// - Parameters:
    ///   - content: 文件内容
    ///   - path: 目标路径（支持 ~ 前缀）
    static func writeToFile(_ content: String, path: String) throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
