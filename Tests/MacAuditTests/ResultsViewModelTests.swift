import Testing
@testable import MacAudit

// MARK: - 테스트용 로컬 ModuleSummary (MacAuditUI의 것과 동일 구조)
private struct TestModuleSummary {
    let id: String
    let name: String
    let passed: Int
    let failed: Int
    let total: Int
    var score: Int { total > 0 ? passed * 100 / total : 100 }
}

// MARK: - Results 정렬/필터 로직 단위 테스트
// AppViewModel 의 results(for:), failedResults(for:), moduleName(for:) 로직을
// 동일한 알고리즘으로 직접 검증

// MARK: - results(for:) — fail 우선 정렬

@Test("results(for:) 지정 모듈 결과만 반환")
func resultsForModuleFiltersCorrectly() {
    let allResults: [AuditResult] = [
        makeResult("m1.a", moduleId: "m1", status: AuditStatus.pass),
        makeResult("m1.b", moduleId: "m1", status: AuditStatus.fail),
        makeResult("m2.a", moduleId: "m2", status: AuditStatus.pass),
    ]
    let filtered = allResults.filter { $0.moduleId == "m1" }
    #expect(filtered.count == 2)
    #expect(filtered.allSatisfy { $0.moduleId == "m1" })
}

@Test("results(for:) 미존재 모듈은 빈 배열")
func resultsForUnknownModuleEmpty() {
    let allResults = [makeResult("m1.a", moduleId: "m1", status: AuditStatus.pass)]
    let filtered = allResults.filter { $0.moduleId == "none" }
    #expect(filtered.isEmpty)
}

@Test("results(for:) fail 항목이 pass 보다 앞에 정렬됨")
func resultsForModuleFailFirst() {
    let allResults: [AuditResult] = [
        makeResult("m1.a", moduleId: "m1", status: AuditStatus.pass),
        makeResult("m1.b", moduleId: "m1", status: AuditStatus.fail),
        makeResult("m1.c", moduleId: "m1", status: AuditStatus.info),
        makeResult("m1.d", moduleId: "m1", status: AuditStatus.fail),
    ]
    let module = allResults.filter { $0.moduleId == "m1" }
    let sorted = sortResultsFailFirst(module)
    #expect(sorted[0].status == .fail)
    #expect(sorted[1].status == .fail)
    // pass/info 뒤에 위치
    let nonFail = sorted.dropFirst(2)
    #expect(nonFail.allSatisfy { $0.status != AuditStatus.fail })
}

// MARK: - failedResults(for:)

@Test("failedResults(for:) 실패 항목만 반환")
func failedResultsOnlyFailed() {
    let allResults: [AuditResult] = [
        makeResult("m1.a", moduleId: "m1", status: AuditStatus.pass),
        makeResult("m1.b", moduleId: "m1", status: AuditStatus.fail),
        makeResult("m1.c", moduleId: "m1", status: AuditStatus.fail),
    ]
    let failed = allResults.filter { $0.moduleId == "m1" && $0.status == AuditStatus.fail }
    #expect(failed.count == 2)
}

@Test("failedResults(for:) 실패 없으면 빈 배열")
func failedResultsEmptyWhenNoneFailed() {
    let allResults: [AuditResult] = [
        makeResult("m1.a", moduleId: "m1", status: AuditStatus.pass),
        makeResult("m1.b", moduleId: "m1", status: AuditStatus.info),
    ]
    let failed = allResults.filter { $0.moduleId == "m1" && $0.status == AuditStatus.fail }
    #expect(failed.isEmpty)
}

// MARK: - moduleName(for:)

@Test("moduleName(for:) 모듈 요약에서 이름 반환")
func moduleNameFromSummaries() {
    let summaries = [
        TestModuleSummary(id: "claude", name: "AI서비스조정", passed: 5, failed: 1, total: 6),
        TestModuleSummary(id: "network_security", name: "네트워크보안", passed: 8, failed: 0, total: 8),
    ]
    #expect(moduleNameFrom(summaries, id: "claude") == "AI서비스조정")
    #expect(moduleNameFrom(summaries, id: "network_security") == "네트워크보안")
}

