import Testing
import Foundation
@testable import MacAudit

// MARK: - Helpers

private func makeCheck(
    id: String,
    fixCmd: String? = nil,
    fixRisk: RiskLevel? = nil,
    networkRisk: Bool = false
) -> AuditCheck {
    AuditCheck(
        id: id,
        name: "Check \(id)",
        module: "test",
        command: "echo x",
        expected: "yes",
        fixRisk: fixRisk,
        fixCommand: fixCmd,
        networkRisk: networkRisk
    )
}

private func makeResult(check: AuditCheck, status: AuditStatus) -> AuditResult {
    switch status {
    case .pass: return .pass(check: check, actual: "yes")
    case .fail: return .fail(check: check, actual: "no")
    case .warn: return .warn(check: check, actual: "warn")
    case .info: return .info(check: check, actual: "info")
    case .skip: return .skip(check: check, reason: "skip")
    case .error: return .error(check: check, error: "err")
    }
}

// MARK: - extractFixActions

@Test("FixEngine extractFixActions returns empty when no failures")
func fixEngineNoFailures() {
    let check = makeCheck(id: "t.c1", fixCmd: "echo fix", fixRisk: .low)
    let result = makeResult(check: check, status: .pass)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.isEmpty)
}

@Test("FixEngine extractFixActions ignores checks without fixCommand")
func fixEngineNoFixCommand() {
    let check = makeCheck(id: "t.c1")  // no fixCmd
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.isEmpty)
}

@Test("FixEngine extractFixActions ignores checks without fixRiskLevel")
func fixEngineNoFixRiskLevel() {
    let check = makeCheck(id: "t.c1", fixCmd: "echo fix")  // no fixRisk
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.isEmpty)
}

@Test("FixEngine extractFixActions extracts action for failed check with fixCommand")
func fixEngineExtractsAction() {
    let check = makeCheck(id: "t.c1", fixCmd: "echo fix", fixRisk: .low)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].checkId == "t.c1")
    #expect(actions[0].command == "echo fix")
}

@Test("FixEngine extractFixActions sets requiresSudo for sudo commands")
func fixEngineRequiresSudo() {
    let check = makeCheck(id: "t.c1", fixCmd: "sudo echo fix", fixRisk: .high)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].requiresSudo == true)
}

@Test("FixEngine extractFixActions does not set requiresSudo for non-sudo commands")
func fixEngineNoSudo() {
    let check = makeCheck(id: "t.c1", fixCmd: "defaults write com.apple.X k -bool true", fixRisk: .low)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].requiresSudo == false)
}

@Test("FixEngine extractFixActions propagates networkRisk flag")
func fixEngineNetworkRisk() {
    let check = makeCheck(id: "t.c1", fixCmd: "sudo networksetup -setv6off Wi-Fi", fixRisk: .critical, networkRisk: true)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].networkRisk == true)
}

@Test("FixEngine extractFixActions sorts by risk level ascending")
func fixEngineRiskSorting() {
    let c1 = makeCheck(id: "t.high", fixCmd: "echo h", fixRisk: .high)
    let c2 = makeCheck(id: "t.low", fixCmd: "echo l", fixRisk: .low)
    let c3 = makeCheck(id: "t.safe", fixCmd: "echo s", fixRisk: .safe)
    let results = [c1, c2, c3].map { makeResult(check: $0, status: .fail) }
    let actions = FixEngine.extractFixActions(from: results, checks: [c1, c2, c3])
    #expect(actions.count == 3)
    #expect(actions[0].riskLevel == .safe)
    #expect(actions[1].riskLevel == .low)
    #expect(actions[2].riskLevel == .high)
}

// MARK: - FixAction properties

@Test("FixAction riskTag is non-empty")
func fixActionRiskTag() {
    let action = FixAction(
        checkId: "t.c1",
        name: "Test",
        command: "echo fix",
        riskLevel: .low,
        requiresSudo: false,
        networkRisk: false,
        description: "test fix"
    )
    #expect(!action.riskTag.isEmpty)
}

@Test("FixAction description contains fix prefix")
func fixActionDescription() {
    let check = makeCheck(id: "t.c1", fixCmd: "echo fix", fixRisk: .low)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.first?.description.contains("修复") == true)
}

// MARK: - generateUndoCommand three-branch tests

private func makeAction(id: String, command: String) -> FixAction {
    FixAction(
        checkId: id,
        name: "Test \(id)",
        command: command,
        riskLevel: .low,
        requiresSudo: false,
        networkRisk: false,
        description: "test"
    )
}

