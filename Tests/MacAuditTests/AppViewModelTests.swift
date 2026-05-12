import Testing
import Foundation
import MacAuditCore
@testable import MacAuditUI

@MainActor
struct AppViewModelTests {

    private func makeVM() -> AppViewModel {
        UserDefaults.standard.removeObject(forKey: "ma_user_skipped")
        UserDefaults.standard.removeObject(forKey: "ma_version")
        UserDefaults.standard.removeObject(forKey: "ma_device")
        return AppViewModel()
    }

    private func makeResult(_ checkId: String, moduleId: String, status: AuditStatus) -> AuditResult {
        let check = AuditCheck(id: checkId, name: checkId, module: moduleId, command: "echo test")
        switch status {
        case .pass: return .pass(check: check, actual: "ok")
        case .fail: return .fail(check: check, actual: "bad")
        case .warn: return .warn(check: check, actual: "warn")
        case .info: return .info(check: check, actual: "info")
        case .skip: return .skip(check: check, reason: "test")
        case .error: return .error(check: check, error: "err")
        }
    }

    // MARK: - Initial State

    @Test("AppViewModel initial state has no results and score 0")
    func initialState() {
        let vm = makeVM()
        #expect(vm.results.isEmpty)
        #expect(vm.moduleSummaries.isEmpty)
        #expect(vm.systemScore == 0)
        #expect(vm.isScanning == false)
        #expect(vm.lastAuditDurationMs == 0)
        #expect(vm.selectedScreen == .dashboard)
        #expect(vm.userSkippedIds.isEmpty)
        #expect(vm.skippedCount == 0)
    }

    // MARK: - systemScore

    @Test("systemScore returns 0 when no results")
    func systemScoreEmpty() {
        let vm = makeVM()
        #expect(vm.systemScore == 0)
    }

