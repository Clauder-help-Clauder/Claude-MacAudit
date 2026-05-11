import Testing
@testable import MacAudit

// MARK: - RiskLevel Tests

@Test("RiskLevel raw values are ordered correctly")
func riskLevelOrdering() {
    #expect(RiskLevel.safe.rawValue == 0)
    #expect(RiskLevel.low.rawValue == 1)
    #expect(RiskLevel.medium.rawValue == 2)
    #expect(RiskLevel.high.rawValue == 3)
    #expect(RiskLevel.critical.rawValue == 4)
}

@Test("RiskLevel Comparable works")
func riskLevelComparable() {
    #expect(RiskLevel.safe < RiskLevel.low)
    #expect(RiskLevel.low < RiskLevel.medium)
    #expect(RiskLevel.medium < RiskLevel.high)
    #expect(RiskLevel.high < RiskLevel.critical)
    #expect(!(RiskLevel.critical < RiskLevel.high))
}

@Test("RiskLevel allCases has 5 elements")
func riskLevelAllCases() {
    #expect(RiskLevel.allCases.count == 5)
}

@Test("RiskLevel labels are non-empty")
func riskLevelLabels() {
    for level in RiskLevel.allCases {
        #expect(!level.label.isEmpty)
    }
}

@Test("RiskLevel labels have correct specific values")
func riskLevelLabelValues() {
    #expect(RiskLevel.safe.label == "SAFE")
    #expect(RiskLevel.low.label == "LOW")
    #expect(RiskLevel.medium.label == "MEDIUM")
    #expect(RiskLevel.high.label == "HIGH")
    #expect(RiskLevel.critical.label == "CRITICAL")
}

// MARK: - AuditStatus Tests

@Test("AuditStatus all cases exist")
func auditStatusAllCases() {
    let statuses: [AuditStatus] = [.pass, .warn, .fail, .info, .skip, .error]
    #expect(statuses.count == 6)
}

@Test("AuditStatus symbols are non-empty")
func auditStatusSymbols() {
    let statuses: [AuditStatus] = [.pass, .warn, .fail, .info, .skip, .error]
    for status in statuses {
        #expect(!status.symbol.isEmpty)
    }
}

@Test("AuditStatus symbols have correct specific values")
func auditStatusSymbolValues() {
    #expect(AuditStatus.pass.symbol == "✓")
    #expect(AuditStatus.warn.symbol == "!")
    #expect(AuditStatus.fail.symbol == "✗")
    #expect(AuditStatus.info.symbol == "i")
    #expect(AuditStatus.skip.symbol == "⊘")
    #expect(AuditStatus.error.symbol == "?")
}

@Test("AuditStatus rawValues match string names")
func auditStatusRawValues() {
    #expect(AuditStatus.pass.rawValue == "pass")
    #expect(AuditStatus.fail.rawValue == "fail")
    #expect(AuditStatus.warn.rawValue == "warn")
    #expect(AuditStatus.info.rawValue == "info")
    #expect(AuditStatus.skip.rawValue == "skip")
    #expect(AuditStatus.error.rawValue == "error")
}

// MARK: - MacOSVersion Tests

@Test("MacOSVersion allCases has 2 elements")
func macOSVersionAllCases() {
    #expect(MacOSVersion.allCases.count == 2)
}

@Test("MacOSVersion versionString is non-empty")
func macOSVersionString() {
    #expect(!MacOSVersion.versionString.isEmpty)
    #expect(MacOSVersion.versionString.contains("."))
}

@Test("MacOSVersion displayNames are non-empty")
func macOSVersionDisplayNames() {
    for version in MacOSVersion.allCases {
        #expect(!version.displayName.isEmpty)
    }
}

@Test("MacOSVersion majorVersions are correct")
func macOSVersionMajorVersions() {
    #expect(MacOSVersion.sequoia.majorVersion == 15)
    #expect(MacOSVersion.tahoe.majorVersion == 26)
}

// MARK: - DeviceType Tests

@Test("DeviceType detect returns valid value")
func deviceTypeDetect() {
    let device = DeviceType.detect()
    #expect(device == .laptop || device == .desktop)
}

@Test("DeviceType displayNames are non-empty")
func deviceTypeDisplayNames() {
    #expect(!DeviceType.laptop.displayName.isEmpty)
    #expect(!DeviceType.desktop.displayName.isEmpty)
}

@Test("DeviceType rawValues match string names")
func deviceTypeRawValues() {
    #expect(DeviceType.laptop.rawValue == "laptop")
    #expect(DeviceType.desktop.rawValue == "desktop")
}

// MARK: - CPUArchitecture Tests

@Test("CPUArchitecture has arm64 and x86_64 cases")
func cpuArchitectureCases() {
    #expect(CPUArchitecture.arm64.rawValue == "arm64")
    #expect(CPUArchitecture.x86_64.rawValue == "x86_64")
}

@Test("CPUArchitecture displayName")
func cpuArchitectureDisplayName() {
    #expect(CPUArchitecture.arm64.displayName == "Apple Silicon")
    #expect(CPUArchitecture.x86_64.displayName == "Intel")
}

@Test("CPUArchitecture detect returns valid value on current machine")
func cpuArchitectureDetect() {
    let arch = CPUArchitecture.detect()
    #expect(arch == .arm64 || arch == .x86_64)
}

@Test("CPUArchitecture isAppleSilicon computed property")
func cpuArchitectureIsAppleSilicon() {
    #expect(CPUArchitecture.arm64.isAppleSilicon == true)
    #expect(CPUArchitecture.x86_64.isAppleSilicon == false)
}