@Test("generateUndoCommand: defaults write + previousValue='not set' → defaults delete")
func generateUndoCommandNotSet() {
    let action = makeAction(id: "t.x", command: "defaults write com.apple.Dock autohide -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "not set")
    #expect(undo == "defaults delete com.apple.Dock autohide")
}

@Test("generateUndoCommand: defaults write + previousValue='N/A' → defaults delete")
func generateUndoCommandNA() {
    let action = makeAction(id: "t.x", command: "defaults write com.apple.X key -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "N/A")
    #expect(undo == "defaults delete com.apple.X key")
}

@Test("generateUndoCommand: defaults write + has previous value → write back previous value")
func generateUndoCommandWithPreviousValue() {
    let action = makeAction(id: "t.x", command: "defaults write com.apple.X key -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "false")
    #expect(undo == "defaults write com.apple.X key -bool false")
}

@Test("generateUndoCommand: non-defaults command → manual comment")
func generateUndoCommandNonDefaults() {
    let action = makeAction(id: "t.x", command: "echo something")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "oldval")
    #expect(undo.hasPrefix("# 手动回滚:"))
    #expect(undo.contains("oldval"))
}

@Test("generateUndoCommand: defaults write with fewer than 4 parts → manual comment fallback")
func generateUndoCommandTooFewParts() {
    // "defaults write x" has only 3 parts → parts.count < 4 → fallback
    let action = makeAction(id: "t.x", command: "defaults write x")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "not set")
    // Should fall through to manual comment since parts.count < 4
    #expect(undo.hasPrefix("# 手动回滚:"))
}

@Test("FixEngine executeSafe result tuple contains Bool=false for failing command")
func fixEngineExecuteSafeFailingCommand() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    // Command that always fails
    let c = makeCheck(id: "t.fail", fixCmd: "exit 1", fixRisk: .low)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executor = ShellExecutor()
    let executed = await FixEngine.executeSafe(
        actions, executor: executor, historyBaseDir: tmpDir
    )
    // The action should appear in results with success=false
    let failResult = executed.first { $0.0.checkId == "t.fail" }
    #expect(failResult != nil)
    #expect(failResult?.1 == false)
}

@Test("FixEngine executeSafe only runs safe and low risk non-sudo actions")
func fixEngineExecuteSafeFilters() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let c1 = makeCheck(id: "t.safe", fixCmd: "echo safe", fixRisk: .safe)
    let c2 = makeCheck(id: "t.low", fixCmd: "echo low", fixRisk: .low)
    let c3 = makeCheck(id: "t.high", fixCmd: "sudo echo high", fixRisk: .high)
    let checks = [c1, c2, c3]
    let results = checks.map { makeResult(check: $0, status: .fail) }
    let actions = FixEngine.extractFixActions(from: results, checks: checks)
    let executor = ShellExecutor()
    let executed = await FixEngine.executeSafe(
        actions, executor: executor, auditResults: results, historyBaseDir: tmpDir
    )
    let executedIds = executed.map { $0.0.checkId }
    #expect(executedIds.contains("t.safe"))
    #expect(executedIds.contains("t.low"))
    #expect(!executedIds.contains("t.high"))
}

@Test("FixEngine executeSafe writes history to specified baseDir not user home")
func fixEngineExecuteSafeHistoryIsolated() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let c = makeCheck(id: "t.low", fixCmd: "echo low", fixRisk: .low)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executor = ShellExecutor()
    _ = await FixEngine.executeSafe(
        actions, executor: executor, auditResults: [result], historyBaseDir: tmpDir
    )
    // History file must be in tmpDir, NOT in ~/.macaudit
    let historyPath = "\(tmpDir)/history.json"
    #expect(FileManager.default.fileExists(atPath: historyPath))
    // Verify user's ~/.macaudit was NOT written by this test
    // (We can't assert absence without knowing prior state, but isolation is verified above)
}

@Test("FixEngine executeSafe returns empty when no safe/low actions")
func fixEngineExecuteSafeEmpty() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let c = makeCheck(id: "t.high", fixCmd: "sudo sysctl x=1", fixRisk: .high)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executor = ShellExecutor()
    let executed = await FixEngine.executeSafe(
        actions, executor: executor, historyBaseDir: tmpDir
    )
    #expect(executed.isEmpty)
}

@Test("FixEngine executeSafe uses auditResults currentValue for prevValue in undo command")
func fixEngineExecuteSafeCurrentValue() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let c = makeCheck(id: "t.low", fixCmd: "defaults write com.apple.X k -bool true", fixRisk: .low)
    let auditResult = AuditResult.fail(check: c, actual: "false")
    let actions = FixEngine.extractFixActions(from: [auditResult], checks: [c])
    let executor = ShellExecutor()
    _ = await FixEngine.executeSafe(
        actions, executor: executor, auditResults: [auditResult], historyBaseDir: tmpDir
    )
    // Load the saved history and verify previousValue was captured
    let history = FixHistory(baseDir: tmpDir)
    let batch = history.lastBatch()
    #expect(batch != nil)
    #expect(batch?.records.first?.previousValue == "false")
}

// MARK: - extractFixActions: medium and critical risk levels

@Test("FixEngine extractFixActions extracts medium-risk action")
func fixEngineExtractsMediumAction() {
    let check = makeCheck(id: "t.med", fixCmd: "defaults write com.apple.Dock X -bool true", fixRisk: .medium)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].riskLevel == .medium)
    #expect(actions[0].requiresSudo == false)
}

