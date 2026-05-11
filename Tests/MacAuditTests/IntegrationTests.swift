import Testing
@testable import MacAudit
import Foundation

// MARK: - Integration TestModule

private struct IntegrationTestModule: AuditModule {
    let id = "integration_test"
    let name = "Integration Test Module"

    private let checks_: [AuditCheck] = [
        AuditCheck(id: "it.pass", name: "Pass Check", module: "integration_test",
                   command: "echo yes", expected: "yes"),
        AuditCheck(id: "it.fail", name: "Fail Check", module: "integration_test",
                   command: "echo no", expected: "yes"),
        AuditCheck(id: "it.info", name: "Info Check", module: "integration_test",
                   command: "echo someinfo"),  // no expected → info
    ]

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        checks_
    }

    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks_, executor: executor)
    }
}

// MARK: - Full flow with real ShellExecutor

@Test("Integration: AuditRunner runAll produces one result per check")
func integrationResultCountMatchesChecks() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    #expect(results.count == 3)
}

@Test("Integration: pass check produces pass result")
func integrationPassCheck() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let passResult = results.first { $0.checkId == "it.pass" }
    #expect(passResult?.status == .pass)
}

@Test("Integration: fail check produces fail result")
func integrationFailCheck() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let failResult = results.first { $0.checkId == "it.fail" }
    #expect(failResult?.status == .fail)
}

@Test("Integration: info check (no expectedValue) produces info result")
func integrationInfoCheck() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let infoResult = results.first { $0.checkId == "it.info" }
    #expect(infoResult?.status == .info)
}

@Test("Integration: runModule returns results for integration_test")
func integrationRunModule() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runModule("integration_test")
    #expect(results != nil)
    #expect(results?.count == 3)
}

@Test("Integration: runModule returns nil for unknown id")
func integrationRunModuleUnknown() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runModule("does_not_exist")
    #expect(results == nil)
}

@Test("Integration: AuditResult actualValue is populated for pass check")
func integrationActualValuePopulated() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let passResult = results.first { $0.checkId == "it.pass" }
    #expect(passResult?.actualValue == "yes")
}

// MARK: - All 13 real modules can be instantiated

@Test("Integration: all 12 real modules can be instantiated")
func integrationAllModulesInstantiate() {
    let modules: [any AuditModule] = [
        SystemInfoModule(),
        NetworkSecurityModule(),
        PrivacyModule(),
        AnimationModule(),
        ServicesModule(),
        PowerModule(),
        ShellModule(),
        ClaudeProtectionModule(),
        DevEnvironmentModule(),
        IPQualityModule(),
        ChromeModule(),
        SafariModule(),
    ]
    #expect(modules.count == 12)
}

@Test("Integration: all 12 real modules have non-empty ids and names")
func integrationAllModulesHaveIds() {
    let modules: [any AuditModule] = [
        SystemInfoModule(),
        NetworkSecurityModule(),
        PrivacyModule(),
        AnimationModule(),
        ServicesModule(),
        PowerModule(),
        ShellModule(),
        ClaudeProtectionModule(),
        DevEnvironmentModule(),
        IPQualityModule(),
        ChromeModule(),
        SafariModule(),
    ]
    for module in modules {
        #expect(!module.id.isEmpty)
        #expect(!module.name.isEmpty)
    }
}

@Test("Integration: all 12 real modules have checks for sequoia/laptop")
func integrationAllModulesHaveChecks() {
    let modules: [any AuditModule] = [
        SystemInfoModule(),
        NetworkSecurityModule(),
        PrivacyModule(),
        AnimationModule(),
        ServicesModule(),
        PowerModule(),
        ShellModule(),
        ClaudeProtectionModule(),
        DevEnvironmentModule(),
        IPQualityModule(),
        ChromeModule(),
        SafariModule(),
    ]
    for module in modules {
        let count = module.checkCount(for: .sequoia, device: .laptop, arch: .arm64)
        #expect(count > 0, "Module \(module.id) should have at least 1 check")
    }
}

@Test("Integration: ReportGenerator produces valid JSON from real module results")
func integrationReportGeneratorJSON() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let json = ReportGenerator.generateJSON(
        results: results,
        modules: [module],
        version: .sequoia,
        device: .laptop,
        duration: .seconds(1)
    )
    let data = json.data(using: .utf8)!
    let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(obj != nil)
    let summary = obj?["summary"] as? [String: Any]
    #expect(summary?["total"] as? Int == 3)
}

@Test("Integration: ReportGenerator markdown from real results contains summary")
func integrationReportGeneratorMarkdown() async {
    let module = IntegrationTestModule()
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let md = ReportGenerator.generateMarkdown(
        results: results,
        modules: [module],
        version: .sequoia,
        device: .laptop,
        duration: .seconds(1)
    )
    #expect(md.contains("摘要") || md.contains("MacAudit"))
}
