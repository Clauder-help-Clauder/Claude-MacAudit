import Testing
import MacAuditCore

@Test("Core NetworkSecurity Wi-Fi commands resolve service name dynamically instead of hardcoding Wi-Fi")
func coreNetworkSecurityWifiCommandsResolveServiceDynamically() {
    let module = MacAuditCore.NetworkSecurityModule()
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