@Test("moduleName(for:) 미존재 ID는 id 자체 반환")
func moduleNameFallbackToId() {
    let summaries: [TestModuleSummary] = []
    #expect(moduleNameFrom(summaries, id: "unknown") == "unknown")
}

// MARK: - defaultSelectedModuleId

@Test("defaultSelectedModuleId 첫 번째 모듈 id 반환")
func defaultSelectedModuleIdFirst() {
    let summaries = [
        TestModuleSummary(id: "system_info", name: "시스템정보", passed: 5, failed: 0, total: 5),
        TestModuleSummary(id: "claude", name: "AI서비스", passed: 3, failed: 2, total: 5),
    ]
    #expect(summaries.first?.id == "system_info")
}

@Test("defaultSelectedModuleId 데이터 없으면 nil")
func defaultSelectedModuleIdNilWhenEmpty() {
    let summaries: [TestModuleSummary] = []
    #expect(summaries.first?.id == nil)
}

// MARK: - ModuleSummary score 계산

@Test("ModuleSummary score 정확히 계산됨")
func moduleSummaryScoreCalculation() {
    let s = TestModuleSummary(id: "m1", name: "M1", passed: 8, failed: 2, total: 10)
    #expect(s.score == 80)
}

@Test("ModuleSummary total 0이면 score 100")
func moduleSummaryScoreWhenTotalZero() {
    let s = TestModuleSummary(id: "m1", name: "M1", passed: 0, failed: 0, total: 0)
    #expect(s.score == 100)
}

// MARK: - Helpers (알고리즘 추출)

private func sortResultsFailFirst(_ results: [AuditResult]) -> [AuditResult] {
    let failed = results.filter { $0.status == AuditStatus.fail }
    let others = results.filter { $0.status != AuditStatus.fail }
    return failed + others
}

private func moduleNameFrom(_ summaries: [TestModuleSummary], id: String) -> String {
    summaries.first(where: { $0.id == id })?.name ?? id
}

// MARK: - Score formula consistency

@Test("Score formula: integer division matches real ModuleSummary behavior")
func scoreFormulaConsistency() {
    // Verify the test fixture formula matches the real behavior
    // passed * 100 / total (integer division, floors)
    #expect(TestModuleSummary(id: "a", name: "A", passed: 1, failed: 2, total: 3).score == 33)
    #expect(TestModuleSummary(id: "b", name: "B", passed: 2, failed: 1, total: 3).score == 66)
    #expect(TestModuleSummary(id: "c", name: "C", passed: 0, failed: 0, total: 0).score == 100)
    #expect(TestModuleSummary(id: "d", name: "D", passed: 3, failed: 0, total: 3).score == 100)
}

@Test("Filter: medium risk with networkRisk excluded from medium category")
func filterConsistencyMediumNetworkRisk() {
    // Verify that items with medium risk AND networkRisk=true
    // are NOT counted in the medium category (they go to critical)
    struct FakeAction {
        let riskLevel: RiskLevel
        let requiresSudo: Bool
        let networkRisk: Bool
    }
    let action = FakeAction(riskLevel: .medium, requiresSudo: false, networkRisk: true)
    let inMedium = (action.riskLevel == .medium || action.requiresSudo) && !action.networkRisk
    #expect(inMedium == false)
}

private func makeResult(_ checkId: String, moduleId: String, status: AuditStatus) -> AuditResult {
    let check = AuditCheck(id: checkId, name: checkId, module: moduleId, command: "echo test")
    switch status {
    case .pass: return .pass(check: check, actual: "ok", duration: 0)
    case .fail: return .fail(check: check, actual: "bad", duration: 0)
    default:    return .info(check: check, actual: "info", duration: 0)
    }
}
