import Testing
@testable import MacAudit

// MARK: - M11 DevEnvironmentModule Tests
// Total tools: 7+12+2(seq)+1(tahoe)+1+8+12+8+4+1+1+4+2+5 = 68
// Sequoia: 68 - 1(tahoe-only) = 67
// Tahoe: 68 - 2(sequoia-only) = 66

@Test("M11 module id and name are non-empty")
func devEnvironmentModuleMetadata() {
    let module = DevEnvironmentModule()
    #expect(module.id == "dev")
    #expect(!module.name.isEmpty)
}

@Test("M11 checks count is 67 for sequoia")
func devEnvironmentChecksCountSequoia() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 67)
}

@Test("M11 checks count is 66 for tahoe")
func devEnvironmentChecksCountTahoe() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 66)
}

@Test("M11 all check IDs start with m11.")
func devEnvironmentCheckIDPrefix() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m11."))
    }
}

@Test("M11 all checks belong to dev module")
func devEnvironmentCheckModuleField() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "dev")
    }
}

@Test("M11 sequoia has pyenv_deps and orbstack_seq checks")
func devEnvironmentSequoiaSpecificChecks() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(ids.contains("m11.pyenv_deps"))
    #expect(ids.contains("m11.orbstack_seq"))
}

@Test("M11 tahoe has mlx check, not sequoia-only checks")
func devEnvironmentTahoeSpecificChecks() {
    let module = DevEnvironmentModule()
    let tahoeChecks = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    let tahoeIds = tahoeChecks.map(\.id)
    #expect(tahoeIds.contains("m11.mlx"))
    #expect(!tahoeIds.contains("m11.pyenv_deps"))
    #expect(!tahoeIds.contains("m11.orbstack_seq"))
}

@Test("M11 ulimit_n check expects 65536")
func devEnvironmentUlimitNExpected() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ul = checks.first { $0.id == "m11.ulimit_n" }
    #expect(ul != nil)
    #expect(ul?.expectedValue == "65536")
}

@Test("M11 check IDs are unique")
func devEnvironmentCheckIDsUnique() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M11 contains brew, git, node checks")
func devEnvironmentCoreToolsPresent() {
    let module = DevEnvironmentModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(ids.contains("m11.brew"))
    #expect(ids.contains("m11.git"))
    #expect(ids.contains("m11.node"))
}
