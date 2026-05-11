// FixEngine.swift
// 修复引擎 — 根据风险等级分级执行修复操作，支持自动执行（safe/low）、
// 逐条确认（medium）、手动复制（sudo）、双重确认（critical/网络风险），
// 并生成 undo 命令和历史记录以支持回滚。

import Foundation
import MacAuditCore

/// 修复操作定义，封装单条修复命令的元数据
struct FixAction: Sendable {
    /// 关联的检测项 ID
    let checkId: String
    /// 检测项名称
    let name: String
    /// 修复命令
    let command: String
    /// 风险等级
    let riskLevel: RiskLevel
    /// 是否需要 sudo 权限
    let requiresSudo: Bool
    /// 是否存在网络断开风险
    let networkRisk: Bool
    /// 操作描述文本
    let description: String

    /// 组合风险等级、sudo、网络风险的标签字符串（带 ANSI 颜色）
    var riskTag: String {
        var tag = riskLevel.color.wrap("[\(riskLevel.label)]")
        if requiresSudo { tag += ANSIColor.orange.wrap(" [SUDO]") }
        if networkRisk { tag += ANSIColor.red.wrap(" [网络风险]") }
        return tag
    }
}

/// 修复引擎 — 按风险等级分级执行修复操作，自动生成 undo 命令并记录历史
struct FixEngine: Sendable {

    /// 检测命令是否需要 sudo（支持 "sudo "、"/usr/bin/sudo "、"/usr/local/bin/sudo " 等变体）
    /// - Parameter command: 待检测的 shell 命令
    /// - Returns: 是否以 sudo 前缀开头
    static func detectsSudo(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("sudo ") { return true }
        let sudoPathPattern = #"^(?:/\S+/)?sudo(\s|$)"#
        if let regex = try? NSRegularExpression(pattern: sudoPathPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return true
        }
        return false
    }

    /// 从失败的审查结果中提取可修复项，按风险等级升序排列
    /// - Parameters:
    ///   - results: 审计结果数组
    ///   - checks: 审计检查项定义数组
    /// - Returns: 可执行的 FixAction 列表
    static func extractFixActions(from results: [AuditResult], checks: [AuditCheck]) -> [FixAction] {
        let checkMap = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
        var actions: [FixAction] = []

        for result in results where result.status == .fail {
            guard let check = checkMap[result.checkId],
                  let fixCmd = check.fixCommand,
                  let fixRisk = check.fixRiskLevel else { continue }

            actions.append(FixAction(
                checkId: check.id,
                name: check.name,
                command: fixCmd,
                riskLevel: fixRisk,
                requiresSudo: FixEngine.detectsSudo(fixCmd),
                networkRisk: check.networkRisk,
                description: "修复: \(check.name) (当前: \(result.actualValue ?? "N/A"), 期望: \(check.expectedValue ?? "N/A"))"
            ))
        }

        return actions.sorted { $0.riskLevel < $1.riskLevel }
    }

    /// 分组显示修复方案，按风险等级（safe/low/medium/high/critical）分区展示
    /// - Parameter actions: 修复操作列表
    static func printFixPlan(_ actions: [FixAction]) {
        if actions.isEmpty {
            Layout.print(ANSIColor.green.wrap("\n  无需修复 — 所有检测项均已通过或无修复命令\n"))
            return
        }

        Layout.print(ANSIColor.bold.wrap("\n  ══════════════════════════════════════════════"))
        Layout.print(ANSIColor.bold.wrap("  修复方案 (\(actions.count) 项)"))
        Layout.print(ANSIColor.bold.wrap("  ══════════════════════════════════════════════\n"))

        let grouped = Dictionary(grouping: actions) { $0.riskLevel }

        for level in RiskLevel.allCases {
            guard let group = grouped[level], !group.isEmpty else { continue }

            let header: String
            switch level {
            case .safe:
                header = "自动执行（只读，安全）"
            case .low:
                header = "一键批量执行（defaults write，可撤销）"
            case .medium:
                header = "逐条确认（影响系统行为）"
            case .high:
                header = "手动执行（需要 sudo，请复制到终端）"
            case .critical:
                header = "高危操作（可能断网，需要双重确认）"
            }

            Layout.print("  \(level.color.wrap("■")) \(ANSIColor.bold.wrap(header)) [\(group.count) 项]")
            Layout.printEmpty()

            for (i, action) in group.enumerated() {
                print("    \(i + 1). \(action.name)")
                print("       \(ANSIColor.dim.wrap(action.command))")
                if action.networkRisk {
                    print("       \(ANSIColor.red.wrap("⚠ 此命令可能导致网络断开！"))")
                }
            }
            Layout.printEmpty()
        }
    }

