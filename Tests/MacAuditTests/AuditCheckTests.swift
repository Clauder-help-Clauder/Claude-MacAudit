import Testing
@testable import MacAudit

// MARK: - AuditCheck Init Tests

@Test("AuditCheck stores id, name, module correctly")
func auditCheckBasicFields() {
    let check = AuditCheck(id: "test.id", name: "Test Name", module: "test_mod", command: "echo hi")
    #expect(check.id == "test.id")
    #expect(check.name == "Test Name")
    #expect(check.module == "test_mod")
}

@Test("AuditCheck defaults: no expected, no fix, no sudo, no networkRisk")
func auditCheckDefaults() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo")
    #expect(check.expectedValue == nil)
    #expect(check.fixCommand == nil)
    #expect(check.fixRiskLevel == nil)
    #expect(check.requiresSudo == false)
    #expect(check.networkRisk == false)
    #expect(check.tags.isEmpty)
    #expect(check.crossRef == nil)
    #expect(check.deviceTypes == nil)
    #expect(check.supportedVersions.isEmpty)
}

@Test("AuditCheck stores expected value")
func auditCheckExpectedValue() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo", expected: "enabled")
    #expect(check.expectedValue == "enabled")
}

@Test("AuditCheck stores risk level")
func auditCheckRiskLevel() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo", risk: .high)
    #expect(check.detectionRiskLevel == .high)
}

@Test("AuditCheck stores fix command and fix risk")
func auditCheckFixFields() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           fixRisk: .high, fixCommand: "sudo fix")
    #expect(check.fixCommand == "sudo fix")
    #expect(check.fixRiskLevel == .high)
}

@Test("AuditCheck stores networkRisk flag")
func auditCheckNetworkRisk() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo", networkRisk: true)
    #expect(check.networkRisk == true)
}

@Test("AuditCheck stores tags")
func auditCheckTags() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           tags: ["group1", "group2"])
    #expect(check.tags.contains("group1"))
    #expect(check.tags.contains("group2"))
}

@Test("AuditCheck stores crossRef")
func auditCheckCrossRef() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo", crossRef: "m2.sip")
    #expect(check.crossRef == "m2.sip")
}

// MARK: - AuditCheck isApplicable Tests

@Test("AuditCheck isApplicable: empty versions matches all")
func auditCheckApplicableAllVersions() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo")
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
    #expect(check.isApplicable(version: .tahoe, device: .desktop, arch: .x86_64))
}

@Test("AuditCheck isApplicable: version-restricted check")
func auditCheckApplicableVersionRestriction() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia])
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
    #expect(!check.isApplicable(version: .tahoe, device: .laptop, arch: .arm64))
}

@Test("AuditCheck isApplicable: device-restricted check")
func auditCheckApplicableDeviceRestriction() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           devices: [.laptop])
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
    #expect(!check.isApplicable(version: .sequoia, device: .desktop, arch: .arm64))
}

// MARK: - isApplicable 四象限组合

@Test("AuditCheck isApplicable: version OK + device NOT OK → false")
func auditCheckApplicableVersionOkDeviceNot() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia], devices: [.laptop])
    #expect(!check.isApplicable(version: .sequoia, device: .desktop, arch: .arm64))
}

@Test("AuditCheck isApplicable: version NOT OK + device OK → false")
func auditCheckApplicableVersionNotDeviceOk() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia], devices: [.laptop])
    #expect(!check.isApplicable(version: .tahoe, device: .laptop, arch: .arm64))
}

@Test("AuditCheck isApplicable: version NOT OK + device NOT OK → false")
func auditCheckApplicableBothNot() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia], devices: [.laptop])
    #expect(!check.isApplicable(version: .tahoe, device: .desktop, arch: .arm64))
}

@Test("AuditCheck isApplicable: version OK + device OK → true")
func auditCheckApplicableBothOk() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia], devices: [.laptop])
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
}

@Test("AuditCheck isApplicable: empty devices Set (not nil) → false for all devices")
func auditCheckApplicableEmptyDeviceSet() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           devices: Set<DeviceType>())
    #expect(!check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
    #expect(!check.isApplicable(version: .sequoia, device: .desktop, arch: .arm64))
}

// MARK: - AuditCheck architecture filtering

@Test("AuditCheck defaults: architectures is nil (all architectures)")
func auditCheckDefaultArchitectures() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo")
    #expect(check.architectures == nil)
}

@Test("AuditCheck isApplicable: arm64-only check passes on arm64")
func auditCheckApplicableArm64OnlyOnArm64() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           architectures: [.arm64])
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
}

@Test("AuditCheck isApplicable: arm64-only check fails on x86_64")
func auditCheckApplicableArm64OnlyOnIntel() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           architectures: [.arm64])
    #expect(!check.isApplicable(version: .sequoia, device: .laptop, arch: .x86_64))
}

@Test("AuditCheck isApplicable: nil architectures matches all")
func auditCheckApplicableNilArchAll() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo")
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .x86_64))
}

@Test("AuditCheck isApplicable: version OK + device OK + arch NOT OK → false")
func auditCheckApplicableVersionDeviceOkArchNot() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia], devices: [.laptop], architectures: [.arm64])
    #expect(!check.isApplicable(version: .sequoia, device: .laptop, arch: .x86_64))
}

