// InteractiveUI.swift
// 终端交互 UI 工具 — 负责审查过程中的实时输出，
// 包括进度条、模块标题、单项结果、模块摘要和总体摘要。

import Foundation

/// 终端交互 UI 工具集，提供审查过程的格式化输出
struct InteractiveUI: Sendable {

    /// 打印/刷新进度条（覆盖当前行，仅终端环境生效）
    /// - Parameters:
    ///   - module: 当前模块名称
    ///   - current: 已完成数量
    ///   - total: 总数量
    static func updateProgress(module: String, current: Int, total: Int) {
        guard ANSIColor.isTerminal else { return }
        let pct = total > 0 ? current * 100 / total : 0
        let barWidth = 20
        let filled = total > 0 ? current * barWidth / total : 0
        let empty = barWidth - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        let line = "[\(bar)] \(pct)%  \(module) (\(current)/\(total))"
        print("\r\u{001B}[2K\(Layout.margin)\(ANSIColor.bold.wrap(line))", terminator: "")
        fflush(stdout)
    }

    /// 清除进度条行（仅终端环境生效）
    static func clearProgress() {
        guard ANSIColor.isTerminal else { return }
        print("\r\u{001B}[2K", terminator: "")
        fflush(stdout)
    }

    /// 打印模块开始标题（分隔线 + 模块名 + 检测项数量）
    /// - Parameters:
    ///   - module: 审计模块
    ///   - checkCount: 该模块适用的检测项数量
    static func printModuleHeader(_ module: any AuditModule, checkCount: Int) {
        Layout.printEmpty()
        Layout.printLine()
        Layout.print(ANSIColor.bold.wrap("\(module.name) (\(checkCount) 项)"))
        Layout.printLine()
    }

    /// 打印单项检测结果，包含状态符号、风险等级、检测项名和当前值
    /// - 自动根据终端宽度截断过长的值
    /// - Parameter result: 单条审计结果
    static func printResult(_ result: AuditResult) {
        let symbolStr = result.status.symbol        // 可见符号，1–2 宽
        let riskLabel = "[\(result.riskLevel.label)]"  // [SAFE] / [MEDIUM] 等
        let rawValue: String
        switch result.status {
        case .pass:  rawValue = result.actualValue ?? "OK"
        case .fail:  rawValue = result.actualValue ?? "FAIL"
        case .warn:  rawValue = result.actualValue ?? "WARN"
        case .info:  rawValue = result.actualValue ?? ""
        case .skip:  rawValue = "跳过"
        case .error: rawValue = result.error ?? "未知错误"
        }

        // MARK: - 计算显示宽度与截断

        let prefixWidth = Layout.displayWidth(symbolStr) + 1
                        + Layout.displayWidth(riskLabel) + 1
                        + Layout.displayWidth(result.checkName) + 2
        // 留 4 字符安全边距
        let maxValueWidth = max(4, Layout.terminalWidth - prefixWidth - 4)

        // 截断 value
        var valueW = 0
        var valueStr = ""
        for ch in rawValue {
            let w = Layout.displayWidth(String(ch))
            if valueW + w > maxValueWidth { valueStr += "…"; break }
            valueStr += String(ch); valueW += w
        }

        let symbol = result.status.color.wrap(symbolStr)
        let risk   = result.riskLevel.color.wrap(riskLabel)
        let value: String
        switch result.status {
        case .pass:  value = ANSIColor.green.wrap(valueStr)
        case .fail:  value = ANSIColor.red.wrap(valueStr)
        case .warn:  value = ANSIColor.yellow.wrap(valueStr)
        case .info:  value = ANSIColor.blue.wrap(valueStr)
        case .skip:  value = ANSIColor.dim.wrap(valueStr)
        case .error: value = ANSIColor.red.wrap(valueStr)
        }
        Swift.print("\(symbol) \(risk) \(result.checkName): \(value)")
    }

    static func printResultsPaged(_ results: [AuditResult], interactive: Bool) {
        guard interactive, ANSIColor.isTerminal else {
            for r in results { printResult(r) }
            return
        }
        let pageSize = max(5, Layout.terminalHeight - 8)
        for (i, result) in results.enumerated() {
            printResult(result)
            if (i + 1) % pageSize == 0 && i + 1 < results.count {
                let remaining = results.count - i - 1
                Layout.printNoNL(ANSIColor.dim.wrap("  ▼ 还有 \(remaining) 项，按 Enter 继续..."))
                TerminalInput.enableRawMode()
                _ = TerminalInput.readKey()
                // 排空输入缓冲区，防止多余按键穿透到下一层交互
                while true {
                    var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
                    guard poll(&pfd, 1, 0) > 0 else { break }
                    var discard: UInt8 = 0
                    _ = Darwin.read(STDIN_FILENO, &discard, 1)
                }
                TerminalInput.disableRawMode()
                Swift.print("\r\u{001B}[2K", terminator: "")
                fflush(stdout)
            }
        }
    }

