import Foundation

/// 修复操作定义
public struct FixAction: Sendable {
    public let checkId: String
    public let name: String
    public let command: String
    public let riskLevel: RiskLevel
    public let requiresSudo: Bool
    public let networkRisk: Bool
    public let description: String

    /// 风险标签
    var riskTag: String {
        var tag = riskLevel.color.wrap("[\(riskLevel.label)]")
        if requiresSudo { tag += ANSIColor.orange.wrap(" [SUDO]") }
        if networkRisk { tag += ANSIColor.red.wrap(" [网络风险]") }
        return tag
    }
}

    /// 修复引擎 — 按风险等级分级执行
public struct FixEngine: Sendable {

    /// 检测命令是否需要 sudo（支持 "sudo "、"/usr/bin/sudo "、"/usr/local/bin/sudo " 等变体）
    public static func detectsSudo(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("sudo ") { return true }
        let sudoPathPattern = #"^(?:/\S+/)?sudo(\s|$)"#
        if let regex = try? NSRegularExpression(pattern: sudoPathPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return true
        }
        return false
    }

    /// 从失败的审查结果中提取可修复项
    public static func extractFixActions(from results: [AuditResult], checks: [AuditCheck]) -> [FixAction] {
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

    /// 分组显示修复方案
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

    /// 执行 safe + low 级别的修复（带历史记录）
    static func executeSafe(
        _ actions: [FixAction],
        executor: ShellExecutor,
        auditResults: [AuditResult] = [],
        historyBaseDir: String = "~/.macaudit"
    ) async -> [(FixAction, Bool)] {
        let safeActions = actions.filter { $0.riskLevel <= .low && !$0.requiresSudo }
        var results: [(FixAction, Bool)] = []
        var records: [FixRecord] = []

        // 按 checkId 建立当前值索引
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

                // 生成 undo 命令：将值写回原来的值
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

        // 保存批次历史
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
    public static func generateUndoCommand(action: FixAction, previousValue: String) -> String {
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

    public static func shellEscape(_ value: String) -> String {
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

    public static func containsShellMetacharacters(_ value: String) -> Bool {
        let metacharacters: Set<Character> = ["$", "`", ";", "|", "&", ">", "<", "(", ")", "{", "}", "!", "#", "~", "*", "?", "[", "]", "'", "\"", "\\"]
        return value.contains { metacharacters.contains($0) }
    }

    public static func normalizePreviousValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            return "unknown"
        }
        return trimmed
    }

    public static func verifyCommand(for action: FixAction) -> String {
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

    /// 生成 sudo 命令供复制
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

    /// 交互式执行 medium 级别
    /// - Parameter confirm: 每条 action 执行前的确认函数，默认从 TTY 读取 y/N。
    ///   测试时注入 `{ true }` 或 `{ false }` 即可，不影响生产行为。
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

    /// 执行 critical（网络风险）级别 — 需要 CONFIRM
    /// - Parameter confirm: 每条 action 执行前的确认函数，默认从 TTY 读取 CONFIRM。
    ///   测试时注入 `{ true }` 或 `{ false }` 即可，不影响生产行为。
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