@Test("FixEngine extractFixActions extracts critical-risk action with networkRisk")
func fixEngineExtractsCriticalAction() {
    let check = makeCheck(
        id: "t.crit",
        fixCmd: "sudo networksetup -setv6off Wi-Fi",
        fixRisk: .critical,
        networkRisk: true
    )
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].riskLevel == .critical)
    #expect(actions[0].networkRisk == true)
    #expect(actions[0].requiresSudo == true)
}

@Test("FixEngine extractFixActions sorts all five risk levels correctly")
func fixEngineRiskSortingAllLevels() {
    let levels: [(String, RiskLevel)] = [
        ("t.critical", .critical), ("t.high", .high), ("t.medium", .medium),
        ("t.low", .low), ("t.safe", .safe)
    ]
    let checks = levels.map { makeCheck(id: $0.0, fixCmd: "echo \($0.0)", fixRisk: $0.1) }
    let results = checks.map { makeResult(check: $0, status: .fail) }
    let actions = FixEngine.extractFixActions(from: results, checks: checks)
    #expect(actions.count == 5)
    #expect(actions[0].riskLevel == .safe)
    #expect(actions[1].riskLevel == .low)
    #expect(actions[2].riskLevel == .medium)
    #expect(actions[3].riskLevel == .high)
    #expect(actions[4].riskLevel == .critical)
}

// MARK: - executeMedium (依赖注入 confirm 闭包)