    /// 打印模块摘要（通过/失败/警告/跳过/信息/错误的分项统计）
    /// - Parameter results: 该模块的审计结果数组
    static func printModuleSummary(_ results: [AuditResult]) {
        let pass = results.filter { $0.status == .pass }.count
        let fail = results.filter { $0.status == .fail }.count
        let warn = results.filter { $0.status == .warn }.count
        let skip = results.filter { $0.status == .skip }.count
        let info = results.filter { $0.status == .info }.count
        let err = results.filter { $0.status == .error }.count

        var parts: [String] = []
        if pass > 0 { parts.append(ANSIColor.green.wrap("\(pass) 通过")) }
        if fail > 0 { parts.append(ANSIColor.red.wrap("\(fail) 失败")) }
        if warn > 0 { parts.append(ANSIColor.yellow.wrap("\(warn) 警告")) }
        if info > 0 { parts.append(ANSIColor.blue.wrap("\(info) 信息")) }
        if skip > 0 { parts.append(ANSIColor.dim.wrap("\(skip) 跳过")) }
        if err > 0 { parts.append(ANSIColor.orange.wrap("\(err) 错误")) }
        Layout.printLine("─")
        Layout.print("摘要: \(parts.joined(separator: " | "))")
    }

    /// 打印总体摘要（总计/通过/失败/警告/耗时）
    /// - Parameters:
    ///   - allResults: 全部审计结果
    ///   - duration: 审计总耗时
    static func printOverallSummary(
        _ allResults: [AuditResult],
        duration: Duration
    ) {
        let total = allResults.count
        let pass = allResults.filter { $0.status == .pass }.count
        let fail = allResults.filter { $0.status == .fail }.count
        let warn = allResults.filter { $0.status == .warn }.count

        Layout.printEmpty()
        Layout.printDoubleLine()
        Layout.print(ANSIColor.bold.wrap("审查完成"))
        Layout.printDoubleLine()
        Layout.print("总计: \(total) 项检测")
        Layout.print("通过: \(ANSIColor.green.wrap("\(pass)"))")
        if fail > 0 { Layout.print("失败: \(ANSIColor.red.wrap("\(fail)"))") }
        if warn > 0 { Layout.print("警告: \(ANSIColor.yellow.wrap("\(warn)"))") }
        let seconds = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
        Layout.print("耗时: \(String(format: "%.1f", seconds)) 秒")
        Layout.printEmpty()
    }

    /// 打印未通过项汇总（失败/警告/错误按严重度排列）
    /// - Parameter allResults: 全部审计结果
    static func printFailureSummary(_ allResults: [AuditResult]) {
        let failures = allResults.filter { $0.status == .fail }
        let warnings = allResults.filter { $0.status == .warn }
        let errors = allResults.filter { $0.status == .error }

        let total = failures.count + warnings.count + errors.count
        guard total > 0 else {
            Layout.print(ANSIColor.green.wrap("✓ 所有检测项均已通过"))
            Layout.printEmpty()
            return
        }

        Layout.printDoubleLine()
        Layout.print(ANSIColor.bold.wrap("未通过项汇总 (\(total) 项)"))
        Layout.printDoubleLine()
        Layout.printEmpty()

        let sortedFailures = failures.sorted { $0.riskLevel > $1.riskLevel }

        if !sortedFailures.isEmpty {
            Layout.printSection("失败 (\(sortedFailures.count) 项)")
            for r in sortedFailures {
                let riskLabel = "[\(r.riskLevel.label)]"
                let actual = r.actualValue ?? "N/A"
                let expected = r.expectedValue ?? ""
                let detail = expected.isEmpty ? actual : "\(actual) (期望: \(expected))"
                let prefixWidth = Layout.displayWidth("✗") + 1
                              + Layout.displayWidth(riskLabel) + 1
                              + Layout.displayWidth(r.checkName) + 2
                let maxDetailW = max(4, Layout.terminalWidth - prefixWidth - 4)
                var detailW = 0; var detailStr = ""
                for ch in detail {
                    let w = Layout.displayWidth(String(ch))
                    if detailW + w > maxDetailW { detailStr += "…"; break }
                    detailStr += String(ch); detailW += w
                }
                let risk = r.riskLevel.color.wrap(riskLabel)
                Swift.print("\(ANSIColor.red.wrap("✗")) \(risk) \(r.checkName): \(detailStr)")
            }
            Layout.printEmpty()
        }

        if !warnings.isEmpty {
            Layout.printSection("警告 (\(warnings.count) 项)")
            for r in warnings.sorted(by: { $0.riskLevel > $1.riskLevel }) {
                let riskLabel = "[\(r.riskLevel.label)]"
                let rawVal = r.actualValue ?? "N/A"
                let prefixWidth = Layout.displayWidth("!") + 1
                              + Layout.displayWidth(riskLabel) + 1
                              + Layout.displayWidth(r.checkName) + 2
                let maxValW = max(4, Layout.terminalWidth - prefixWidth - 4)
                var valW = 0; var valStr = ""
                for ch in rawVal {
                    let w = Layout.displayWidth(String(ch))
                    if valW + w > maxValW { valStr += "…"; break }
                    valStr += String(ch); valW += w
                }
                let risk = r.riskLevel.color.wrap(riskLabel)
                Swift.print("\(ANSIColor.yellow.wrap("!")) \(risk) \(r.checkName): \(valStr)")
            }
            Layout.printEmpty()
        }

        if !errors.isEmpty {
            Layout.printSection("错误 (\(errors.count) 项)")
            for r in errors {
                Layout.print("\(ANSIColor.orange.wrap("?")) \(r.checkName): \(r.error ?? "未知")")
            }
            Layout.printEmpty()
        }
    }
}
