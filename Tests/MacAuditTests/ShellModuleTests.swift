import Testing
@testable import MacAudit

// MARK: - M9 ShellModule Tests
// 16 checks, all versions/devices


@Test("M9 check IDs are unique")
func shellCheckIDsUnique() {
    let module = ShellModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M9 module id and name are non-empty")
func shellModuleMetadata() {
    let module = ShellModule()
    #expect(module.id == "shell")
    #expect(!module.name.isEmpty)
}

@Test("M9 checks count for sequoia laptop")
func shellChecksCountSequoia() {
    let module = ShellModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count >= 14) // At least 14 shell security checks
}

@Test("M9 all checks have non-empty commands")
func shellChecksHaveCommands() {
    let module = ShellModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(!check.detectionCommand.isEmpty, "Check \(check.id) has empty command")
    }
}

@Test("M9 check IDs follow m9.xxx pattern")
func shellCheckIDPrefix() {
    let module = ShellModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m9."), "Check \(check.id) doesn't have m9. prefix")
    }
}

@Test("M9 dangerous alias check exists")
func shellDangerousAliasCheck() {
    let module = ShellModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let aliasCheck = checks.first { $0.id == "m9.dangerous_alias" }
    #expect(aliasCheck != nil)
}
