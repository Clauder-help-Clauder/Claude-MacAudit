import Testing
@testable import MacAudit

// MARK: - M1 SystemInfoModule Tests

@Test("M1 module id and name are non-empty")
func systemInfoModuleMetadata() {
    let module = SystemInfoModule()
    #expect(!module.id.isEmpty)
    #expect(!module.name.isEmpty)
    #expect(module.id == "system_info")
}

@Test("M1 checks count is 12 for sequoia laptop")
func systemInfoChecksCountSequoiaLaptop() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 12)
}

@Test("M1 checks count is 12 for tahoe desktop")
func systemInfoChecksCountTahoeDesktop() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 12)
}

@Test("M1 all check IDs start with m1.")
func systemInfoCheckIDPrefix() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m1."))
    }
}

@Test("M1 all checks belong to system_info module")
func systemInfoCheckModuleField() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "system_info")
    }
}

@Test("M1 check names are non-empty")
func systemInfoCheckNames() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(!check.name.isEmpty)
    }
}

@Test("M1 contains m1.macos_version check")
func systemInfoContainsMacOSVersion() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(ids.contains("m1.macos_version"))
}

@Test("M1 cpu_arch check is informational (no expected value, never fails)")
func systemInfoCpuArchInformational() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let cpuCheck = checks.first { $0.id == "m1.cpu_arch" }
    #expect(cpuCheck != nil)
    #expect(cpuCheck?.expectedValue == nil)
}

@Test("M1 all checks have detection commands")
func systemInfoChecksHaveCommands() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(!check.detectionCommand.isEmpty)
    }
}

@Test("M1 check IDs are unique")
func systemInfoCheckIDsUnique() {
    let module = SystemInfoModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}
