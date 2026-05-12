import Testing
@testable import MacAudit
import Foundation

// MARK: - Helpers

private struct FakeModule: AuditModule {
    let id: String
    let name: String
    let description = ""
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] { [] }
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] { [] }
}

private func makeCheck(id: String, module: String = "m1") -> AuditCheck {
    AuditCheck(id: id, name: "Check \(id)", module: module, command: "echo x")
}

private func zeroDuration() -> Duration { .seconds(0) }

// MARK: - Markdown report

@Test("ReportGenerator markdown contains report title")
func markdownHasTitle() {
    let results: [AuditResult] = []
    let md = ReportGenerator.generateMarkdown(
        results: results, modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("MacAudit"))
}

@Test("ReportGenerator markdown contains summary section")
func markdownHasSummarySection() {
    let md = ReportGenerator.generateMarkdown(
        results: [], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("摘要") || md.contains("Summary"))
}

@Test("ReportGenerator markdown counts pass results correctly")
func markdownPassCount() {
    let check = makeCheck(id: "m1.x")
    let result = AuditResult.pass(check: check, actual: "ok")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    // The summary table contains "| 通过 | 1 |" exactly
    #expect(md.contains("| 通过 | 1 |"))
}

@Test("ReportGenerator markdown counts fail results correctly")
func markdownFailCount() {
    let check = makeCheck(id: "m1.x")
    let result = AuditResult.fail(check: check, actual: "bad")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    // The summary table contains "| 失败 | 1 |" exactly
    #expect(md.contains("| 失败 | 1 |"))
}

@Test("ReportGenerator markdown includes device info")
func markdownHasDeviceInfo() {
    let md = ReportGenerator.generateMarkdown(
        results: [], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let hasDevice = md.contains("laptop") || md.contains("MacBook") || md.contains("设备")
    #expect(hasDevice)
}

@Test("ReportGenerator markdown includes module section when results present")
func markdownHasModuleSection() {
    let check = AuditCheck(id: "m1.test", name: "Test Check", module: "system_info", command: "echo x")
    let result = AuditResult.pass(check: check, actual: "x")
    let module = FakeModule(id: "system_info", name: "系统信息")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [module],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("系统信息"))
}

// MARK: - JSON report

