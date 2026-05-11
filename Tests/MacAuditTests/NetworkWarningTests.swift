import Testing
@testable import MacAudit

// MARK: - isNetworkRisk detection

@Test("NetworkWarning detects mDNSResponder as network risk")
func networkWarningMDNSResponder() {
    #expect(NetworkWarning.isNetworkRisk("killall -HUP mDNSResponder"))
}

@Test("NetworkWarning detects networksetup as network risk")
func networkWarningNetworksetup() {
    #expect(NetworkWarning.isNetworkRisk("sudo networksetup -setv6off Wi-Fi"))
}

@Test("NetworkWarning detects ifconfig as network risk")
func networkWarningIfconfig() {
    #expect(NetworkWarning.isNetworkRisk("ifconfig en0 down"))
}

@Test("NetworkWarning detects pfctl as network risk")
func networkWarningPfctl() {
    #expect(NetworkWarning.isNetworkRisk("sudo pfctl -e -f /etc/pf.conf"))
}

@Test("NetworkWarning detects socketfilterfw as network risk")
func networkWarningSocketfilterfw() {
    #expect(NetworkWarning.isNetworkRisk("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"))
}

@Test("NetworkWarning detects scutil as network risk")
func networkWarningScutil() {
    #expect(NetworkWarning.isNetworkRisk("scutil --set ComputerName NewName"))
}

@Test("NetworkWarning detects dscacheutil flushcache as network risk")
func networkWarningDscacheutil() {
    #expect(NetworkWarning.isNetworkRisk("dscacheutil -flushcache"))
}

@Test("NetworkWarning detects dns keyword as network risk")
func networkWarningDns() {
    #expect(NetworkWarning.isNetworkRisk("sudo launchctl unload /System/Library/LaunchDaemons/com.apple.dns.plist"))
}

@Test("NetworkWarning returns false for safe non-network command")
func networkWarningSafeCommand() {
    #expect(!NetworkWarning.isNetworkRisk("defaults write com.apple.dock autohide -bool true"))
}

@Test("NetworkWarning returns false for echo command")
func networkWarningEcho() {
    #expect(!NetworkWarning.isNetworkRisk("echo hello"))
}

@Test("NetworkWarning returns false for launchctl non-network command")
func networkWarningLaunchctl() {
    #expect(!NetworkWarning.isNetworkRisk("launchctl disable gui/501/com.apple.gamed"))
}

@Test("NetworkWarning is case-insensitive for risk detection")
func networkWarningCaseInsensitive() {
    #expect(NetworkWarning.isNetworkRisk("SUDO NETWORKSETUP -SETV6OFF WI-FI"))
}

@Test("NetworkWarning detects setv6off keyword")
func networkWarningSetv6off() {
    #expect(NetworkWarning.isNetworkRisk("sudo networksetup -setv6off \"Wi-Fi\""))
}

@Test("NetworkWarning detects route command as network risk")
func networkWarningRoute() {
    #expect(NetworkWarning.isNetworkRisk("sudo route flush"))
}

@Test("NetworkWarning detects flush keyword")
func networkWarningFlush() {
    #expect(NetworkWarning.isNetworkRisk("sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"))
}

@Test("NetworkWarning returns false for empty command")
func networkWarningEmpty() {
    #expect(!NetworkWarning.isNetworkRisk(""))
}

// MARK: - suggestRecovery tests

@Test("suggestRecovery for setv6off returns networksetup recovery command")
func suggestRecoverySetv6off() {
    let cmds = NetworkWarning.suggestRecovery(for: "sudo networksetup -setv6off Wi-Fi")
    #expect(cmds.contains { $0.contains("setv6automatic") })
}

@Test("suggestRecovery for mDNSResponder returns DNS cache comment")
func suggestRecoveryMDNS() {
    let cmds = NetworkWarning.suggestRecovery(for: "killall -HUP mDNSResponder")
    #expect(cmds.contains { $0.contains("DNS") })
}

@Test("suggestRecovery for flushcache returns cache comment")
func suggestRecoveryFlushcache() {
    let cmds = NetworkWarning.suggestRecovery(for: "dscacheutil -flushcache")
    #expect(cmds.contains { $0.contains("DNS") })
}

@Test("suggestRecovery for socketfilterfw returns firewall off command")
func suggestRecoverySocketfilterfw() {
    let cmds = NetworkWarning.suggestRecovery(for: "sudo socketfilterfw --setglobalstate on")
    #expect(cmds.contains { $0.contains("socketfilterfw") && $0.contains("off") })
}

@Test("suggestRecovery for pfctl returns pfctl -d command")
func suggestRecoveryPfctl() {
    let cmds = NetworkWarning.suggestRecovery(for: "sudo pfctl -e -f /etc/pf.conf")
    #expect(cmds.contains { $0.contains("pfctl -d") })
}

@Test("suggestRecovery for networksetup proxy returns proxy off command")
func suggestRecoveryNetworksetupProxy() {
    let cmds = NetworkWarning.suggestRecovery(for: "sudo networksetup -setwebproxy Wi-Fi proxy.example.com 8080")
    #expect(cmds.contains { $0.contains("proxystate") && $0.contains("off") })
}

@Test("suggestRecovery for unknown command returns default fallback")
func suggestRecoveryDefault() {
    let cmds = NetworkWarning.suggestRecovery(for: "some_unknown_network_cmd")
    #expect(!cmds.isEmpty)
    // Default fallback contains restart hint
    #expect(cmds.contains { $0.contains("重启") || $0.contains("restart") || $0.contains("#") })
}
