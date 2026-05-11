import Testing
@testable import MacAudit

// MARK: - M13 IPQualityModule Tests

@Test("M13 module id is ip_quality")
func ipQualityModuleID() {
    let module = IPQualityModule()
    #expect(module.id == "ip_quality")
}

@Test("M13 module name is non-empty")
func ipQualityModuleName() {
    let module = IPQualityModule()
    #expect(!module.name.isEmpty)
}

@Test("M13 module description is non-empty")
func ipQualityModuleDescription() {
    let module = IPQualityModule()
    #expect(!module.description.isEmpty)
}

@Test("M13 total checks count is 23 for sequoia laptop")
func ipQualityChecksCountSequoiaLaptop() {
    let module = IPQualityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 23)
}

@Test("M13 total checks count is 23 for tahoe desktop")
func ipQualityChecksCountTahoeDesktop() {
    let module = IPQualityModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 23)
}

@Test("M13 phaseA returns 9 checks")
func ipQualityPhaseACount() {
    let module = IPQualityModule()
    #expect(module.phaseAChecks().count == 9)
}

@Test("M13 phaseB returns 11 checks")
func ipQualityPhaseBCount() {
    let module = IPQualityModule()
    #expect(module.phaseBChecks().count == 11)
}

@Test("M13 phaseC returns 1 check")
func ipQualityPhaseCCount() {
    let module = IPQualityModule()
    #expect(module.phaseCChecks().count == 1)
}

@Test("M13 phaseD returns 2 checks")
func ipQualityPhaseDCount() {
    let module = IPQualityModule()
    #expect(module.phaseDChecks().count == 2)
}

@Test("M13 all check IDs start with m13.")
func ipQualityCheckIDPrefix() {
    let module = IPQualityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m13."))
    }
}

@Test("M13 all checks have module ip_quality")
func ipQualityCheckModuleField() {
    let module = IPQualityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "ip_quality")
    }
}

@Test("M13 check IDs are unique")
func ipQualityCheckIDsUnique() {
    let module = IPQualityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M13 specific check IDs exist: public_ipv4, dnsbl_summary, smtp_port25")
func ipQualitySpecificCheckIDs() {
    let module = IPQualityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = Set(checks.map(\.id))
    #expect(ids.contains("m13.public_ipv4"))
    #expect(ids.contains("m13.dnsbl_summary"))
    #expect(ids.contains("m13.smtp_port25"))
    #expect(ids.contains("m13.smtp_port587"))
    #expect(ids.contains("m13.is_proxy"))
    #expect(ids.contains("m13.is_vpn"))
    #expect(ids.contains("m13.is_tor"))
    #expect(ids.contains("m13.is_datacenter"))
}

@Test("M13 phaseA checks have ip, network, or dns tags")
func ipQualityPhaseAHasNetworkOrIPTags() {
    let module = IPQualityModule()
    let allowed: Set<String> = ["ip", "network", "dns", "proxy"]
    for check in module.phaseAChecks() {
        let hasValidTag = !check.tags.isDisjoint(with: allowed)
        #expect(hasValidTag, "Check \(check.id) has no ip/network/dns/proxy tag")
    }
}

@Test("M13 phaseC check has dnsbl tag")
func ipQualityPhaseCHasDnsblTag() {
    let module = IPQualityModule()
    let check = module.phaseCChecks()[0]
    #expect(check.tags.contains("dnsbl"))
}

@Test("M13 phaseD checks have mail tag")
func ipQualityPhaseDHasMailTag() {
    let module = IPQualityModule()
    for check in module.phaseDChecks() {
        #expect(check.tags.contains("mail"), "Check \(check.id) missing mail tag")
    }
}

@Test("M13 phaseA check IDs are in expected order")
func ipQualityPhaseACheckIDs() {
    let module = IPQualityModule()
    let ids = module.phaseAChecks().map(\.id)
    let expected = [
        "m13.public_ipv4", "m13.public_ipv6", "m13.local_interfaces",
        "m13.dns_servers", "m13.proxy_config", "m13.default_gateway",
        "m13.reverse_dns", "m13.whois_org", "m13.whois_country"
    ]
    #expect(ids == expected)
}

@Test("M13 phaseD check IDs are smtp_port25 and smtp_port587")
func ipQualityPhaseDCheckIDs() {
    let module = IPQualityModule()
    let ids = module.phaseDChecks().map(\.id)
    #expect(ids == ["m13.smtp_port25", "m13.smtp_port587"])
}