@Test("FixEngine executeMedium returns empty when no medium-risk non-sudo non-network actions")
func fixEngineMediumFiltersOutNonMedium() async {
    let c1 = makeCheck(id: "t.safe", fixCmd: "echo safe", fixRisk: .safe)
    let c2 = makeCheck(id: "t.low",  fixCmd: "echo low",  fixRisk: .low)
    let actions = FixEngine.extractFixActions(
        from: [c1, c2].map { makeResult(check: $0, status: .fail) },
        checks: [c1, c2]
    )
    let executed = await FixEngine.executeMedium(actions, executor: ShellExecutor(), confirm: { true })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeMedium returns empty when medium action requires sudo")
func fixEngineMediumFiltersSudo() async {
    let check = makeCheck(id: "t.med", fixCmd: "sudo defaults write com.X k -bool true", fixRisk: .medium)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    #expect(actions[0].requiresSudo == true)
    let executed = await FixEngine.executeMedium(actions, executor: ShellExecutor(), confirm: { true })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeMedium returns empty when medium action has networkRisk")
func fixEngineMediumFiltersNetworkRisk() async {
    let check = makeCheck(id: "t.med", fixCmd: "defaults write com.X k -bool true", fixRisk: .medium, networkRisk: true)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    #expect(actions[0].networkRisk == true)
    let executed = await FixEngine.executeMedium(actions, executor: ShellExecutor(), confirm: { true })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeMedium returns empty when actions list is empty")
func fixEngineMediumEmptyInput() async {
    let executed = await FixEngine.executeMedium([], executor: ShellExecutor(), confirm: { true })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeMedium confirm=true executes medium action and returns result")
func fixEngineMediumConfirmTrue() async {
    let executor = ShellExecutor(stubbedOutputs: ["echo medium_ok": "medium_ok"])
    let check = makeCheck(id: "t.med", fixCmd: "echo medium_ok", fixRisk: .medium)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    let executed = await FixEngine.executeMedium(actions, executor: executor, confirm: { true })
    #expect(executed.count == 1)
    #expect(executed[0].0.checkId == "t.med")
    #expect(executed[0].1 == true)   // isSuccess
}

@Test("FixEngine executeMedium confirm=false skips action and returns empty")
func fixEngineMediumConfirmFalse() async {
    let executor = ShellExecutor(stubbedOutputs: ["echo medium_ok": "medium_ok"])
    let check = makeCheck(id: "t.med", fixCmd: "echo medium_ok", fixRisk: .medium)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    let executed = await FixEngine.executeMedium(actions, executor: executor, confirm: { false })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeMedium confirm=true reports failure when command fails")
func fixEngineMediumConfirmTrueFails() async {
    // stub 不包含该命令 → ShellExecutor 会真实运行 exit 1
    let check = makeCheck(id: "t.med", fixCmd: "exit 1", fixRisk: .medium)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    let executed = await FixEngine.executeMedium(actions, executor: ShellExecutor(), confirm: { true })
    #expect(executed.count == 1)
    #expect(executed[0].1 == false)   // isSuccess = false
}

@Test("FixEngine executeMedium confirm called once per eligible action")
func fixEngineMediumConfirmCalledPerAction() async {
    let executor = ShellExecutor(stubbedOutputs: [
        "echo a": "a",
        "echo b": "b",
    ])
    let c1 = makeCheck(id: "t.a", fixCmd: "echo a", fixRisk: .medium)
    let c2 = makeCheck(id: "t.b", fixCmd: "echo b", fixRisk: .medium)
    let checks = [c1, c2]
    let actions = FixEngine.extractFixActions(
        from: checks.map { makeResult(check: $0, status: .fail) },
        checks: checks
    )
    var callCount = 0
    _ = await FixEngine.executeMedium(actions, executor: executor, confirm: {
        callCount += 1
        return true
    })
    #expect(callCount == 2)
}

// MARK: - executeCritical (依赖注入 confirm 闭包)

@Test("FixEngine executeCritical returns empty when no networkRisk actions")
func fixEngineCriticalFiltersNonNetwork() async {
    let c1 = makeCheck(id: "t.low",  fixCmd: "echo low",      fixRisk: .low,  networkRisk: false)
    let c2 = makeCheck(id: "t.high", fixCmd: "sudo sysctl x=1", fixRisk: .high, networkRisk: false)
    let checks = [c1, c2]
    let actions = FixEngine.extractFixActions(
        from: checks.map { makeResult(check: $0, status: .fail) },
        checks: checks
    )
    let executed = await FixEngine.executeCritical(actions, executor: ShellExecutor(), confirm: { true })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeCritical returns empty when actions list is empty")
func fixEngineCriticalEmptyInput() async {
    let executed = await FixEngine.executeCritical([], executor: ShellExecutor(), confirm: { true })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeCritical confirm=true executes networkRisk action and returns result")
func fixEngineCriticalConfirmTrue() async {
    let executor = ShellExecutor(stubbedOutputs: ["echo critical_ok": "critical_ok"])
    let check = makeCheck(id: "t.crit", fixCmd: "echo critical_ok", fixRisk: .medium, networkRisk: true)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    let executed = await FixEngine.executeCritical(actions, executor: executor, confirm: { true })
    #expect(executed.count == 1)
    #expect(executed[0].0.checkId == "t.crit")
    #expect(executed[0].1 == true)
}

@Test("FixEngine executeCritical confirm=false skips networkRisk action")
func fixEngineCriticalConfirmFalse() async {
    let executor = ShellExecutor(stubbedOutputs: ["echo critical_ok": "critical_ok"])
    let check = makeCheck(id: "t.crit", fixCmd: "echo critical_ok", fixRisk: .medium, networkRisk: true)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    let executed = await FixEngine.executeCritical(actions, executor: executor, confirm: { false })
    #expect(executed.isEmpty)
}

@Test("FixEngine executeCritical confirm=true reports failure when command fails")
func fixEngineCriticalConfirmTrueFails() async {
    let check = makeCheck(id: "t.crit", fixCmd: "exit 1", fixRisk: .medium, networkRisk: true)
    let actions = FixEngine.extractFixActions(from: [makeResult(check: check, status: .fail)], checks: [check])
    let executed = await FixEngine.executeCritical(actions, executor: ShellExecutor(), confirm: { true })
    #expect(executed.count == 1)
    #expect(executed[0].1 == false)
}

@Test("FixEngine executeCritical confirm called once per networkRisk action")
func fixEngineCriticalConfirmCalledPerAction() async {
    let executor = ShellExecutor(stubbedOutputs: [
        "echo x": "x",
        "echo y": "y",
    ])
    let c1 = makeCheck(id: "t.x", fixCmd: "echo x", fixRisk: .medium, networkRisk: true)
    let c2 = makeCheck(id: "t.y", fixCmd: "echo y", fixRisk: .medium, networkRisk: true)
    let checks = [c1, c2]
    let actions = FixEngine.extractFixActions(
        from: checks.map { makeResult(check: $0, status: .fail) },
        checks: checks
    )
    var callCount = 0
    _ = await FixEngine.executeCritical(actions, executor: executor, confirm: {
        callCount += 1
        return true
    })
    #expect(callCount == 2)
}

// MARK: - FixAction.riskTag format for all risk levels

@Test("FixAction riskTag contains sudo label for sudo commands")
func fixActionRiskTagSudoLabel() {
    let action = FixAction(
        checkId: "t.x", name: "Test", command: "sudo sysctl x=1",
        riskLevel: .high, requiresSudo: true, networkRisk: false, description: "test"
    )
    // riskTag wraps with ANSI, strip codes and check for SUDO keyword presence
    let stripped = action.riskTag.replacingOccurrences(of: "\\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    #expect(stripped.contains("SUDO"))
}

@Test("FixAction riskTag contains network risk label for networkRisk commands")
func fixActionRiskTagNetworkLabel() {
    let action = FixAction(
        checkId: "t.x", name: "Test", command: "sudo networksetup -setv6off Wi-Fi",
        riskLevel: .critical, requiresSudo: true, networkRisk: true, description: "test"
    )
    let stripped = action.riskTag.replacingOccurrences(of: "\\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    #expect(stripped.contains("网络风险"))
}

@Test("FixAction riskTag does not contain sudo/network labels when neither is set")
func fixActionRiskTagClean() {
    let action = FixAction(
        checkId: "t.x", name: "Test", command: "defaults write com.X k -bool true",
        riskLevel: .low, requiresSudo: false, networkRisk: false, description: "test"
    )
    let stripped = action.riskTag.replacingOccurrences(of: "\\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    #expect(!stripped.contains("SUDO"))
    #expect(!stripped.contains("网络风险"))
}

// MARK: - Tahoe / PlistBuddy / Compound undo tests (P0)

@Test("generateUndoCommand handles Tahoe dict previousValue")
func undoTahoeDictPreviousValue() {
    let action = makeAction(id: "t.tahoe", command: "defaults write com.apple.Safari UniversalSearchEnabled -bool false")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "{ \"-bool\" = true; }")
    #expect(!undo.hasPrefix("# 手动回滚"))
    #expect(!undo.contains("{") || undo.contains("'"))
}

@Test("generateUndoCommand handles PlistBuddy command")
func undoPlistBuddyCommand() {
    let action = makeAction(id: "t.chrome", command: "sudo /usr/libexec/PlistBuddy -c 'Set :WebRtcIPHandlingPolicy string disable_non_proxied_udp' '/Library/Managed Preferences/com.google.Chrome.plist'")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "default_public_interface_only")
    #expect(undo.hasPrefix("# 手动回滚") || undo.contains("PlistBuddy"))
}

@Test("generateUndoCommand handles compound && fixCommand")
func undoCompoundFixCommand() {
    let action = makeAction(id: "t.compound", command: "defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false && defaults write com.apple.Safari WebKit2JavaScriptCanOpenWindowsAutomatically -bool false")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "not set")
    #expect(undo.contains("com.apple.Safari"))
    #expect(!undo.contains("&&"))
}

@Test("generateUndoCommand handles sudo prefix")
func undoSudoPrefix() {
    let action = makeAction(id: "t.sudo", command: "sudo defaults write com.apple.Safari UniversalSearchEnabled -bool false")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "1")
    #expect(undo.contains("com.apple.Safari"))
    #expect(undo.contains("UniversalSearchEnabled"))
}

@Test("generateUndoCommand preserves -string type flag")
func undoStringTypeFlag() {
    let action = makeAction(id: "t.str", command: "defaults write com.apple.X key -string none")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "prompt")
    #expect(undo == "defaults write com.apple.X key -string prompt")
}

@Test("generateUndoCommand handles pipe compound (killall Dock)")
func undoPipeCompound() {
    let action = makeAction(id: "t.dock", command: "defaults write com.apple.Dock autohide -bool true && killall Dock")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "false")
    #expect(undo.contains("com.apple.Dock"))
    #expect(!undo.contains("killall"))
}

// MARK: - A0 Defect: previousValue "unknown" injection risk

@Test("generateUndoCommand: previousValue='unknown' does not write literal 'unknown' to defaults")
func generateUndoCommandUnknownNoInjection() {
    let action = makeAction(id: "t.x", command: "defaults write com.apple.Dock autohide -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "unknown")
    #expect(!undo.contains("defaults write com.apple.Dock autohide unknown"))
    #expect(undo.hasPrefix("#"))
    #expect(undo.contains("原值未记录"))
}

@Test("generateUndoCommand: previousValue='unknown' for PlistBuddy produces comment not write")
func generateUndoCommandUnknownPlistBuddy() {
    let action = makeAction(id: "t.pb", command: "/usr/libexec/PlistBuddy -c 'Set :AutoHideDock 1' ~/Library/Preferences/com.apple.dock.plist")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "unknown")
    #expect(!undo.contains("Set :AutoHideDock unknown"))
    #expect(undo.hasPrefix("#"))
}

@Test("generateUndoCommand: previousValue='unknown' for defaults write with type flag produces comment")
func generateUndoCommandUnknownWithTypeFlag() {
    let action = makeAction(id: "t.int", command: "defaults write com.apple.X key -int 1")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "unknown")
    #expect(!undo.contains("defaults write com.apple.X key -int unknown"))
    #expect(!undo.contains("defaults write com.apple.X key unknown"))
    #expect(undo.hasPrefix("#"))
}

// MARK: - A0 Defect: shellEscape control character injection

@Test("shellEscape sanitizes newline control characters")
func shellEscapeNewlineSanitized() {
    let escaped = FixEngine.shellEscape("hello\nworld")
    #expect(!escaped.contains("\n"))
}

@Test("shellEscape sanitizes carriage return control characters")
func shellEscapeCRSanitized() {
    let escaped = FixEngine.shellEscape("hello\rworld")
    #expect(!escaped.contains("\r"))
}

@Test("shellEscape sanitizes null byte")
func shellEscapeNullSanitized() {
    let escaped = FixEngine.shellEscape("hello\0world")
    #expect(!escaped.contains("\0"))
}

@Test("shellEscape sanitizes tab character")
func shellEscapeTabSanitized() {
    let escaped = FixEngine.shellEscape("hello\tworld")
    #expect(!escaped.contains("\t"))
}

@Test("shellEscape preserves safe characters unchanged")
func shellEscapeSafeCharsUnchanged() {
    #expect(FixEngine.shellEscape("hello") == "hello")
    #expect(FixEngine.shellEscape("value123") == "value123")
    #expect(FixEngine.shellEscape("my.key.name") == "my.key.name")
}

@Test("shellEscape quotes values containing hyphens (prevents flag misinterpretation)")
func shellEscapeQuotesHyphens() {
    #expect(FixEngine.shellEscape("my-key") == "'my-key'")
    #expect(FixEngine.shellEscape("-force") == "'-force'")
}

@Test("shellEscape preserves spaces in values (does NOT strip them)")
func shellEscapePreservesSpaces() {
    let escaped = FixEngine.shellEscape("full keyboard access")
    #expect(escaped.contains("full keyboard access"))
    #expect(escaped.hasSuffix("'"))
    #expect(escaped.hasPrefix("'"))
}

@Test("shellEscape returns quoted empty string for empty input")
func shellEscapeEmpty() {
    #expect(FixEngine.shellEscape("") == "''")
}

@Test("shellEscape returns quoted empty string for all-control-char input")
func shellEscapeAllControlChars() {
    let controlChars = String(UnicodeScalar(1)!) + String(UnicodeScalar(2)!) + String(UnicodeScalar(3)!)
    #expect(FixEngine.shellEscape(controlChars) == "''")
}

@Test("normalizePreviousValue trims whitespace from non-dict values")
func normalizePreviousValueTrims() {
    #expect(FixEngine.normalizePreviousValue(" true ") == "true")
    #expect(FixEngine.normalizePreviousValue(" false ") == "false")
}

@Test("generateUndoCommand with whitespace-padded previousValue produces correct undo")
func undoWithWhitespacePaddedPrev() {
    let action = makeAction(id: "t.ws", command: "defaults write com.apple.X key -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: " false ")
    #expect(undo == "defaults write com.apple.X key -bool false")
}

// MARK: - A0 Defect: executeMedium/Critical must save FixHistory for undo

@Test("executeMedium saves FixHistory after successful medium-risk fix")
func fixEngineExecuteMediumSavesHistory() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.Dock orientation": "ok",
        "defaults read com.apple.Dock orientation": "left"
    ])
    let c = makeCheck(id: "t.med", fixCmd: "defaults write com.apple.Dock orientation -string left", fixRisk: .medium)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    _ = await FixEngine.executeMedium(
        actions, executor: executor, auditResults: [result], confirm: { true }, historyBaseDir: tmpDir
    )
    let history = FixHistory(baseDir: tmpDir)
    let batch = history.lastBatch()
    #expect(batch != nil)
    #expect(batch?.records.first?.checkId == "t.med")
}

@Test("executeCritical saves FixHistory after successful critical-risk fix")
func fixEngineExecuteCriticalSavesHistory() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "sudo networksetup": "ok"
    ])
    let c = makeCheck(id: "t.crit", fixCmd: "sudo networksetup -setv6off Wi-Fi", fixRisk: .critical, networkRisk: true)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    _ = await FixEngine.executeCritical(
        actions, executor: executor, auditResults: [result], confirm: { true }, historyBaseDir: tmpDir
    )
    let history = FixHistory(baseDir: tmpDir)
    let batch = history.lastBatch()
    #expect(batch != nil)
    #expect(batch?.records.first?.checkId == "t.crit")
}