    /// 执行 safe + low 级别的修复（无需确认），带验证和历史记录
    /// - Parameters:
    ///   - actions: 全部修复操作列表（内部会过滤 safe/low 且非 sudo 的项）
    ///   - executor: Shell 执行器
    ///   - auditResults: 原始审计结果（用于提取当前值）
    ///   - historyBaseDir: 历史记录存储目录
    /// - Returns: 每个操作及其执行是否成功的元组数组
    static func executeSafe(
        _ actions: [FixAction],
        executor: ShellExecutor,
        auditResults: [AuditResult] = [],
        historyBaseDir: String = "~/.macaudit"
    ) async -> [(FixAction, Bool)] {
        let safeActions = actions.filter { $0.riskLevel <= .low && !$0.requiresSudo }
        var results: [(FixAction, Bool)] = []
        var records: [FixRecord] = []

        // MARK: - 建立当前值索引

        let currentValues = Dictionary(uniqueKeysWithValues:
            auditResults.compactMap { r -> (String, String)? in
                guard let v = r.actualValue else { return nil }
                return (r.checkId, v)
            })

        for action in safeActions {
            let prevValue = currentValues[action.checkId] ?? "unknown"

            let result = await executor.run(action.command)

            if result.isSuccess {
                let verifyCmd = verifyCommand(for: action)
                var verified = true
                if !verifyCmd.isEmpty {
                    let verifyResult = await executor.run(verifyCmd)
                    if !verifyResult.isSuccess || verifyResult.trimmedOutput.isEmpty {
                        verified = false
                    }
                }
                if verified {
                    Layout.print(ANSIColor.green.wrap("    ✓ \(action.name)"))
                } else {
                    Layout.print(ANSIColor.yellow.wrap("    ⚠ \(action.name) — 命令成功但值未确认"))
                }
                results.append((action, verified))

                // MARK: - 生成 undo 命令

                let undoCmd = generateUndoCommand(action: action, previousValue: prevValue)
                records.append(FixRecord(
                    checkId: action.checkId,
                    name: action.name,
                    command: action.command,
                    previousValue: prevValue,
                    newValue: {
                        let seg = action.command.components(separatedBy: " && ").first ?? action.command
                        return seg.components(separatedBy: " ").last ?? ""
                    }(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    undoCommand: undoCmd
                ))
            } else {
                results.append((action, false))
                Layout.print(ANSIColor.red.wrap("    ✗ \(action.name): \(result.stderr)"))
            }
        }

        // MARK: - 保存批次历史

        if !records.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let batch = FixBatch(
                id: "fix_\(formatter.string(from: Date()))",
                timestamp: ISO8601DateFormatter().string(from: Date()),
                records: records
            )
            do {
                try FixHistory(baseDir: historyBaseDir).saveBatch(batch)
                Layout.print(ANSIColor.dim.wrap("\n    历史已记录 (\(records.count) 项)，可用 --undo 回滚"))
            } catch {
                Layout.print(ANSIColor.yellow.wrap("\n    历史记录保存失败: \(error.localizedDescription)"))
            }
            AuditLogger.logFix(
                batchId: batch.id,
                executedResults: results.map { (checkId: $0.0.checkId, command: $0.0.command, success: $0.1, error: $0.1 ? nil : "execution failed") },
                type: "safe"
            )
        }

        return results
    }

