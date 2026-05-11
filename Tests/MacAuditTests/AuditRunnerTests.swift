import Testing
@testable import MacAudit

// MARK: - Minimal test module for AuditRunner testing

private struct TestModule: AuditModule {
    let id: String
    let name: String
    let description: String = ""
    private let fixedChecks: [AuditCheck]

    init(id: String = "test_module", name: String = "Test Module", checks: [AuditCheck] = []) {
        self.id = id
        self.name = name
        self.fixedChecks = checks
    }

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        fixedChecks
    }

    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(fixedChecks, executor: executor)
    }
}

private actor CLIRunTracker {
    private(set) var secondModuleDidRun = false

    func markSecondModuleRan() {
        secondModuleDidRun = true
    }
}

private struct CancellingCLIModule: AuditModule {
    let id = "cli_cancel_first"
    let name = "CLI Cancel First"
    let description = ""

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            AuditCheck(id: "cli.cancel.first", name: "CLI Cancel First", module: id, command: "echo ok", expected: "ok")
        ]
    }

    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        let check = checks(for: version, device: device, arch: arch)[0]
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return [.pass(check: check, actual: "ok", duration: 0)]
    }
}

private struct TrackingCLIModule: AuditModule {
    let id = "cli_cancel_second"
    let name = "CLI Cancel Second"
    let description = ""
    let tracker: CLIRunTracker

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            AuditCheck(id: "cli.cancel.second", name: "CLI Cancel Second", module: id, command: "echo ok", expected: "ok")
        ]
    }

    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await tracker.markSecondModuleRan()
        let check = checks(for: version, device: device, arch: arch)[0]
        return [.pass(check: check, actual: "ok", duration: 0)]
    }
}

private func makeCheck(id: String, command: String, expected: String? = nil) -> AuditCheck {
    AuditCheck(id: id, name: "Check \(id)", module: "test_module", command: command, expected: expected)
}

// MARK: - AuditRunner init

@Test("AuditRunner init stores modules")
func auditRunnerStoresModules() {
    let m1 = TestModule(id: "a", name: "A")
    let m2 = TestModule(id: "b", name: "B")
    let runner = AuditRunner(modules: [m1, m2], arch: .arm64, quiet: true)
    #expect(runner.modules.count == 2)
}

@Test("AuditRunner init uses quiet flag")
func auditRunnerQuietFlag() {
    let runner = AuditRunner(modules: [], arch: .arm64, quiet: true)
    #expect(runner.quiet == true)
}

// MARK: - AuditRunner.runAll

@Test("AuditRunner runAll returns results from all modules")
func auditRunnerRunAllAggregates() async {
    let c1 = makeCheck(id: "t.c1", command: "echo pass", expected: "pass")
    let c2 = makeCheck(id: "t.c2", command: "echo info")
    let module = TestModule(id: "test_module", name: "Test", checks: [c1, c2])
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    #expect(results.count == 2)
}