// MARK: - requiresSudo detection enhancement

@Test("extractFixActions detects sudo with full path /usr/bin/sudo")
func fixEngineDetectsSudoFullPath() {
    let check = makeCheck(id: "t.sudo_full", fixCmd: "/usr/bin/sudo sysctl -w net.inet.ip.forwarding=1", fixRisk: .high)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].requiresSudo == true)
}

@Test("extractFixActions detects sudo with leading whitespace")
func fixEngineDetectsSudoWithWhitespace() {
    let check = makeCheck(id: "t.sudo_ws", fixCmd: "  sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1", fixRisk: .high)
    let result = makeResult(check: check, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [check])
    #expect(actions.count == 1)
    #expect(actions[0].requiresSudo == true)
}

@Test("detectsSudo rejects false positive: command containing 'sudo ' in argument")
func fixEngineSudoFalsePositive() {
    #expect(FixEngine.detectsSudo("/bin/echo \"please run sudo to fix\"") == false)
    #expect(FixEngine.detectsSudo("/bin/bash -c \"echo sudo needed\"") == false)
}

@Test("detectsSudo accepts path-qualified sudo binary")
func fixEngineSudoPathQualified() {
    #expect(FixEngine.detectsSudo("/usr/bin/sudo sysctl -w x=1") == true)
    #expect(FixEngine.detectsSudo("/usr/local/bin/sudo echo test") == true)
}

