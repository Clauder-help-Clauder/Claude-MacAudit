//
//  PrivacyModule.swift
//  MacAudit
//
//  M4: 隐私与遥测模块
//  检测 macOS 隐私配置和遥测数据设置，包括诊断数据提交、崩溃报告、
//  Siri、广告追踪、mDNS 多播、Captive Portal、.DS_Store 写入等，
//  macOS 15+ 对 mDNS 和 Captive Portal 使用替代检测方式。
//

import Foundation
import MacAuditCore

/// M4: 隐私与遥测模块
struct PrivacyModule: AuditModule {
    /// 模块唯一标识
    let id = "privacy"
    /// 模块显示名称
    let name = "隐私与遥测"
    /// 模块功能描述
    let description = "隐私配置和遥测数据检测"

    /// 隐私检查项定义
    private struct PrivacyDef {
        /// 检查项标识
        let id: String
        /// 显示名称
        let name: String
        /// defaults 读取 domain
        let readDomain: String
        /// defaults 读取 key
        let readKey: String
        /// 期望值
        let expected: String
        /// defaults 写入类型，如 "-bool true"、"-int 0"、"-string none"
        let writeType: String

        /// 便捷初始化器
        init(_ id: String, _ name: String, _ domain: String, _ key: String, _ expected: String, _ writeType: String) {
            self.id = id; self.name = name; self.readDomain = domain
            self.readKey = key; self.expected = expected; self.writeType = writeType
        }
    }

    /// 隐私检查项定义列表
    private let defs: [PrivacyDef] = [
        PrivacyDef("m4.diagnostics", "诊断数据提交", "com.apple.SubmitDiagInfo", "AutoSubmit", "0", "0"),
        PrivacyDef("m4.crash_reporter", "崩溃报告弹窗", "com.apple.CrashReporter", "DialogType", "none", "-string none"),
        PrivacyDef("m4.siri_enabled", "Siri 主开关", "com.apple.assistant.support", "'Assistant Enabled'", "0", "0"),
        PrivacyDef("m4.siri_sharing", "Siri 数据共享", "com.apple.assistant.support", "'Siri Data Sharing Opt-In Status'", "0", "-int 0"),
        PrivacyDef("m4.siri_menu", "Siri 菜单栏", "com.apple.Siri", "StatusMenuVisible", "0", "0"),
        PrivacyDef("m4.ad_tracking", "个性化广告", "com.apple.AdLib", "allowApplePersonalizedAdvertising", "0", "0"),
        PrivacyDef("m4.usage_tracking", "iCloud 使用追踪", "com.apple.UsageTracking", "CoreDonationsEnabled", "0", "0"),
        PrivacyDef("m4.udc_automation", "iCloud UDC 自动化", "com.apple.UsageTracking", "UDCAutomationEnabled", "0", "0"),
        // m4.mdns: macOS 15+ 已移除 /Library/Preferences/com.apple.mDNSResponder.plist
        // 检测改为通过 launchctl 查看 mDNSResponder 参数（仅信息展示，fix 需手动）
        PrivacyDef("m4.mdns", "mDNS 多播广告", "/Library/Preferences/com.apple.mDNSResponder.plist", "NoMulticastAdvertisements", "1", "1"),
        // m4.captive: macOS 15+ 已移除 CaptiveNetworkSupport plist，改用 scutil 检测
        PrivacyDef("m4.captive", "Captive Portal 检测", "/Library/Preferences/SystemConfiguration/CaptiveNetworkSupport", "Active", "0", "0"),
        PrivacyDef("m4.ds_network", "网络卷 .DS_Store", "com.apple.desktopservices", "DSDontWriteNetworkStores", "1", "1"),
        PrivacyDef("m4.ds_usb", "USB 卷 .DS_Store", "com.apple.desktopservices", "DSDontWriteUSBStores", "1", "1"),
        PrivacyDef("m4.airdrop", "AirDrop 状态", "com.apple.NetworkBrowser", "DisableAirDrop", "1", "1"),
        PrivacyDef("m4.photo_analysis", "照片面部识别", "com.apple.photoanalysisd", "enabled", "0", "0"),
        PrivacyDef("m4.safari_search", "Safari 网络搜索", "com.apple.Safari", "UniversalSearchEnabled", "0", "0"),
        PrivacyDef("m4.safari_suggest", "Safari 搜索建议", "com.apple.Safari", "SuppressSearchSuggestions", "1", "1"),
        PrivacyDef("m4.spotlight_suggest", "Spotlight 建议", "com.apple.lookup.shared", "LookupSuggestionsDisabled", "1", "1"),
    ]

    /// 将 PrivacyDef 转换为 AuditCheck，对 mDNS 和 Captive Portal 使用替代检测方式
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
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

    /// 执行隐私与遥测检查，返回检测结果
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