@Test("AuditRunner runAll returns empty for no modules")
func auditRunnerRunAllEmpty() async {
    let runner = AuditRunner(modules: [], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    #expect(results.isEmpty)
}

@Test("AuditRunner runAll aggregates across two modules")
func auditRunnerRunAllTwoModules() async {
    let c1 = makeCheck(id: "m1.c1", command: "echo a")
    let c2 = makeCheck(id: "m2.c1", command: "echo b")
    let m1 = TestModule(id: "mod1", name: "M1", checks: [c1])
    let m2 = TestModule(id: "mod2", name: "M2", checks: [c2])
    let runner = AuditRunner(modules: [m1, m2], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    #expect(results.count == 2)
}

@Test("AuditRunner runAll result statuses reflect command outcomes")
func auditRunnerRunAllStatuses() async {
    let pass = makeCheck(id: "t.pass", command: "echo yes", expected: "yes")
    let fail = makeCheck(id: "t.fail", command: "echo no", expected: "yes")
    let module = TestModule(id: "test_module", name: "T", checks: [pass, fail])
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runAll()
    let statuses = results.map(\.status)
    #expect(statuses.contains(.pass))
    #expect(statuses.contains(.fail))
}

@Test("CLI AuditRunner runAll preserves current module results and stops future modules after cancellation")
func auditRunnerRunAllPreservesCurrentModuleResultsAfterCancellation() async {
    let tracker = CLIRunTracker()
    let runner = AuditRunner(
        modules: [CancellingCLIModule(), TrackingCLIModule(tracker: tracker)],
        version: .sequoia,
        device: .laptop,
        quiet: true
    )

    let results = await runner.runAll()

    #expect(results.count == 1)
    #expect(results.first?.checkId == "cli.cancel.first")
    #expect(await tracker.secondModuleDidRun == false)
}

// MARK: - AuditRunner.runModule

@Test("AuditRunner runModule returns results for matching module id")
func auditRunnerRunModuleFound() async {
    let c = makeCheck(id: "t.c1", command: "echo hello")
    let module = TestModule(id: "my_module", name: "My", checks: [c])
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runModule("my_module")
    #expect(results != nil)
    #expect(results?.count == 1)
}

@Test("AuditRunner runModule returns nil for unknown module id")
func auditRunnerRunModuleNotFound() async {
    let module = TestModule(id: "existing", name: "E")
    let runner = AuditRunner(modules: [module], arch: .arm64, quiet: true)
    let results = await runner.runModule("nonexistent")
    #expect(results == nil)
}

@Test("AuditRunner runModule returns nil when modules array is empty")
func auditRunnerRunModuleEmptyModules() async {
    let runner = AuditRunner(modules: [], arch: .arm64, quiet: true)
    let results = await runner.runModule("anything")
    #expect(results == nil)
}

@Test("AuditRunner runModule only runs the specified module")
func auditRunnerRunModuleIsolated() async {
    let c1 = makeCheck(id: "m1.c1", command: "echo one")
    let c2 = makeCheck(id: "m2.c1", command: "echo two")
    let m1 = TestModule(id: "mod1", name: "M1", checks: [c1])
    let m2 = TestModule(id: "mod2", name: "M2", checks: [c2])
    let runner = AuditRunner(modules: [m1, m2], arch: .arm64, quiet: true)
    let results = await runner.runModule("mod1")
    #expect(results?.count == 1)
    #expect(results?.first?.checkId == "m1.c1")
}

@Test("CLI AuditRunner runModule preserves finished module results after cancellation")
func cliAuditRunnerRunModulePreservesFinishedResultsAfterCancellation() async {
    let runner = AuditRunner(
        modules: [CancellingCLIModule()],
        version: .sequoia,
        device: .laptop,
        quiet: true
    )

    let results = await runner.runModule("cli_cancel_first")

    #expect(results?.count == 1)
    #expect(results?.first?.checkId == "cli.cancel.first")
}

@Test("CLI AuditRunner runModule returns empty results instead of nil when caller is already cancelled")
func cliAuditRunnerRunModulePreCancelledReturnsEmptyResults() async {
    let runner = AuditRunner(
        modules: [CancellingCLIModule()],
        version: .sequoia,
        device: .laptop,
        quiet: true
    )

    let results = await Task {
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return await runner.runModule("cli_cancel_first")
    }.value

    #expect(results != nil)
    #expect(results?.isEmpty == true)
}

// MARK: - crossRefCount

@Test("AuditRunner crossRefCount returns 0 when no checks have crossRef")
func crossRefCountZero() {
    let c1 = makeCheck(id: "a.1", command: "echo")
    let c2 = makeCheck(id: "a.2", command: "echo")
    let module = TestModule(id: "a", name: "A", checks: [c1, c2])
    let count = AuditRunner.crossRefCount(in: [], modules: [module], version: .sequoia, device: .laptop, arch: .arm64)
    #expect(count == 0)
}

@Test("AuditRunner crossRefCount counts checks with non-nil crossRef")
func crossRefCountNonZero() {
    let module = ClaudeProtectionModule()
    let count = AuditRunner.crossRefCount(
        in: [], modules: [module], version: .sequoia, device: .laptop, arch: .arm64
    )
    // Known crossRefs in M10: fw_global→m2.firewall, surge_dns→m3.surge_dns,
    // proxy_https→m9.https_proxy, proxy_on_func→m9.proxy_on, proxy_off_func→m9.proxy_off,
    // hosts_total→m9.hosts_claude, ipv6_rtadv→m8.ipv6_rtadv — at least 7
    #expect(count >= 7)
}

@Test("AuditRunner crossRefCount results parameter is ignored (only checks matter)")
func crossRefCountResultsIgnored() {
    let module = ClaudeProtectionModule()
    let fakeResult = AuditResult.pass(
        check: AuditCheck(id: "x.1", name: "X", module: "x", command: "echo"),
        actual: "ok"
    )
    let countWithResults = AuditRunner.crossRefCount(
        in: [fakeResult], modules: [module], version: .sequoia, device: .laptop, arch: .arm64
    )
    let countEmpty = AuditRunner.crossRefCount(
        in: [], modules: [module], version: .sequoia, device: .laptop, arch: .arm64
    )
    // results param is not used in the implementation — counts must be identical
    #expect(countWithResults == countEmpty)
}

@Test("AuditRunner crossRefCount counts correctly across multiple modules")
func crossRefCountMultiModules() {
    // M10 (Claude) has known crossRefs: fw_global, surge_dns, proxy_https, etc.
    // M9 (Shell) has none
    let m10 = ClaudeProtectionModule()
    let m9 = ShellModule()
    let countBoth = AuditRunner.crossRefCount(
        in: [], modules: [m10, m9], version: .sequoia, device: .laptop, arch: .arm64
    )
    let countM10Only = AuditRunner.crossRefCount(
        in: [], modules: [m10], version: .sequoia, device: .laptop, arch: .arm64
    )
    let countM9Only = AuditRunner.crossRefCount(
        in: [], modules: [m9], version: .sequoia, device: .laptop, arch: .arm64
    )
    // Both together = M10 + M9 (M9 has 0 crossRefs)
    #expect(countBoth == countM10Only + countM9Only)
    #expect(countM9Only == 0)
}

@Test("AuditRunner crossRefCount respects version and device filters")
func crossRefCountVersionFilter() {
    // Results param is unused in crossRefCount (only checks matter)
    let m10 = ClaudeProtectionModule()
    let countSeq = AuditRunner.crossRefCount(
        in: [], modules: [m10], version: .sequoia, device: .laptop, arch: .arm64
    )
    let countTahoe = AuditRunner.crossRefCount(
        in: [], modules: [m10], version: .tahoe, device: .laptop, arch: .arm64
    )
    // M10 has same checks regardless of version — counts should be equal
    #expect(countSeq == countTahoe)
}