// MARK: - A0 Defect: post-fix verification (verifyCommand derivation)

@Test("verifyCommand: defaults write → defaults read")
func verifyCommandDefaultsWrite() {
    let action = makeAction(id: "t.v1", command: "defaults write com.apple.Dock autohide -bool true")
    let verify = FixEngine.verifyCommand(for: action)
    #expect(verify == "defaults read com.apple.Dock autohide 2>/dev/null")
}

@Test("verifyCommand: sudo defaults write → defaults read (no sudo for reading)")
func verifyCommandSudoDefaultsWrite() {
    let action = makeAction(id: "t.v2", command: "sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1")
    let verify = FixEngine.verifyCommand(for: action)
    #expect(verify == "defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null")
}

@Test("verifyCommand: PlistBuddy Set → PlistBuddy Print")
func verifyCommandPlistBuddySet() {
    let action = makeAction(id: "t.v3", command: "/usr/libexec/PlistBuddy -c 'Set :AutoHideDock 1' ~/Library/Preferences/com.apple.dock.plist")
    let verify = FixEngine.verifyCommand(for: action)
    #expect(verify == "/usr/libexec/PlistBuddy -c 'Print :AutoHideDock' ~/Library/Preferences/com.apple.dock.plist 2>/dev/null")
}

@Test("verifyCommand: compound && command → verify first part only")
func verifyCommandCompound() {
    let action = makeAction(id: "t.v4", command: "defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false && defaults write com.apple.Safari WebKit2JavaScriptCanOpenWindowsAutomatically -bool false")
    let verify = FixEngine.verifyCommand(for: action)
    #expect(verify == "defaults read com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically 2>/dev/null")
}