    /// 根据修复命令生成对应的 undo 命令（internal 供测试使用）
    ///
    /// 支持 defaults write/delete 和 PlistBuddy Set/Add 两种模式的逆向生成。
    /// 对包含 shell 元字符的输入会返回 "# 无法回滚" 注释行。
    ///
    /// - Parameters:
    ///   - action: 修复操作
    ///   - previousValue: 修复前的原始值
    /// - Returns: 可执行的 undo 命令字符串
    static func generateUndoCommand(action: FixAction, previousValue: String) -> String {
        let rawCmd = action.command
        let cmd: String
        if let ampIdx = rawCmd.range(of: " && ") {
            cmd = String(rawCmd[..<ampIdx.lowerBound])
        } else {
            cmd = rawCmd
        }
        let normalizedPrev = normalizePreviousValue(previousValue)
        if normalizedPrev == "unknown" {
            return "# 无法回滚: \(action.name) (原值未记录)"
        }
        let escaped = shellEscape(normalizedPrev)
        if escaped == "''" {
            return "# 无法回滚: \(action.name) (previousValue contains dangerous characters)"
        }
        if containsShellMetacharacters(normalizedPrev) {
            return "# 无法回滚: \(action.name) (previousValue contains shell metacharacters)"
        }
        let pbPattern = #"^(sudo\s+)?/usr/libexec/PlistBuddy\s+-c\s+'(Set|Add)\s+:(\S+)\s+.*?'\s+(.+)"#
        if let regex = try? NSRegularExpression(pattern: pbPattern),
           let match = regex.firstMatch(in: cmd, range: NSRange(cmd.startIndex..., in: cmd)),
           let keyPathRange = Range(match.range(at: 3), in: cmd),
           let plistRange = Range(match.range(at: 4), in: cmd) {
            let keyPath = String(cmd[keyPathRange])
            let plist = String(cmd[plistRange]).trimmingCharacters(in: .init(charactersIn: "'\""))
            if containsShellMetacharacters(keyPath) || containsShellMetacharacters(plist) {
                return "# 无法回滚: \(action.name) (path contains dangerous characters)"
            }
            if normalizedPrev == "not set" || normalizedPrev == "N/A" {
                return "/usr/libexec/PlistBuddy -c 'Delete :\(keyPath)' \(plist)"
            }
            return "/usr/libexec/PlistBuddy -c 'Set :\(keyPath) \(escaped)' \(plist)"
        }
        let pattern = #"^(sudo\s+)?defaults\s+(write|delete)\s+(\S+)\s+(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: cmd, range: NSRange(cmd.startIndex..., in: cmd)),
              let domainRange = Range(match.range(at: 3), in: cmd),
              let keyRange = Range(match.range(at: 4), in: cmd) else {
            return "# 手动回滚: \(action.name) (原值: \(escaped))"
        }
        let domain = String(cmd[domainRange])
        let key = String(cmd[keyRange])
        if containsShellMetacharacters(domain) || containsShellMetacharacters(key) {
            return "# 无法回滚: \(action.name) (domain/key contains dangerous characters)"
        }
        if normalizedPrev == "not set" || normalizedPrev == "N/A" {
            return "defaults delete \(domain) \(key)"
        }
        let matchEnd = match.range.upperBound
        if let matchEndIdx = Range(NSRange(location: matchEnd, length: 0), in: cmd)?.lowerBound,
           matchEndIdx < cmd.endIndex {
            let remaining = String(cmd[matchEndIdx...]).trimmingCharacters(in: .whitespaces)
            if let typeRange = remaining.range(of: #"^-\w+"#, options: .regularExpression) {
                let typeFlag = String(remaining[typeRange])
                return "defaults write \(domain) \(key) \(typeFlag) \(escaped)"
            }
        }
        return "defaults write \(domain) \(key) \(escaped)"
    }