@Test("AuditCheck isApplicable: all three dimensions OK → true")
func auditCheckApplicableAllThreeOk() {
    let check = AuditCheck(id: "x", name: "X", module: "m", command: "echo",
                           versions: [.sequoia], devices: [.laptop], architectures: [.arm64])
    #expect(check.isApplicable(version: .sequoia, device: .laptop, arch: .arm64))
}

// MARK: - AuditResult Factory Tests

@Test("AuditResult.pass creates pass status")
func auditResultPass() {
    let check = AuditCheck(id: "t.1", name: "Test", module: "m", command: "echo", expected: "1")
    let result = AuditResult.pass(check: check, actual: "1")
    #expect(result.status == .pass)
    #expect(result.actualValue == "1")
    #expect(result.checkId == "t.1")
}

@Test("AuditResult.fail creates fail status")
func auditResultFail() {
    let check = AuditCheck(id: "t.2", name: "Test", module: "m", command: "echo", expected: "1")
    let result = AuditResult.fail(check: check, actual: "0")
    #expect(result.status == .fail)
    #expect(result.actualValue == "0")
}

@Test("AuditResult.warn creates warn status")
func auditResultWarn() {
    let check = AuditCheck(id: "t.3", name: "Test", module: "m", command: "echo")
    let result = AuditResult.warn(check: check, actual: "unknown")
    #expect(result.status == .warn)
}

@Test("AuditResult.info creates info status")
func auditResultInfo() {
    let check = AuditCheck(id: "t.4", name: "Test", module: "m", command: "echo")
    let result = AuditResult.info(check: check, actual: "some info")
    #expect(result.status == .info)
}

@Test("AuditResult.skip creates skip status with reason")
func auditResultSkip() {
    let check = AuditCheck(id: "t.5", name: "Test", module: "m", command: "echo")
    let result = AuditResult.skip(check: check, reason: "not applicable")
    #expect(result.status == .skip)
    #expect(result.message.contains("not applicable"))
}

@Test("AuditResult.pass sets moduleId from check.module")
func auditResultPassModuleId() {
    let check = AuditCheck(id: "m2.sip", name: "SIP", module: "security", command: "csrutil status", expected: "enabled")
    let result = AuditResult.pass(check: check, actual: "enabled")
    #expect(result.moduleId == "security")
    #expect(result.checkId == "m2.sip")
}

@Test("AuditResult.fail sets moduleId from check.module")
func auditResultFailModuleId() {
    let check = AuditCheck(id: "m13.ip", name: "IP", module: "ip_quality", command: "curl")
    let result = AuditResult.fail(check: check, actual: "bad")
    #expect(result.moduleId == "ip_quality")
}

@Test("AuditResult.info sets moduleId from check.module")
func auditResultInfoModuleId() {
    let check = AuditCheck(id: "m11.node", name: "Node", module: "dev", command: "node -v")
    let result = AuditResult.info(check: check, actual: "v22.0.0")
    #expect(result.moduleId == "dev")
}

@Test("AuditResult.error sets moduleId from check.module")
func auditResultErrorModuleId() {
    let check = AuditCheck(id: "m1.hw", name: "HW", module: "system_info", command: "system_profiler")
    let result = AuditResult.error(check: check, error: "timeout")
    #expect(result.moduleId == "system_info")
}

// MARK: - AuditResult message auto-generation tests

@Test("AuditResult.pass auto-generates message as 'checkName: actual' when no message given")
func auditResultPassAutoMessage() {
    let check = AuditCheck(id: "t.x", name: "SIP Status", module: "m", command: "echo")
    let result = AuditResult.pass(check: check, actual: "enabled")
    #expect(result.message == "SIP Status: enabled")
}

@Test("AuditResult.pass uses provided message when non-empty")
func auditResultPassCustomMessage() {
    let check = AuditCheck(id: "t.x", name: "SIP", module: "m", command: "echo")
    let result = AuditResult.pass(check: check, actual: "enabled", message: "Custom message")
    #expect(result.message == "Custom message")
}

@Test("AuditResult.fail auto-generates message with expectedValue when check has expected")
func auditResultFailAutoMessageWithExpected() {
    let check = AuditCheck(id: "t.x", name: "FileVault", module: "m", command: "echo", expected: "On")
    let result = AuditResult.fail(check: check, actual: "Off")
    #expect(result.message == "FileVault: 期望 On, 实际 Off")
}

@Test("AuditResult.fail auto-generates message with N/A when check has no expectedValue")
func auditResultFailAutoMessageNoExpected() {
    let check = AuditCheck(id: "t.x", name: "Check X", module: "m", command: "echo")
    let result = AuditResult.fail(check: check, actual: "bad")
    #expect(result.message == "Check X: 期望 N/A, 实际 bad")
}

@Test("AuditResult.error stores error string in error field")
func auditResultErrorField() {
    let check = AuditCheck(id: "t.x", name: "Test", module: "m", command: "echo")
    let result = AuditResult.error(check: check, error: "timeout")
    #expect(result.error == "timeout")
}

@Test("AuditResult.skip has nil actualValue")
func auditResultSkipNilActual() {
    let check = AuditCheck(id: "t.x", name: "Test", module: "m", command: "echo")
    let result = AuditResult.skip(check: check, reason: "version mismatch")
    #expect(result.actualValue == nil)
    #expect(result.durationMs == 0)
}

