import Testing
@testable import MacAudit

// MARK: - NetworkSecurityModule Tests（合并自 M2 SecurityModule + M3 NetworkModule + M8 NetworkTuningModule）

@Test("NetworkSecurity module id and name are non-empty")
func networkSecurityModuleMetadata() {
    let module = NetworkSecurityModule()
    #expect(module.id == "network_security")
    #expect(!module.name.isEmpty)
}

@Test("NetworkSecurity checks count for sequoia laptop")
func networkSecurityChecksCountSequoia() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // 15(M2) + 12(M3) + 17(M8) = 44
    #expect(checks.count == 44)
}

@Test("NetworkSecurity checks count for tahoe desktop")
func networkSecurityChecksCountTahoe() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 44)
}

@Test("NetworkSecurity all check IDs start with m2. m3. or m8.")
func networkSecurityCheckIDPrefix() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        let valid = check.id.hasPrefix("m2.") || check.id.hasPrefix("m3.") || check.id.hasPrefix("m8.")
        #expect(valid, "Unexpected ID prefix: \(check.id)")
    }
}

@Test("NetworkSecurity all checks belong to network_security module")
func networkSecurityCheckModuleField() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "network_security")
    }
}

@Test("NetworkSecurity check IDs are unique")
func networkSecurityCheckIDsUnique() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

// ── M2 原有检测项 ──────────────────────────────────

@Test("M2 sip check expects enabled")
func networkSecuritySIPExpected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let sip = checks.first { $0.id == "m2.sip" }
    #expect(sip != nil)
    #expect(sip?.expectedValue == "enabled")
}

@Test("M2 gatekeeper check expects assessments enabled")
func networkSecurityGatekeeperExpected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let gk = checks.first { $0.id == "m2.gatekeeper" }
    #expect(gk != nil)
    #expect(gk?.expectedValue == "assessments enabled")
}

@Test("M2 firewall check expects enabled and has fixCommand")
func networkSecurityFirewallExpected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let fw = checks.first { $0.id == "m2.firewall" }
    #expect(fw != nil)
    #expect(fw?.expectedValue == "enabled")
    #expect(fw?.fixCommand != nil)
}

@Test("M2 filevault check expects FileVault is On.")
func networkSecurityFilevaultExpected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let fv = checks.first { $0.id == "m2.filevault" }
    #expect(fv != nil)
    #expect(fv?.expectedValue == "FileVault is On.")
}

// ── M3 原有检测项 ──────────────────────────────────

@Test("M3 airplay check expects 0")
func networkSecurityAirplayExpected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ap = checks.first { $0.id == "m3.airplay" }
    #expect(ap != nil)
    #expect(ap?.expectedValue == "0")
}

@Test("M3 smb check expects 0")
func networkSecuritySMBExpected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let smb = checks.first { $0.id == "m3.smb" }
    #expect(smb != nil)
    #expect(smb?.expectedValue == "0")
}

@Test("M3 ipv6 check has networkRisk true")
func networkSecurityIPv6Risk() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ipv6 = checks.first { $0.id == "m3.ipv6" }
    #expect(ipv6 != nil)
    #expect(ipv6?.networkRisk == true)
}

@Test("M3 wifi_ipv6 check expects Off")
func networkSecurityWifiIPv6Expected() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let wv6 = checks.first { $0.id == "m3.wifi_ipv6" }
    #expect(wv6 != nil)
    #expect(wv6?.expectedValue == "Off")
}

