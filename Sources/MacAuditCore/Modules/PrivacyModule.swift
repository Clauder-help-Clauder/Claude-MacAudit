import Foundation

/// M4: 隐私与遥测模块
public struct PrivacyModule: AuditModule {
    public init() {}

    public let id = "privacy"
    public let name = "隐私与遥测"
    public let description = "隐私配置和遥测数据检测"

    private struct PrivacyDef {
        let id: String
        let name: String
        let readDomain: String
        let readKey: String
        let expected: String
        let writeType: String  // "-bool true", "-int 0" etc.

        init(_ id: String, _ name: String, _ domain: String, _ key: String, _ expected: String, _ writeType: String) {
            self.id = id; self.name = name; self.readDomain = domain
            self.readKey = key; self.expected = expected; self.writeType = writeType
        }
    }

    private let defs: [PrivacyDef] = [
        PrivacyDef("m4.diagnostics", "诊断数据提交", "com.apple.SubmitDiagInfo", "AutoSubmit", "0", "0"),
        PrivacyDef("m4.crash_reporter", "崩溃报告弹窗", "com.apple.CrashReporter", "DialogType", "none", "-string none"),
        PrivacyDef("m4.siri_enabled", "Siri 主开关", "com.apple.assistant.support", "'Assistant Enabled'", "0", "0"),
        PrivacyDef("m4.siri_sharing", "Siri 数据共享", "com.apple.assistant.support", "'Siri Data Sharing Opt-In Status'", "0", "-int 0"),
        PrivacyDef("m4.siri_menu", "Siri 菜单栏", "com.apple.Siri", "StatusMenuVisible", "0", "0"),
        PrivacyDef("m4.ad_tracking", "个性化广告", "com.apple.AdLib", "allowApplePersonalizedAdvertising", "0", "0"),
        PrivacyDef("m4.usage_tracking", "iCloud 使用追踪", "com.apple.UsageTracking", "CoreDonationsEnabled", "0", "0"),
        PrivacyDef("m4.udc_automation", "iCloud UDC 自动化", "com.apple.UsageTracking", "UDCAutomationEnabled", "0", "0"),
        PrivacyDef("m4.mdns", "mDNS 多播广告", "/Library/Preferences/com.apple.mDNSResponder.plist", "NoMulticastAdvertisements", "1", "1"),
        PrivacyDef("m4.captive", "Captive Portal 检测", "/Library/Preferences/SystemConfiguration/CaptiveNetworkSupport", "Active", "0", "0"),
        PrivacyDef("m4.ds_network", "网络卷 .DS_Store", "com.apple.desktopservices", "DSDontWriteNetworkStores", "1", "1"),
        PrivacyDef("m4.ds_usb", "USB 卷 .DS_Store", "com.apple.desktopservices", "DSDontWriteUSBStores", "1", "1"),
        PrivacyDef("m4.airdrop", "AirDrop 状态", "com.apple.NetworkBrowser", "DisableAirDrop", "1", "1"),
        PrivacyDef("m4.photo_analysis", "照片面部识别", "com.apple.photoanalysisd", "enabled", "0", "0"),
        PrivacyDef("m4.safari_search", "Safari 网络搜索", "com.apple.Safari", "UniversalSearchEnabled", "0", "0"),
        PrivacyDef("m4.safari_suggest", "Safari 搜索建议", "com.apple.Safari", "SuppressSearchSuggestions", "1", "1"),
        PrivacyDef("m4.spotlight_suggest", "Spotlight 建议", "com.apple.lookup.shared", "LookupSuggestionsDisabled", "1", "1"),
    ]

    public func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        defs.map { d in
            // macOS 15 Sequoia+: mDNSResponder.plist 和 CaptiveNetworkSupport plist 已移除
            // 这两条使用 launchctl/scutil 替代检测（仅信息展示，无自动修复）
            if (d.id == "m4.mdns" || d.id == "m4.captive") {
                let altCmd: String
                let altExpected: String?
                let altFixCmd: String?
                let altFixRisk: RiskLevel?
                if d.id == "m4.mdns" {
                    altCmd = "defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements 2>/dev/null || echo '0'"
                    altExpected = "1"
                    altFixCmd = "sudo defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements 1 && sudo launchctl stop com.apple.mDNSResponder && sudo launchctl start com.apple.mDNSResponder"
                    altFixRisk = .medium
                } else {
                    altCmd = "defaults read /Library/Preferences/SystemConfiguration/com.apple.captive.control Active 2>/dev/null || echo 'not set'"
                    altExpected = nil
                    altFixCmd = "sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active 0"
                    altFixRisk = .high
                }
                let pri: CheckPriority = .a0
                return AuditCheck(
                    id: d.id, name: d.name, module: id,
                    command: altCmd, expected: altExpected,
                    risk: .safe,
                    fixRisk: altFixRisk, fixCommand: altFixCmd,
                    networkRisk: true,
                    priority: pri
                )
            }

            let readCmd = "defaults read \(d.readDomain) \(d.readKey) 2>/dev/null || echo 'not set'"
            let writeCmd = "defaults write \(d.readDomain) \(d.readKey) \(d.writeType)"
            let needsSudo = d.readDomain.hasPrefix("/Library")
            let isTelemetry = d.id.contains("diagnostics") || d.id.contains("crash_reporter") || d.id.contains("ad_tracking") || d.id.contains("usage_tracking") || d.id.contains("udc_automation") || d.id.contains("safari_search") || d.id.contains("safari_suggest") || d.id.contains("spotlight_suggest")
            let pri: CheckPriority = .a0
            return AuditCheck(
                id: d.id, name: d.name, module: id,
                command: readCmd, expected: d.expected,
                risk: .safe,
                fixRisk: needsSudo ? .high : .low,
                fixCommand: needsSudo ? "sudo \(writeCmd)" : writeCmd,
                networkRisk: d.id == "m4.mdns" || d.id == "m4.captive",
                priority: pri
            )
        }
    }

    public func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
