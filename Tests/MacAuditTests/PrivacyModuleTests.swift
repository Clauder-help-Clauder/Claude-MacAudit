import Testing
@testable import MacAudit

// MARK: - M4 PrivacyModule Tests

@Test("M4 module id and name are non-empty")
func privacyModuleMetadata() {
    let module = PrivacyModule()
    #expect(module.id == "privacy")
    #expect(!module.name.isEmpty)
}

@Test("M4 checks count is 17 for sequoia laptop")
func privacyChecksCountSequoia() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 17)
}

@Test("M4 checks count is 17 for tahoe desktop")
func privacyChecksCountTahoe() {
    let module = PrivacyModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 17)
}

@Test("M4 all check IDs start with m4.")
func privacyCheckIDPrefix() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m4."))
    }
}

@Test("M4 all checks belong to privacy module")
func privacyCheckModuleField() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "privacy")
    }
}

@Test("M4 diagnostics check expects 0")
func privacyDiagnosticsExpected() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let diag = checks.first { $0.id == "m4.diagnostics" }
    #expect(diag != nil)
    #expect(diag?.expectedValue == "0")
}

@Test("M4 ad_tracking check expects 0")
func privacyAdTrackingExpected() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ad = checks.first { $0.id == "m4.ad_tracking" }
    #expect(ad != nil)
    #expect(ad?.expectedValue == "0")
}

@Test("M4 mdns check has networkRisk true")
func privacyMdnsNetworkRisk() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let mdns = checks.first { $0.id == "m4.mdns" }
    #expect(mdns != nil)
    #expect(mdns?.networkRisk == true)
}

@Test("M4 airdrop check expects 1")
func privacyAirDropExpected() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let airdrop = checks.first { $0.id == "m4.airdrop" }
    #expect(airdrop != nil)
    #expect(airdrop?.expectedValue == "1")
}

@Test("M4 all checks have fix commands (including mdns/captive with sudo defaults write)")
func privacyChecksHaveFixCommands() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.fixCommand != nil, "Check \(check.id) should have fixCommand")
    }
    // mdns and captive now have fixCommands via sudo defaults write (even on macOS 15+)
    let mdns = checks.first { $0.id == "m4.mdns" }
    let captive = checks.first { $0.id == "m4.captive" }
    #expect(mdns?.fixCommand != nil)
    #expect(captive?.fixCommand != nil)
    #expect(mdns?.fixCommand?.contains("mDNSResponder") == true)
    #expect(captive?.fixCommand?.contains("captive") == true)
}

@Test("M4 check IDs are unique")
func privacyCheckIDsUnique() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

// MARK: - needsSudo fixCommand branch tests

@Test("M4 mdns/captive fixCommands use sudo defaults write (macOS 15+ compatible)")
func privacyNeedsSudoChecks() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // macOS 15+: plist path changed but sudo defaults write still creates it
    let mdns = checks.first { $0.id == "m4.mdns" }
    #expect(mdns?.fixCommand?.hasPrefix("sudo defaults write") == true)
    let captive = checks.first { $0.id == "m4.captive" }
    #expect(captive?.fixCommand?.hasPrefix("sudo defaults write") == true)
}

@Test("M4 checks with user defaults domain do NOT have sudo prefix in fixCommand")
func privacyNoSudoChecks() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let diag = checks.first { $0.id == "m4.diagnostics" }
    #expect(diag?.fixCommand?.hasPrefix("sudo ") == false)
    let ad = checks.first { $0.id == "m4.ad_tracking" }
    #expect(ad?.fixCommand?.hasPrefix("sudo ") == false)
}

@Test("M4 mdns has medium fixRisk, captive has high fixRisk")
func privacyFixRiskMatchesSudo() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let mdns = checks.first { $0.id == "m4.mdns" }
    #expect(mdns?.fixRiskLevel == .medium)
    let captive = checks.first { $0.id == "m4.captive" }
    #expect(captive?.fixRiskLevel == .high)
    let diag = checks.first { $0.id == "m4.diagnostics" }
    #expect(diag?.fixRiskLevel == .low)
}

@Test("M4 captive check also has networkRisk true")
func privacyCaptiveNetworkRisk() {
    let module = PrivacyModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let captive = checks.first { $0.id == "m4.captive" }
    #expect(captive?.networkRisk == true)
}