@Test("M3 Wi-Fi commands resolve service name dynamically instead of hardcoding Wi-Fi")
func networkSecurityWifiCommandsResolveServiceDynamically() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let wifiIPv6 = checks.first { $0.id == "m3.wifi_ipv6" }
    let wifiProxy = checks.first { $0.id == "m3.wifi_proxy" }
    let globalIPv6 = checks.first { $0.id == "m3.ipv6" }

    #expect(wifiIPv6?.detectionCommand.contains("listnetworkserviceorder") == true)
    #expect(wifiProxy?.detectionCommand.contains("listnetworkserviceorder") == true)
    #expect(globalIPv6?.fixCommand?.contains("listnetworkserviceorder") == true)
    #expect(wifiIPv6?.fixCommand?.contains("listnetworkserviceorder") == true)
    #expect(wifiIPv6?.detectionCommand.contains("'Wi-Fi'") == false)
    #expect(wifiProxy?.detectionCommand.contains("'Wi-Fi'") == false)
    #expect(globalIPv6?.fixCommand?.contains("'Wi-Fi'") == false)
    #expect(wifiIPv6?.fixCommand?.contains("'Wi-Fi'") == false)
}

// ── M8 原有检测项 ──────────────────────────────────

@Test("M8 TCP sendspace check expects 1048576")
func networkSecurityTCPSendspace() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let sc = checks.first { $0.id == "m8.net_inet_tcp_sendspace" }
    #expect(sc != nil)
    #expect(sc?.expectedValue == "1048576")
}

@Test("M8 TCP blackhole check has medium risk")
func networkSecurityTCPBlackhole() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let bh = checks.first { $0.id == "m8.net_inet_tcp_blackhole" }
    #expect(bh != nil)
    #expect(bh?.detectionRiskLevel == .medium)
}

@Test("M8 IPv6 rtadv check has networkRisk true")
func networkSecurityIPv6Rtadv() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let rtadv = checks.first { $0.id == "m8.net_inet6_ip6_accept_rtadv" }
    #expect(rtadv != nil)
    #expect(rtadv?.networkRisk == true)
}

@Test("M8 accept_rtadv check uses networksetup instead of sysctl -w")
func networkSecurityAcceptRtadvFixCommand() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let rtadv = checks.first { $0.id == "m8.net_inet6_ip6_accept_rtadv" }
    #expect(rtadv != nil)
    #expect(rtadv?.fixCommand?.contains("sysctl -w") == false,
            "accept_rtadv is read-only sysctl, fixCommand must not use sysctl -w")
    #expect(rtadv?.fixCommand?.contains("networksetup") == true,
            "accept_rtadv fixCommand should use networksetup to disable IPv6")
}

@Test("M8 ip6_forwarding check uses networksetup instead of sysctl -w")
func networkSecurityIPv6ForwardingFixCommand() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let fwd = checks.first { $0.id == "m8.net_inet6_ip6_forwarding" }
    #expect(fwd != nil)
    #expect(fwd?.fixCommand?.contains("sysctl -w") == false,
            "ip6.forwarding is read-only sysctl, fixCommand must not use sysctl -w")
    #expect(fwd?.fixCommand?.contains("networksetup") == true,
            "ip6.forwarding fixCommand should use networksetup to disable IPv6")
}

@Test("M8 accept_rtadv description mentions read-only limitation")
func networkSecurityAcceptRtadvDescriptionMentionsReadOnly() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let rtadv = checks.first { $0.id == "m8.net_inet6_ip6_accept_rtadv" }
    #expect(rtadv != nil)
    let desc = rtadv?.description ?? ""
    #expect(desc.contains("只读") || desc.contains("read-only") || desc.contains("无法"),
            "Description should mention the read-only limitation")
}

@Test("M8 persistence plist check is present")
func networkSecuritySysctlPlist() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let plist = checks.first { $0.id == "m8.sysctl_plist" }
    #expect(plist != nil)
}

// MARK: - Architecture-dependent maxsockbuf

@Test("M8 maxsockbuf expects 6291456 on arm64")
func networkSecurityMaxsockbufArm64() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let msb = checks.first { $0.id == "m8.kern_ipc_maxsockbuf" }
    #expect(msb != nil)
    #expect(msb?.expectedValue == "6291456")
}

@Test("M8 maxsockbuf expects 16777216 on x86_64")
func networkSecurityMaxsockbufIntel() {
    let module = NetworkSecurityModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .x86_64)
    let msb = checks.first { $0.id == "m8.kern_ipc_maxsockbuf" }
    #expect(msb != nil)
    #expect(msb?.expectedValue == "16777216")
}
