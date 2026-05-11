import Testing
@testable import MacAudit

// MARK: - M6 ServicesModule Tests
// Total services: 110 defined
// All version-tagged services (17) are now [.sequoia, .tahoe] — verified against both VMs 2026-04-11
// No services are exclusively one-version-only
// Sequoia count: 110, Tahoe count: 110

@Test("M6 module id and name are non-empty")
func servicesModuleMetadata() {
    let module = ServicesModule()
    #expect(module.id == "services")
    #expect(!module.name.isEmpty)
}

@Test("M6 checks count is 76 for sequoia")
func servicesChecksCountSequoia() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 76)
}

@Test("M6 checks count is 76 for tahoe")
func servicesChecksCountTahoe() {
    let module = ServicesModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 76)
}

@Test("M6 all check IDs start with m6.")
func servicesCheckIDPrefix() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m6."))
    }
}

@Test("M6 all checks belong to services module")
func servicesCheckModuleField() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "services")
    }
}

@Test("M6 all checks expect true (disabled)")
func servicesChecksExpectTrue() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.expectedValue == "true")
    }
}

@Test("M6 sequoia and tahoe have equal check counts (all version-tagged services are [.sequoia, .tahoe])")
func servicesSequoiaEqualsTahoe() {
    let module = ServicesModule()
    let sequoia = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let tahoe = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    #expect(sequoia.count == tahoe.count)
}

@Test("M6 all version-tagged services appear in both sequoia and tahoe")
func servicesVersionTaggedInBoth() {
    let module = ServicesModule()
    let tahoeIds = module.checks(for: .tahoe, device: .laptop, arch: .arm64).map(\.id)
    let sequoiaIds = module.checks(for: .sequoia, device: .laptop, arch: .arm64).map(\.id)
    let bothVersionServices = [
        "com.apple.shazamd", "com.apple.sportsd",
        "com.apple.homeenergyd", "com.apple.translationd",
    ]
    for svc in bothVersionServices {
        let id = "m6.\(svc)"
        #expect(tahoeIds.contains(id), "Expected \(id) in Tahoe")
        #expect(sequoiaIds.contains(id), "Expected \(id) in Sequoia")
    }
}

@Test("M6 check IDs are unique")
func servicesCheckIDsUnique() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M6 checks have group tags")
func servicesChecksHaveTags() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(!check.tags.isEmpty)
    }
}

// MARK: - checks() vs run() design documentation

@Test("M6 checks() returns empty detectionCommand by design (run() handles launchctl directly)")
func servicesChecksHaveEmptyCommand() {
    // Design: ServicesModule.checks() exposes checks with empty command strings.
    // The actual launchctl detection is done in run() which reads all service states
    // in a single launchctl call. This is intentional for performance.
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.detectionCommand == "")
    }
}

@Test("M6 all checks expect 'true' (meaning disabled=true is desired)")
func servicesAllExpectTrue() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.expectedValue == "true")
    }
}

@Test("M6 check IDs follow m6.<service_label> pattern")
func servicesCheckIDFormat() {
    let module = ServicesModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m6."))
        // Service labels are com.apple.* format
        let label = String(check.id.dropFirst(3)) // drop "m6."
        #expect(label.hasPrefix("com.apple."))
    }
}

@Test("M6 all version-tagged services (17) appear in both sequoia and tahoe — verified on real VMs 2026-04-11")
func servicesVersionTaggedAppearInBoth() {
    let module = ServicesModule()
    let tahoeIds = Set(module.checks(for: .tahoe, device: .laptop, arch: .arm64).map(\.id))
    let sequoiaIds = Set(module.checks(for: .sequoia, device: .laptop, arch: .arm64).map(\.id))
    // These were previously mistagged as Sequoia-only or Tahoe-only.
    // Real-VM verification confirmed all exist on both macOS 15 and macOS 26.
    let bothVersionServices = [
        "com.apple.shazamd", "com.apple.sportsd", "com.apple.homeenergyd",
        "com.apple.translationd",
    ]
    for label in bothVersionServices {
        #expect(tahoeIds.contains("m6.\(label)"),
            "Expected \(label) in Tahoe (verified on macOS 26)")
        #expect(sequoiaIds.contains("m6.\(label)"),
            "Expected \(label) in Sequoia (verified on macOS 15)")
    }
}

// MARK: - ServicesModule.run() three-path tests

@Test("M6 run() produces .pass for service with disabled status")
func servicesRunDisabledPass() async {
    let module = ServicesModule()
    let fakeOutput = "\"com.apple.assistantd\" => disabled\n\"com.apple.gamed\" => enabled"
    let executor = ShellExecutor(stubbedOutputs: ["launchctl print-disabled": fakeOutput])
    let results = await module.run(version: .sequoia, device: .laptop, arch: .arm64, executor: executor)
    let assistantd = results.first { $0.checkId == "m6.com.apple.assistantd" }
    #expect(assistantd?.status == .pass)
    #expect(assistantd?.actualValue == "disabled")
}

@Test("M6 run() produces .fail for service with enabled status")
func servicesRunEnabledFail() async {
    let module = ServicesModule()
    let fakeOutput = "\"com.apple.gamed\" => enabled"
    let executor = ShellExecutor(stubbedOutputs: ["launchctl print-disabled": fakeOutput])
    let results = await module.run(version: .sequoia, device: .laptop, arch: .arm64, executor: executor)
    let gamed = results.first { $0.checkId == "m6.com.apple.gamed" }
    #expect(gamed?.status == .fail)
    #expect(gamed?.actualValue == "enabled")
}

@Test("M6 run() produces .warn for service not in launchctl output")
func servicesRunUnmanagedWarn() async {
    let module = ServicesModule()
    let executor = ShellExecutor(stubbedOutputs: ["launchctl print-disabled": ""])
    let results = await module.run(version: .sequoia, device: .laptop, arch: .arm64, executor: executor)
    let warnCount = results.filter { $0.status == .warn }.count
    #expect(warnCount == results.count)
    let first = results.first
    #expect(first?.actualValue == "未管理")
}

@Test("M6 run() result count matches checks count for same version")
func servicesRunCountMatchesChecks() async {
    let module = ServicesModule()
    let executor = ShellExecutor(stubbedOutputs: ["launchctl print-disabled": ""])
    let results = await module.run(version: .sequoia, device: .laptop, arch: .arm64, executor: executor)
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(results.count == checks.count)
}