@Test("verifyCommand: non-defaults/non-PlistBuddy → empty string (unverifiable)")
func verifyCommandUnverifiable() {
    let action = makeAction(id: "t.v5", command: "echo something")
    let verify = FixEngine.verifyCommand(for: action)
    #expect(verify.isEmpty)
}

// MARK: - A0 Defect: post-fix verification in executeSafe

@Test("executeSafe verifies fix with verifyCommand when available")
func fixEngineExecuteSafeVerifiesFix() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.Dock autohide -bool": "ok",
        "defaults read com.apple.Dock autohide": "1"
    ])
    let c = makeCheck(id: "t.verified", fixCmd: "defaults write com.apple.Dock autohide -bool true", fixRisk: .low)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executed = await FixEngine.executeSafe(
        actions, executor: executor, auditResults: [result], historyBaseDir: tmpDir
    )
    #expect(executed.count == 1)
    #expect(executed[0].1 == true)
}

@Test("executeSafe marks verified=false when verifyCommand returns empty/failed")
func fixEngineExecuteSafeVerificationFails() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.Dock autohide -bool": "ok",
        "defaults read com.apple.Dock autohide": ""
    ])
    let c = makeCheck(id: "t.unverified", fixCmd: "defaults write com.apple.Dock autohide -bool true", fixRisk: .low)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executed = await FixEngine.executeSafe(
        actions, executor: executor, auditResults: [result], historyBaseDir: tmpDir
    )
    #expect(executed.count == 1)
    #expect(executed[0].1 == false)
}

@Test("executeMedium verifies fix with verifyCommand when available")
func fixEngineExecuteMediumVerifiesFix() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.Dock autohide -bool": "ok",
        "defaults read com.apple.Dock autohide": "1"
    ])
    let c = makeCheck(id: "t.med_verified", fixCmd: "defaults write com.apple.Dock autohide -bool true", fixRisk: .medium)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executed = await FixEngine.executeMedium(
        actions, executor: executor, auditResults: [result],
        confirm: { true }, historyBaseDir: tmpDir
    )
    #expect(executed.count == 1)
    #expect(executed[0].1 == true)
}

@Test("executeMedium marks verified=false when verifyCommand returns empty/failed")
func fixEngineExecuteMediumVerificationFails() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.Dock autohide -bool": "ok",
        "defaults read com.apple.Dock autohide": ""
    ])
    let c = makeCheck(id: "t.med_unverified", fixCmd: "defaults write com.apple.Dock autohide -bool true", fixRisk: .medium)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executed = await FixEngine.executeMedium(
        actions, executor: executor, auditResults: [result],
        confirm: { true }, historyBaseDir: tmpDir
    )
    #expect(executed.count == 1)
    #expect(executed[0].1 == false)
}

@Test("executeCritical verifies fix with verifyCommand when available")
func fixEngineExecuteCriticalVerifiesFix() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.alf globalstate -int": "ok",
        "defaults read com.apple.alf globalstate": "1"
    ])
    let c = makeCheck(id: "t.crit_verified", fixCmd: "defaults write com.apple.alf globalstate -int 1", fixRisk: .medium, networkRisk: true)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executed = await FixEngine.executeCritical(
        actions, executor: executor, auditResults: [result],
        confirm: { true }, historyBaseDir: tmpDir
    )
    #expect(executed.count == 1)
    #expect(executed[0].1 == true)
}

@Test("executeCritical marks verified=false when verifyCommand returns empty/failed")
func fixEngineExecuteCriticalVerificationFails() async {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let executor = ShellExecutor(stubbedOutputs: [
        "defaults write com.apple.alf globalstate -int": "ok",
        "defaults read com.apple.alf globalstate": ""
    ])
    let c = makeCheck(id: "t.crit_unverified", fixCmd: "defaults write com.apple.alf globalstate -int 1", fixRisk: .medium, networkRisk: true)
    let result = makeResult(check: c, status: .fail)
    let actions = FixEngine.extractFixActions(from: [result], checks: [c])
    let executed = await FixEngine.executeCritical(
        actions, executor: executor, auditResults: [result],
        confirm: { true }, historyBaseDir: tmpDir
    )
    #expect(executed.count == 1)
    #expect(executed[0].1 == false)
}