    @Test("systemScore 100 when all pass")
    func systemScoreAllPass() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "network_security", status: .pass),
            makeResult("c2", moduleId: "network_security", status: .pass),
        ])
        #expect(vm.systemScore == 100)
    }

    @Test("systemScore excludes skip/info/services/dev/animation")
    func systemScoreExcludesNonScoring() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "network_security", status: .pass),
            makeResult("c2", moduleId: "network_security", status: .fail),
            makeResult("c3", moduleId: "services", status: .fail),
            makeResult("c4", moduleId: "dev", status: .fail),
            makeResult("c5", moduleId: "animation", status: .fail),
            makeResult("c6", moduleId: "network_security", status: .info),
            makeResult("c7", moduleId: "network_security", status: .skip),
        ])
        #expect(vm.systemScore == 50)
    }

    @Test("systemScore excludes user-skipped checks")
    func systemScoreExcludesUserSkipped() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "network_security", status: .pass),
            makeResult("c2", moduleId: "network_security", status: .fail),
        ])
        vm.skipCheck("c2")
        #expect(vm.systemScore == 100)
    }

    // MARK: - results(for:) — fail-first sort

    @Test("results(for:) returns fail items first")
    func resultsForModuleFailFirst() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "privacy", status: .pass),
            makeResult("c2", moduleId: "privacy", status: .fail),
            makeResult("c3", moduleId: "privacy", status: .info),
            makeResult("c4", moduleId: "network_security", status: .pass),
        ])
        let sorted = vm.results(for: "privacy")
        #expect(sorted.count == 3)
        #expect(sorted[0].status == .fail)
    }

    @Test("results(for:) returns empty for unknown module")
    func resultsForUnknownModule() {
        let vm = makeVM()
        vm.injectTestResults([makeResult("c1", moduleId: "privacy", status: .pass)])
        #expect(vm.results(for: "nonexistent").isEmpty)
    }

    // MARK: - failedResults(for:)

    @Test("failedResults(for:) returns only failed items")
    func failedResultsForModule() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "privacy", status: .pass),
            makeResult("c2", moduleId: "privacy", status: .fail),
            makeResult("c3", moduleId: "privacy", status: .fail),
        ])
        #expect(vm.failedResults(for: "privacy").count == 2)
    }

    @Test("failedResults(for:) empty when no failures")
    func failedResultsNone() {
        let vm = makeVM()
        vm.injectTestResults([makeResult("c1", moduleId: "privacy", status: .pass)])
        #expect(vm.failedResults(for: "privacy").isEmpty)
    }

    // MARK: - moduleName(for:)

    @Test("moduleName(for:) returns name from summaries")
    func moduleNameFromSummaries() {
        let vm = makeVM()
        vm.injectTestSummaries([
            ModuleSummary(id: "privacy", name: "隐私与遥测", passed: 5, failed: 0, total: 5),
        ])
        #expect(vm.moduleName(for: "privacy") == "隐私与遥测")
    }

    @Test("moduleName(for:) falls back to id when not found")
    func moduleNameFallback() {
        let vm = makeVM()
        #expect(vm.moduleName(for: "unknown") == "unknown")
    }

    // MARK: - defaultSelectedModuleId

    @Test("defaultSelectedModuleId returns first summary id")
    func defaultSelectedModuleIdFirst() {
        let vm = makeVM()
        vm.injectTestSummaries([
            ModuleSummary(id: "system_info", name: "系统信息", passed: 5, failed: 0, total: 5),
            ModuleSummary(id: "privacy", name: "隐私", passed: 3, failed: 2, total: 5),
        ])
        #expect(vm.defaultSelectedModuleId == "system_info")
    }

    @Test("defaultSelectedModuleId nil when no summaries")
    func defaultSelectedModuleIdNil() {
        let vm = makeVM()
        #expect(vm.defaultSelectedModuleId == nil)
    }

    // MARK: - failedResults (all modules)

    @Test("failedResults returns all failed across modules")
    func allFailedResults() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "privacy", status: .fail),
            makeResult("c2", moduleId: "network_security", status: .fail),
            makeResult("c3", moduleId: "privacy", status: .pass),
        ])
        #expect(vm.failedResults.count == 2)
    }

    // MARK: - result(for checkId:)

    @Test("result(for:) finds by checkId")
    func resultForCheckId() {
        let vm = makeVM()
        vm.injectTestResults([makeResult("c1", moduleId: "privacy", status: .pass)])
        #expect(vm.result(for: "c1") != nil)
        #expect(vm.result(for: "nonexistent") == nil)
    }

    // MARK: - skipCheck / resetAllSkips

    @Test("skipCheck adds to skipped set and persists")
    func skipCheckAddsAndPersists() {
        let vm = makeVM()
        vm.skipCheck("c1")
        #expect(vm.userSkippedIds.contains("c1"))
        #expect(vm.skippedCount == 1)
    }

    @Test("resetAllSkips clears all skips")
    func resetAllSkips() {
        let vm = makeVM()
        vm.skipCheck("c1")
        vm.skipCheck("c2")
        vm.resetAllSkips()
        #expect(vm.userSkippedIds.isEmpty)
        #expect(vm.skippedCount == 0)
    }

    // MARK: - rebuildModuleSummaries after skip

    @Test("skipCheck triggers rebuildModuleSummaries excluding skipped")
    func skipCheckRebuildsSummaries() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "privacy", status: .fail),
            makeResult("c2", moduleId: "privacy", status: .pass),
        ])
        vm.injectTestSummaries([
            ModuleSummary(id: "privacy", name: "隐私", passed: 1, failed: 1, total: 2),
        ])
        vm.skipCheck("c1")
        let summary = vm.moduleSummaries.first { $0.id == "privacy" }
        #expect(summary != nil)
        #expect(summary!.passed == 1)
        #expect(summary!.failed == 0)
        #expect(summary!.total == 1)
    }

    // MARK: - cancelAudit

    @Test("cancelAudit resets scanning state and returns to dashboard")
    func cancelAudit() {
        let vm = makeVM()
        vm.isScanning = true
        vm.selectedScreen = .scanning
        vm.cancelAudit()
        #expect(vm.isScanning == false)
        #expect(vm.selectedScreen == .dashboard)
    }

    @Test("cancelAudit clears results from partial audit")
    func cancelAuditClearsPartialResults() {
        let vm = makeVM()
        vm.isScanning = true
        vm.selectedScreen = .scanning
        vm.injectTestResults([makeResult("c1", moduleId: "network_security", status: .pass)])
        vm.cancelAudit()
        #expect(vm.isScanning == false)
        #expect(vm.results.isEmpty)
        #expect(vm.moduleSummaries.isEmpty)
    }

    @Test("cancelAudit is idempotent — calling twice does not crash")
    func cancelAuditIdempotent() {
        let vm = makeVM()
        vm.isScanning = true
        vm.cancelAudit()
        vm.cancelAudit()
        #expect(vm.isScanning == false)
    }

    // MARK: - hasSavedSnapshot

    @Test("hasSavedSnapshot is false initially")
    func hasSavedSnapshotInitiallyFalse() {
        let vm = makeVM()
        #expect(vm.hasSavedSnapshot == false)
    }

    // MARK: - restoreFromSnapshot

    @Test("restoreFromSnapshot does nothing when no snapshot")
    func restoreFromSnapshotNoSnapshot() {
        let vm = makeVM()
        vm.restoreFromSnapshot()
        #expect(vm.results.isEmpty)
        #expect(vm.selectedScreen == .dashboard)
    }

    @Test("restoreFromSnapshot restores data and navigates to results")
    func restoreFromSnapshotRestores() {
        let vm = makeVM()
        let results = [makeResult("c1", moduleId: "privacy", status: .pass)]
        let summaries = [ModuleSummary(id: "privacy", name: "隐私", passed: 1, failed: 0, total: 1)]
        vm.savedSnapshot = SavedAuditSnapshot(
            timestamp: Date(),
            version: "v0.3.2",
            systemScore: 100,
            results: results,
            moduleSummaries: summaries
        )
        vm.restoreFromSnapshot()
        #expect(vm.results.count == 1)
        #expect(vm.moduleSummaries.count == 1)
        #expect(vm.selectedScreen == .results)
    }

    // MARK: - ModuleSummary score

    @Test("ModuleSummary score computes correctly")
    func moduleSummaryScore() {
        let s = ModuleSummary(id: "m1", name: "M1", passed: 8, failed: 2, total: 10)
        #expect(s.score == 80)
    }

    @Test("ModuleSummary score is 100 when total is 0")
    func moduleSummaryScoreZeroTotal() {
        let s = ModuleSummary(id: "m1", name: "M1", passed: 0, failed: 0, total: 0)
        #expect(s.score == 100)
    }

    // MARK: - AppConstants

    @Test("AppConstants has expected values")
    func appConstants() {
        #expect(AppConstants.version == "v0.3.2")
        #expect(AppConstants.moduleCount == 12)
        #expect(AppConstants.checkCount == "476+")
    }

    // MARK: - repairActionCounts

    @Test("repairActionCounts returns zero when no results")
    func repairActionCountsEmpty() {
        let vm = makeVM()
        let counts = vm.repairActionCounts
        #expect(counts.safe == 0)
        #expect(counts.medium == 0)
        #expect(counts.critical == 0)
    }

    // MARK: - hasRepairActions

    @Test("hasRepairActions is false when no results")
    func hasRepairActionsEmpty() {
        let vm = makeVM()
        #expect(vm.hasRepairActions == false)
    }

    // MARK: - generateSafeScript / generateMediumScript / generateCriticalScript

    @Test("generateSafeScript returns no-fix message when empty")
    func generateSafeScriptEmpty() {
        let vm = makeVM()
        #expect(vm.generateSafeScript().hasPrefix("# No safe fixes"))
    }

    @Test("generateMediumScript returns no-fix message when empty")
    func generateMediumScriptEmpty() {
        let vm = makeVM()
        #expect(vm.generateMediumScript().hasPrefix("# No medium-risk"))
    }

    @Test("generateCriticalScript returns no-fix message when empty")
    func generateCriticalScriptEmpty() {
        let vm = makeVM()
        #expect(vm.generateCriticalScript().hasPrefix("# No critical"))
    }

    @Test("generateRepairScript returns no-fix message when empty")
    func generateRepairScriptEmpty() {
        let vm = makeVM()
        #expect(vm.generateRepairScript().contains("无需修复"))
    }

    // MARK: - moduleFixCounts

    @Test("moduleFixCounts is empty when no results")
    func moduleFixCountsEmpty() {
        let vm = makeVM()
        #expect(vm.moduleFixCounts.isEmpty)
    }

    // MARK: - generateSingleFixScript

    @Test("generateSingleFixScript returns nil for unknown check")
    func generateSingleFixScriptUnknown() {
        let vm = makeVM()
        #expect(vm.generateSingleFixScript(for: "nonexistent") == nil)
    }

    // MARK: - injectTestResults / injectTestSummaries

    @Test("injectTestResults sets results directly")
    func injectTestResults() {
        let vm = makeVM()
        let results = [
            makeResult("c1", moduleId: "privacy", status: .pass),
            makeResult("c2", moduleId: "privacy", status: .fail),
        ]
        vm.injectTestResults(results)
        #expect(vm.results.count == 2)
    }

    @Test("injectTestSummaries sets summaries directly")
    func injectTestSummaries() {
        let vm = makeVM()
        let summaries = [
            ModuleSummary(id: "privacy", name: "隐私", passed: 5, failed: 0, total: 5),
        ]
        vm.injectTestSummaries(summaries)
        #expect(vm.moduleSummaries.count == 1)
    }

    // MARK: - invalidateChecksCache

    @Test("invalidateChecksCache does not crash")
    func invalidateChecksCache() {
        let vm = makeVM()
        vm.invalidateChecksCache()
        #expect(vm.check(for: "nonexistent") == nil)
    }

    // MARK: - check(for:)

    @Test("check(for:) returns nil for unknown check id")
    func checkForUnknown() {
        let vm = makeVM()
        #expect(vm.check(for: "nonexistent_check_id") == nil)
    }

    // MARK: - startAudit guard

    @Test("startAudit is guarded when already scanning")
    func startAuditGuardedWhenScanning() async {
        let vm = makeVM()
        vm.isScanning = true
        await vm.startAudit()
        #expect(vm.isScanning == true)
    }

    // MARK: - runSingleModule integration

    @Test("runSingleModule does nothing when isScanning is true")
    func runSingleModuleBlockedWhileScanning() async {
        let vm = makeVM()
        vm.isScanning = true
        await vm.runSingleModule("privacy")
        #expect(vm.results.isEmpty)
    }

    @Test("runSingleModule does nothing for unknown moduleId")
    func runSingleModuleUnknownModule() async {
        let vm = makeVM()
        await vm.runSingleModule("nonexistent_module_xyz")
        #expect(vm.results.isEmpty)
    }

    @Test("runSingleModule replaces existing results for the module")
    func runSingleModuleReplacesResults() async {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "privacy", status: .fail),
            makeResult("c2", moduleId: "network_security", status: .pass),
        ])
        let privacyBefore = vm.results.filter { $0.moduleId == "privacy" }.count
        #expect(privacyBefore == 1)
        await vm.runSingleModule("privacy")
        let networkAfter = vm.results.filter { $0.moduleId == "network_security" }.count
        #expect(networkAfter == 1)
    }

    // MARK: - A0 Defect: executeCommand returns ShellResult (D2)

    @Test("executeCommand returns success result for valid command")
    func executeCommandReturnsSuccess() async {
        let vm = makeVM()
        let result = await vm.executeCommand("echo hello")
        #expect(result.isSuccess)
        #expect(result.trimmedOutput.contains("hello"))
    }

    @Test("executeCommand returns failure result for invalid command")
    func executeCommandReturnsFailure() async {
        let vm = makeVM()
        let result = await vm.executeCommand("exit 1")
        #expect(!result.isSuccess)
    }

    @Test("executeCommand returns failure result for nonexistent command")
    func executeCommandReturnsFailureNonexistent() async {
        let vm = makeVM()
        let result = await vm.executeCommand("/nonexistent/binary")
        #expect(!result.isSuccess)
    }
}