    /// Shell 转义：过滤危险字符，安全值直接返回，含特殊字符则加单引号
    /// - Parameter value: 待转义的字符串
    /// - Returns: 转义后的安全字符串，空结果返回 "''"
    static func shellEscape(_ value: String) -> String {
        let safe = value.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0...31, 0x7F...0x9F: return false
            default: break
            }
            let c = Character(scalar)
            switch c {
            case "$", "`", ";", "|", "&", ">", "<", "(", ")",
                 "{", "}", "!", "#", "~", "*", "?", "[", "]", "'":
                return false
            default:
                return true
            }
        }.map(String.init).joined()
        if safe.isEmpty {
            return "''"
        }
        if safe.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }) {
            return safe
        }
        return "'\(safe)'"
    }

    /// 检查字符串是否包含 shell 元字符（$ ` ; | & 等）
    /// - Parameter value: 待检查的字符串
    /// - Returns: 是否包含元字符
    static func containsShellMetacharacters(_ value: String) -> Bool {
        let metacharacters: Set<Character> = ["$", "`", ";", "|", "&", ">", "<", "(", ")", "{", "}", "!", "#", "~", "*", "?", "[", "]", "'", "\"", "\\"]
        return value.contains { metacharacters.contains($0) }
    }

    /// 规范化 previousValue：去除首尾空白，dict 字面量（以 { 开头）标记为 unknown
    /// - Parameter value: 原始值字符串
    /// - Returns: 规范化后的值
    static func normalizePreviousValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            return "unknown"
        }
        return trimmed
    }

    /// 根据 fixCommand 生成对应的验证命令（defaults read / PlistBuddy Print）
    /// - Parameter action: 修复操作
    /// - Returns: 验证命令字符串，无法生成时返回空字符串
    static func verifyCommand(for action: FixAction) -> String {
        let rawCmd = action.command
        let cmd: String
        if let ampIdx = rawCmd.range(of: " && ") {
            cmd = String(rawCmd[..<ampIdx.lowerBound])
        } else {
            cmd = rawCmd
        }
        let pbPattern = #"^(sudo\s+)?/usr/libexec/PlistBuddy\s+-c\s+'(Set|Add)\s+:(\S+)\s+.*?'\s+(.+)"#
        if let regex = try? NSRegularExpression(pattern: pbPattern),
           let match = regex.firstMatch(in: cmd, range: NSRange(cmd.startIndex..., in: cmd)),
           let keyPathRange = Range(match.range(at: 3), in: cmd),
           let plistRange = Range(match.range(at: 4), in: cmd) {
            let keyPath = String(cmd[keyPathRange])
            let plist = String(cmd[plistRange]).trimmingCharacters(in: .init(charactersIn: "'\""))
            return "/usr/libexec/PlistBuddy -c 'Print :\(keyPath)' \(plist) 2>/dev/null"
        }
        // env var fix pattern: sed ... ~/.zshrc; echo 'export VAR=VALUE' >> ~/.zshrc
        if rawCmd.contains(">> ~/.zshrc"),
           let echoRange = rawCmd.range(of: "echo 'export "),
           let endQuote = rawCmd[echoRange.upperBound...].range(of: "'") {
            let exportLine = String(rawCmd[echoRange.upperBound..<endQuote.lowerBound])
            return "grep -c '^export \(exportLine)' ~/.zshrc 2>/dev/null"
        }

        let pattern = #"^(sudo\s+)?defaults\s+write\s+(\S+)\s+(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: cmd, range: NSRange(cmd.startIndex..., in: cmd)),
              let domainRange = Range(match.range(at: 2), in: cmd),
              let keyRange = Range(match.range(at: 3), in: cmd) else {
            return ""
        }
        let domain = String(cmd[domainRange])
        let key = String(cmd[keyRange])
        return "defaults read \(domain) \(key) 2>/dev/null"
    }

    /// 输出需要 sudo 权限的修复命令，供用户手动复制到终端执行
    /// - Parameter actions: 修复操作列表（内部过滤 requiresSudo 的项）
    static func printSudoCommands(_ actions: [FixAction]) {
        let sudoActions = actions.filter { $0.requiresSudo }
        guard !sudoActions.isEmpty else { return }

        Layout.print(ANSIColor.bold.wrap("\n  ── 以下命令需要在终端中手动执行 ──\n"))
        for action in sudoActions {
            Swift.print(ANSIColor.dim.wrap("# \(action.name)"))
            Swift.print(action.command)
            Swift.print("")
        }
        Layout.print(ANSIColor.dim.wrap("  提示: 复制上方命令到另一个终端窗口执行"))
    }

    /// 交互式执行 medium 级别修复（需逐条确认）
    /// - Parameters:
    ///   - actions: 全部修复操作列表（内部过滤 medium 且非 sudo/网络风险的项）
    ///   - executor: Shell 执行器
    ///   - auditResults: 原始审计结果
    ///   - confirm: 确认函数，默认从 TTY 读取 y/N
    ///   - historyBaseDir: 历史记录存储目录
    /// - Returns: 每个操作及其执行是否成功的元组数组
    static func executeMedium(
        _ actions: [FixAction],
        executor: ShellExecutor,
        auditResults: [AuditResult] = [],
        confirm: () -> Bool = { readLine()?.lowercased().hasPrefix("y") ?? false },
        historyBaseDir: String = "~/.macaudit"
    ) async -> [(FixAction, Bool)] {
        let mediumActions = actions.filter { $0.riskLevel == .medium && !$0.requiresSudo && !$0.networkRisk }
        var results: [(FixAction, Bool)] = []
        var records: [FixRecord] = []

        let currentValues = Dictionary(uniqueKeysWithValues:
            auditResults.compactMap { r -> (String, String)? in
                guard let v = r.actualValue else { return nil }
                return (r.checkId, v)
            })

        for action in mediumActions {
            Layout.print("\(action.name)")
            Layout.print("命令: \(ANSIColor.dim.wrap(action.command))")
            Layout.printNoNL("执行? (y/N): ")

            guard confirm() else {
                Layout.print(ANSIColor.yellow.wrap("    跳过"))
                continue
            }

            let prevValue = currentValues[action.checkId] ?? "unknown"
            let result = await executor.run(action.command)
            if result.isSuccess {
                let verifyCmd = verifyCommand(for: action)
                var verified = true
                if !verifyCmd.isEmpty {
                    let verifyResult = await executor.run(verifyCmd)
                    if !verifyResult.isSuccess || verifyResult.trimmedOutput.isEmpty {
                        verified = false
                    }
                }
                if verified {
                    Layout.print(ANSIColor.green.wrap("    ✓ 完成"))
                } else {
                    Layout.print(ANSIColor.yellow.wrap("    ⚠ 命令成功但值未确认"))
                }
                results.append((action, verified))
                let undoCmd = generateUndoCommand(action: action, previousValue: prevValue)
                records.append(FixRecord(
                    checkId: action.checkId,
                    name: action.name,
                    command: action.command,
                    previousValue: prevValue,
                    newValue: {
                        let seg = action.command.components(separatedBy: " && ").first ?? action.command
                        return seg.components(separatedBy: " ").last ?? ""
                    }(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    undoCommand: undoCmd
                ))
            } else {
                results.append((action, false))
                Layout.print(ANSIColor.red.wrap("    ✗ 失败: \(result.stderr)"))
            }
        }

        if !records.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let batch = FixBatch(
                id: "fix_medium_\(formatter.string(from: Date()))",
                timestamp: ISO8601DateFormatter().string(from: Date()),
                records: records
            )
            do {
                try FixHistory(baseDir: historyBaseDir).saveBatch(batch)
                Layout.print(ANSIColor.dim.wrap("\n    历史已记录 (\(records.count) 项)，可用 --undo 回滚"))
            } catch {
                Layout.print(ANSIColor.yellow.wrap("\n    历史记录保存失败: \(error.localizedDescription)"))
            }
            AuditLogger.logFix(
                batchId: batch.id,
                executedResults: results.map { (checkId: $0.0.checkId, command: $0.0.command, success: $0.1, error: $0.1 ? nil : "execution failed") },
                type: "medium"
            )
        }

        return results
    }

    /// 执行 critical（网络风险）级别修复 — 需输入 CONFIRM 确认
    /// - Parameters:
    ///   - actions: 全部修复操作列表（内部过滤 networkRisk 的项）
    ///   - executor: Shell 执行器
    ///   - auditResults: 原始审计结果
    ///   - confirm: 确认函数，默认从 TTY 读取 "CONFIRM"
    ///   - historyBaseDir: 历史记录存储目录
    /// - Returns: 每个操作及其执行是否成功的元组数组
    static func executeCritical(
        _ actions: [FixAction],
        executor: ShellExecutor,
        auditResults: [AuditResult] = [],
        confirm: () -> Bool = { readLine() == "CONFIRM" },
        historyBaseDir: String = "~/.macaudit"
    ) async -> [(FixAction, Bool)] {
        let criticalActions = actions.filter { $0.networkRisk }
        var results: [(FixAction, Bool)] = []
        var records: [FixRecord] = []

        let currentValues = Dictionary(uniqueKeysWithValues:
            auditResults.compactMap { r -> (String, String)? in
                guard let v = r.actualValue else { return nil }
                return (r.checkId, v)
            })

        for action in criticalActions {
            NetworkWarning.showWarning(for: action)

            guard confirm() else {
                continue
            }

            let prevValue = currentValues[action.checkId] ?? "unknown"
            let result = await executor.run(action.command)
            if result.isSuccess {
                let verifyCmd = verifyCommand(for: action)
                var verified = true
                if !verifyCmd.isEmpty {
                    let verifyResult = await executor.run(verifyCmd)
                    if !verifyResult.isSuccess || verifyResult.trimmedOutput.isEmpty {
                        verified = false
                    }
                }
                if verified {
                    Layout.print(ANSIColor.green.wrap("    ✓ 完成"))
                } else {
                    Layout.print(ANSIColor.yellow.wrap("    ⚠ 命令成功但值未确认"))
                }
                results.append((action, verified))
                let undoCmd = generateUndoCommand(action: action, previousValue: prevValue)
                records.append(FixRecord(
                    checkId: action.checkId,
                    name: action.name,
                    command: action.command,
                    previousValue: prevValue,
                    newValue: {
                        let seg = action.command.components(separatedBy: " && ").first ?? action.command
                        return seg.components(separatedBy: " ").last ?? ""
                    }(),
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    undoCommand: undoCmd
                ))
            } else {
                results.append((action, false))
                Layout.print(ANSIColor.red.wrap("    ✗ 失败: \(result.stderr)"))
            }
        }

        if !records.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let batch = FixBatch(
                id: "fix_critical_\(formatter.string(from: Date()))",
                timestamp: ISO8601DateFormatter().string(from: Date()),
                records: records
            )
            do {
                try FixHistory(baseDir: historyBaseDir).saveBatch(batch)
                Layout.print(ANSIColor.dim.wrap("\n    历史已记录 (\(records.count) 项)，可用 --undo 回滚"))
            } catch {
                Layout.print(ANSIColor.yellow.wrap("\n    历史记录保存失败: \(error.localizedDescription)"))
            }
            AuditLogger.logFix(
                batchId: batch.id,
                executedResults: results.map { (checkId: $0.0.checkId, command: $0.0.command, success: $0.1, error: $0.1 ? nil : "execution failed") },
                type: "critical"
            )
        }

        return results
    }
}