@Test("ReportGenerator JSON is valid JSON")
func jsonIsValidJSON() {
    let json = ReportGenerator.generateJSON(
        results: [], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let data = json.data(using: .utf8)!
    let obj = try? JSONSerialization.jsonObject(with: data)
    #expect(obj != nil)
}

@Test("ReportGenerator JSON contains version key")
func jsonHasVersionKey() {
    let json = ReportGenerator.generateJSON(
        results: [], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let data = json.data(using: .utf8)!
    let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    // Parse JSON and verify version key exists with expected string value
    #expect(obj?["version"] as? String == "0.3.2")
}

@Test("ReportGenerator JSON contains summary with correct total")
func jsonSummaryTotal() {
    let check = makeCheck(id: "m1.x")
    let r1 = AuditResult.pass(check: check, actual: "ok")
    let r2 = AuditResult.fail(check: check, actual: "bad")
    let json = ReportGenerator.generateJSON(
        results: [r1, r2], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let data = json.data(using: .utf8)!
    let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    let summary = obj?["summary"] as? [String: Any]
    #expect(summary?["total"] as? Int == 2)
}

@Test("ReportGenerator JSON contains pass and fail counts")
func jsonSummaryPassFail() {
    let check = makeCheck(id: "m1.x")
    let results = [
        AuditResult.pass(check: check, actual: "ok"),
        AuditResult.fail(check: check, actual: "bad"),
        AuditResult.warn(check: check, actual: "meh"),
    ]
    let json = ReportGenerator.generateJSON(
        results: results, modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let data = json.data(using: .utf8)!
    let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    let summary = obj?["summary"] as? [String: Any]
    #expect(summary?["pass"] as? Int == 1)
    #expect(summary?["fail"] as? Int == 1)
    #expect(summary?["warn"] as? Int == 1)
}

@Test("ReportGenerator JSON results array has correct length")
func jsonResultsArray() {
    let check = makeCheck(id: "m1.x")
    let results = [
        AuditResult.pass(check: check, actual: "ok"),
        AuditResult.info(check: check, actual: "info"),
    ]
    let json = ReportGenerator.generateJSON(
        results: results, modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let data = json.data(using: .utf8)!
    let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    let arr = obj?["results"] as? [[String: Any]]
    #expect(arr?.count == 2)
}

// MARK: - moduleId 和 ip_quality 报告覆盖测试

@Test("ReportGenerator markdown includes ip_quality module section")
func markdownHasIPQualitySection() {
    let check = AuditCheck(id: "m13.public_ipv4", name: "Public IPv4", module: "ip_quality", command: "curl")
    let result = AuditResult.info(check: check, actual: "1.2.3.4")
    let module = FakeModule(id: "ip_quality", name: "IP 质量检测")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [module],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("IP 质量检测"))
    #expect(md.contains("Public IPv4"))
}

@Test("ReportGenerator JSON results include moduleId field")
func jsonResultsHaveModuleId() {
    let check = AuditCheck(id: "m13.ip", name: "IP", module: "ip_quality", command: "curl")
    let result = AuditResult.pass(check: check, actual: "ok")
    let json = ReportGenerator.generateJSON(
        results: [result], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(json.contains("\"moduleId\""))
    #expect(json.contains("ip_quality"))
}

@Test("ReportGenerator markdown groups results by moduleId not checkId prefix")
func markdownGroupsByModuleId() {
    // ip_quality checkId starts with m13 but module.id is ip_quality
    let check1 = AuditCheck(id: "m13.ipv4", name: "IPv4", module: "ip_quality", command: "curl")
    let check2 = AuditCheck(id: "m13.geo", name: "Geo", module: "ip_quality", command: "curl")
    let results = [
        AuditResult.pass(check: check1, actual: "1.2.3.4"),
        AuditResult.info(check: check2, actual: "US"),
    ]
    let module = FakeModule(id: "ip_quality", name: "IP 质量检测")
    let md = ReportGenerator.generateMarkdown(
        results: results, modules: [module],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    // Both checks should appear under the ip_quality module section
    #expect(md.contains("IPv4"))
    #expect(md.contains("Geo"))
}

// MARK: - 可修复项摘要节测试

@Test("ReportGenerator markdown includes fixable summary when there are failures with expectedValue")
func markdownHasFixableSummary() {
    let check = AuditCheck(id: "m2.sip", name: "SIP 状态", module: "security",
                           command: "csrutil status", expected: "enabled")
    let result = AuditResult.fail(check: check, actual: "disabled")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("可修复项摘要"))
    #expect(md.contains("macaudit --fix"))
    #expect(md.contains("SIP 状态"))
    #expect(md.contains("disabled"))
    #expect(md.contains("enabled"))
}

@Test("ReportGenerator markdown does not include fixable summary when all pass")
func markdownNoFixableSummaryWhenAllPass() {
    let check = AuditCheck(id: "m2.sip", name: "SIP 状态", module: "security",
                           command: "csrutil status", expected: "enabled")
    let result = AuditResult.pass(check: check, actual: "enabled")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(!md.contains("可修复项摘要"))
}

@Test("ReportGenerator markdown fixable summary includes moduleId column")
func markdownFixableSummaryHasModuleId() {
    let check = AuditCheck(id: "m7.ac_sleep", name: "接电睡眠", module: "power",
                           command: "pmset -g", expected: "0")
    let result = AuditResult.fail(check: check, actual: "15")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("power"))
    #expect(md.contains("接电睡眠"))
}


@Test("ReportGenerator writeToFile writes content to disk")
func reportWriteToFile() throws(any Error) {
    let tmpDir = FileManager.default.temporaryDirectory
    let path = tmpDir.appendingPathComponent("test_report_\(UUID().uuidString).md").path
    try ReportGenerator.writeToFile("# Hello\n", path: path)
    let content = try String(contentsOfFile: path, encoding: .utf8)
    #expect(content == "# Hello\n")
    try? FileManager.default.removeItem(atPath: path)
}

// MARK: - Pipe character and newline escaping

@Test("ReportGenerator markdown escapes pipe character in actualValue")
func markdownEscapesPipeInActualValue() {
    let check = AuditCheck(id: "m1.x", name: "Test", module: "m1", command: "echo")
    // actualValue contains | which should be escaped as \| in markdown table
    let result = AuditResult.info(check: check, actual: "val1 | val2")
    let module = FakeModule(id: "m1", name: "System Info")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [module],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("val1 \\| val2"))
    #expect(!md.contains("val1 | val2"))
}

@Test("ReportGenerator markdown replaces newline with space in actualValue")
func markdownReplacesNewlineInActualValue() {
    let check = AuditCheck(id: "m1.x", name: "Test", module: "m1", command: "echo")
    let result = AuditResult.info(check: check, actual: "line1\nline2")
    let module = FakeModule(id: "m1", name: "System Info")
    let md = ReportGenerator.generateMarkdown(
        results: [result], modules: [module],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("line1 line2"))
    // Original newline should not appear inside the table row
    let tableSection = md.components(separatedBy: "## System Info").last ?? ""
    #expect(!tableSection.contains("line1\nline2"))
}

// MARK: - writeToFile error path

@Test("ReportGenerator writeToFile throws when directory does not exist")
func reportWriteToFileThrowsOnMissingDir() {
    let badPath = "/nonexistent_dir_\(UUID().uuidString)/report.md"
    #expect(throws: (any Error).self) {
        try ReportGenerator.writeToFile("# Test\n", path: badPath)
    }
}

// MARK: - version nil in markdown

@Test("ReportGenerator markdown shows 未知 when version is nil")
func markdownNilVersion() {
    let md = ReportGenerator.generateMarkdown(
        results: [], modules: [],
        version: nil, device: .laptop, duration: zeroDuration()
    )
    #expect(md.contains("未知"))
}

// MARK: - fixable summary sort order

@Test("ReportGenerator markdown fixable summary sorts high risk before low risk")
func markdownFixableSummarySortOrder() {
    let lowCheck = AuditCheck(id: "m1.low", name: "低风险项", module: "m1",
                              command: "echo", expected: "1", risk: .low)
    let highCheck = AuditCheck(id: "m2.high", name: "高风险项", module: "m2",
                               command: "echo", expected: "1", risk: .high)
    let results = [
        AuditResult.fail(check: lowCheck, actual: "0"),
        AuditResult.fail(check: highCheck, actual: "0"),
    ]
    let md = ReportGenerator.generateMarkdown(
        results: results, modules: [],
        version: .sequoia, device: .laptop, duration: zeroDuration()
    )
    let highIdx = md.range(of: "高风险项")?.lowerBound
    let lowIdx = md.range(of: "低风险项")?.lowerBound
    #expect(highIdx != nil && lowIdx != nil)
    if let h = highIdx, let l = lowIdx {
        #expect(h < l)
    }
}