// MARK: - A0 Defect: FixHistory.saveBatch atomic write

@Test("FixHistory atomic write preserves data across save/load cycle")
func fixHistoryAtomicWriteIntegration() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("macaudit_test_\(UUID().uuidString)").path
    defer { try? FileManager.default.removeItem(atPath: dir) }
    let history = FixHistory(baseDir: dir)
    let record = FixRecord(
        checkId: "t.c1", name: "Test",
        command: "defaults write com.apple.X key -bool true",
        previousValue: "false", newValue: "true",
        timestamp: ISO8601DateFormatter().string(from: Date()),
        undoCommand: "defaults write com.apple.X key -bool false"
    )
    let batch = FixBatch(id: "atomic_test", timestamp: ISO8601DateFormatter().string(from: Date()), records: [record])
    try history.saveBatch(batch)
    let loaded = history.loadAll()
    #expect(loaded.count == 1)
    #expect(loaded[0].records.count == 1)
    #expect(loaded[0].records[0].checkId == "t.c1")
}

// MARK: - A0 Defect: shellEscape shell metacharacter injection (D1)

@Test("shellEscape neutralizes command substitution $()")
func shellEscapeNeutralizesDollarSubstitution() {
    let escaped = FixEngine.shellEscape("$(whoami)")
    #expect(!escaped.contains("$("))
}

@Test("shellEscape neutralizes backtick command substitution")
func shellEscapeNeutralizesBacktickSubstitution() {
    let escaped = FixEngine.shellEscape("`whoami`")
    #expect(!escaped.contains("`"))
}

@Test("shellEscape neutralizes semicolon command separator")
func shellEscapeNeutralizesSemicolon() {
    let escaped = FixEngine.shellEscape("true;rm -rf /")
    #expect(!escaped.contains(";"))
}

@Test("shellEscape neutralizes pipe operator")
func shellEscapeNeutralizesPipe() {
    let escaped = FixEngine.shellEscape("value|cat /etc/passwd")
    #expect(!escaped.contains("|"))
}

@Test("shellEscape neutralizes ampersand background operator")
func shellEscapeNeutralizesAmpersand() {
    let escaped = FixEngine.shellEscape("value&malicious")
    #expect(!escaped.contains("&"))
}

@Test("shellEscape neutralizes redirect operators")
func shellEscapeNeutralizesRedirect() {
    let escaped = FixEngine.shellEscape("value> /tmp/evil")
    #expect(!escaped.contains(">"))
    let escaped2 = FixEngine.shellEscape("value< /etc/passwd")
    #expect(!escaped2.contains("<"))
}

@Test("shellEscape: generateUndoCommand with malicious previousValue produces safe command")
func generateUndoCommandMaliciousPreviousValue() {
    let action = makeAction(id: "t.mal", command: "defaults write com.apple.X key -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "$(rm -rf /)")
    #expect(!undo.contains("$(rm"))
    #expect(undo.hasPrefix("#"))
    #expect(undo.contains("shell metacharacters"))
}

@Test("shellEscape: generateUndoCommand with backtick previousValue produces safe command")
func generateUndoCommandBacktickPreviousValue() {
    let action = makeAction(id: "t.bq", command: "defaults write com.apple.X key -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "`whoami`")
    #expect(undo.hasPrefix("#"))
    #expect(undo.contains("shell metacharacters"))
}

@Test("shellEscape: PlistBuddy undo with metacharacter previousValue stays inside single quotes")
func generateUndoCommandPlistBuddyMetacharPreviousValue() {
    let action = makeAction(id: "t.pb2", command: "/usr/libexec/PlistBuddy -c 'Set :SomeKey 1' ~/Library/Preferences/com.apple.test.plist")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "val;rm -rf /")
    #expect(undo.hasPrefix("#"))
    #expect(undo.contains("shell metacharacters"))
}

// MARK: - A0 Defect: FixEngine domain/key shell metacharacter defense (C3)

@Test("generateUndoCommand rejects domain containing shell metacharacters")
func generateUndoCommandRejectsMetacharDomain() {
    let action = makeAction(id: "t.dom", command: "defaults write 'com.apple.X;rm' key -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "false")
    #expect(undo.hasPrefix("#"))
    #expect(undo.contains("dangerous characters"))
}

@Test("generateUndoCommand rejects key containing shell metacharacters")
func generateUndoCommandRejectsMetacharKey() {
    let action = makeAction(id: "t.key", command: "defaults write com.apple.X 'key$(whoami)' -bool true")
    let undo = FixEngine.generateUndoCommand(action: action, previousValue: "false")
    #expect(undo.hasPrefix("#"))
}

@Test("normalizePreviousValue returns unknown for dict values (W3 fix)")
func normalizePreviousValueDictReturnsUnknown() {
    #expect(FixEngine.normalizePreviousValue("{ \"-bool\" = true; }") == "unknown")
    #expect(FixEngine.normalizePreviousValue("{ enabled = true; value = false }") == "unknown")
}
