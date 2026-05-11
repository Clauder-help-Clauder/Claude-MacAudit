import Testing
@testable import MacAudit

struct ModulePriorityConsistencyTests {

    @Test("IPQualityModule: all checks are A0")
    func ipQualityPriorities() {
        let module = IPQualityModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        for check in checks {
            #expect(check.priority == CheckPriority.a0, "\(check.id) should be A0, got \(check.priority)")
        }
    }

    @Test("SystemInfoModule: all checks are A0")
    func systemInfoPriorities() {
        let module = SystemInfoModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        for check in checks {
            #expect(check.priority == CheckPriority.a0, "\(check.id) should be A0, got \(check.priority)")
        }
    }

    @Test("ChromeModule: all checks are A0")
    func chromePriorities() {
        let module = ChromeModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        for check in checks {
            #expect(check.priority == CheckPriority.a0, "\(check.id) should be A0, got \(check.priority)")
        }
    }

    @Test("SafariModule: all checks are A0")
    func safariPriorities() {
        let module = SafariModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        for check in checks {
            #expect(check.priority == CheckPriority.a0, "\(check.id) should be A0, got \(check.priority)")
        }
    }

    @Test("PrivacyModule: all checks are A0")
    func privacyModulePriorities() {
        let module = PrivacyModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        for check in checks {
            #expect(check.priority == CheckPriority.a0, "\(check.id) should be A0, got \(check.priority)")
        }
    }

    @Test("NetworkSecurityModule: DNS leak checks are A0")
    func networkSecurityDNSLeakPriorities() {
        let module = NetworkSecurityModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        let dnsLeakIds: Set<String> = ["m3.dns", "m3.surge_dns", "m3.ipv6", "m3.wifi_ipv6", "m3.wifi_proxy", "m3.surge_dashboard"]
        for check in checks where dnsLeakIds.contains(check.id) || check.id.contains("inet6") {
            #expect(check.priority == CheckPriority.a0, "\(check.id) should be A0, got \(check.priority)")
        }
    }

    @Test("ServicesModule: A0 filter returns 0 checks (all are A1+)")
    func servicesA0FilterIsEmpty() {
        let module = ServicesModule()
        let a0Only = module.checks(for: .sequoia, device: .laptop, arch: .arm64, maxPriority: .a0)
        #expect(a0Only.isEmpty)
    }

    @Test("PowerModule: all checks are A2 (optimization)")
    func powerModulePriorities() {
        let module = PowerModule()
        let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
        for check in checks {
            #expect(check.priority == CheckPriority.a2, "\(check.id) should be A2, got \(check.priority)")
        }
    }

    @Test("Essential mode includes at least 100 checks across 7 modules")
    func essentialModeCheckCount() {
        let modules: [any AuditModule] = [
            SystemInfoModule(), NetworkSecurityModule(), PrivacyModule(),
            ChromeModule(), SafariModule(), ClaudeProtectionModule(),
            IPQualityModule(),
        ]
        var total = 0
        for m in modules {
            total += m.checks(for: .sequoia, device: .laptop, arch: .arm64, maxPriority: .a0).count
        }
        #expect(total >= 100, "Essential mode should have 100+ A0 checks, got \(total)")
    }
}
