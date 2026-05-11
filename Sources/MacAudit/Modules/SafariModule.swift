//
//  SafariModule.swift
//  MacAudit
//
//  M15: Safari 浏览器隐私安全模块
//  检测 Safari 隐私安全配置（基于 CIS Benchmark + 官方最佳实践），
//  包括搜索建议与遥测、安全防护、WebKit 弹窗拦截、AutoFill 隐私、
//  私有浏览指纹保护等，Tahoe 版本额外检测常规浏览指纹保护。
//

import Foundation

/// M15: Safari 浏览器隐私安全模块
struct SafariModule: AuditModule {
    /// 模块唯一标识
    let id = "safari"
    /// 模块显示名称
    let name = "Safari 浏览器"
    /// 模块功能描述
    let description = "Safari 隐私安全配置检测（CIS Benchmark + 官方最佳实践）"

    /// 构建 Safari defaults 读取命令
    private func safariCmd(_ key: String) -> String {
        "defaults read com.apple.Safari '\(key)' 2>/dev/null || echo 'not set'"
    }

    /// 生成 Safari 隐私安全检查项，Tahoe 版本额外包含常规浏览指纹保护
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        let isTahoe = version == .tahoe
        var list: [AuditCheck] = [

            // ── 搜索建议与遥测 ──────────────────────────────
            AuditCheck(id: "m15.search_universal", name: "Safari 网页搜索上报", module: id,
                       description: "禁止地址栏内容发送给 Apple/第三方",
                       command: safariCmd("UniversalSearchEnabled"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.Safari UniversalSearchEnabled -bool false",
                       priority: .a0),

            AuditCheck(id: "m15.search_suggest", name: "Safari 搜索建议", module: id,
                       description: "禁用实时搜索建议减少网络请求",
                       command: safariCmd("SuppressSearchSuggestions"),
                       expected: "1", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.Safari SuppressSearchSuggestions -bool true",
                       priority: .a0),

            AuditCheck(id: "m15.preload", name: "Safari 预加载顶部结果", module: id,
                       description: "禁用预加载，阻止 Safari 向未访问站点发送未授权连接",
                       command: safariCmd("PreloadTopHit"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.Safari PreloadTopHit -bool false",
                       priority: .a0),

            // ── 安全防护（CIS Benchmark 要求）────────────────
            AuditCheck(id: "m15.fraud_warning", name: "Safari 欺诈网站警告", module: id,
                       description: "CIS 基线要求：启用欺诈网站检测（Google Safe Browsing）",
                       command: safariCmd("WarnAboutFraudulentWebsites"),
                       expected: "1", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true",
                       priority: .a0),

            AuditCheck(id: "m15.auto_open", name: "Safari 自动打开下载", module: id,
                       description: "CIS 基线要求：禁止自动打开\"安全\"下载，防文件解析漏洞",
                       command: safariCmd("AutoOpenSafeDownloads"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari AutoOpenSafeDownloads -bool false",
                        priority: .a0),

            AuditCheck(id: "m15.full_url", name: "Safari 显示完整 URL", module: id,
                       description: "显示完整 URL 防止地址栏欺骗（如 apple.com.evil.com）",
                       command: safariCmd("ShowFullURLInSmartSearchField"),
                       expected: "1", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true",
                        priority: .a0),

            AuditCheck(id: "m15.ext_update", name: "Safari 扩展自动更新", module: id,
                       description: "自动更新扩展以修补已知安全漏洞",
                       command: safariCmd("InstallExtensionUpdatesAutomatically"),
                       expected: "1", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true",
                        priority: .a0),

            // ── WebKit 弹窗拦截 ───────────────────────────────
            AuditCheck(id: "m15.popup_block_webkit", name: "Safari 阻止弹窗 (WebKit)", module: id,
                       description: "阻止 JavaScript 自动打开弹窗（广告/钓鱼）— WebKit 层",
                       command: safariCmd("WebKitJavaScriptCanOpenWindowsAutomatically"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false",
                        priority: .a0),

            AuditCheck(id: "m15.popup_block_webkit2", name: "Safari 阻止弹窗 (WebKit2)", module: id,
                       description: "阻止 JavaScript 自动打开弹窗（广告/钓鱼）— WebKit2 层",
                       command: safariCmd("WebKit2JavaScriptCanOpenWindowsAutomatically"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari WebKit2JavaScriptCanOpenWindowsAutomatically -bool false",
                        priority: .a0),

            // ── AutoFill 隐私 ─────────────────────────────────
            AuditCheck(id: "m15.autofill_address", name: "Safari 地址自动填充", module: id,
                       description: "禁用，建议改用专用密码管理器（1Password/Bitwarden）",
                       command: safariCmd("AutoFillFromAddressBook"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari AutoFillFromAddressBook -bool false",
                        priority: .a0),

            AuditCheck(id: "m15.autofill_cc", name: "Safari 信用卡自动填充", module: id,
                       description: "禁用，防止信用卡数据暴露给恶意脚本",
                       command: safariCmd("AutoFillCreditCardData"),
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari AutoFillCreditCardData -bool false",
                        priority: .a0),

            // ── 私有浏览增强（两版本均适用）──────────────────
            AuditCheck(id: "m15.enhanced_private", name: "Safari 私有浏览指纹保护", module: id,
                       description: "启用私有浏览的高级跟踪和指纹识别防护",
                       command: safariCmd("EnableEnhancedPrivacyInPrivateBrowsing"),
                       expected: "1", risk: .safe,
                       fixRisk: .low,
                        fixCommand: "defaults write com.apple.Safari EnableEnhancedPrivacyInPrivateBrowsing -bool true",
                        priority: .a0),
        ]

        // ── Tahoe 专属 ────────────────────────────────────────
        if isTahoe {
            list.append(AuditCheck(
                id: "m15.enhanced_regular", name: "Safari 常规浏览指纹保护", module: id,
                description: "Tahoe 新增：常规浏览模式的高级跟踪/指纹识别防护（阻止跨站跟踪、限制设备信息 API）",
                command: safariCmd("EnableEnhancedPrivacyInRegularBrowsing"),
                expected: "1",
                versions: [.tahoe],
                risk: .safe,
                fixRisk: .low,
                fixCommand: "defaults write com.apple.Safari EnableEnhancedPrivacyInRegularBrowsing -bool true",
            priority: .a0))
        }

        // ── 手动操作提示 ──────────────────────────────────────
        let hideIPPath = isTahoe
            ? "手动操作: Safari > Settings > Privacy > Hide IP address（Tahoe: 选择 Trackers and Websites）"
            : "手动操作: Safari > Settings > Privacy > Hide IP address from trackers"

        list.append(AuditCheck(
            id: "m15.private_relay", name: "Safari IP 隐藏", module: id,
            description: hideIPPath,
            command: "defaults read com.apple.Safari WBSEnablePrivateRelay 2>/dev/null || echo 'not set'",
        priority: .a0))

        return list.map { var c = $0; c.priority = .a0; return c }
    }

    /// 执行 Safari 隐私安全检查，返回检测结果
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
