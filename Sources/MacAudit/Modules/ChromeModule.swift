//
//  ChromeModule.swift
//  MacAudit
//
//  M14: Chrome 浏览器隐私安全模块
//  检测 Chrome Enterprise Policy 配置，包括 WebRTC IP 泄露防护、DNS/DoH 设置、
//  遥测上报、扩展安全等，Chrome 未安装时自动跳过所有检测。
//

import Foundation

/// M14: Chrome 浏览器隐私安全模块
struct ChromeModule: AuditModule {
    /// 模块唯一标识
    let id = "chrome"
    /// 模块显示名称
    let name = "Chrome 浏览器"
    /// 模块功能描述
    let description = "Chrome 隐私安全配置检测（Enterprise Policy）"

    /// Chrome Enterprise Policy 读取辅助
    /// 优先读 /Library/Managed Preferences（强制策略），fallback 到用户域
    private func chromeCmd(_ key: String) -> String {
        "r=$(defaults read '/Library/Managed Preferences/com.google.Chrome' '\(key)' 2>/dev/null); " +
        "[ -z \"$r\" ] && r=$(defaults read com.google.Chrome '\(key)' 2>/dev/null); " +
        "echo \"${r:-not set}\""
    }

    /// 检测 Chrome 是否已安装
    private func chromeInstalled() -> String {
        "test -d '/Applications/Google Chrome.app' && echo 'installed' || echo 'not installed'"
    }

    /// 生成 Chrome 隐私安全检查项，涵盖安装状态、WebRTC 防护、DoH、遥测、扩展安全等
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            // 安装状态
            AuditCheck(id: "m14.installed", name: "Chrome 安装状态", module: id,
                       description: "Chrome 未安装时无需检测其隐私设置\n安装方法: brew install --cask google-chrome\n或从 https://www.google.com/chrome/ 下载 .dmg 安装\n卸载: sudo rm -rf /Applications/Google\\ Chrome.app && rm -rf ~/Library/Application\\ Support/Google/Chrome",
                       command: chromeInstalled(),
                       expected: "installed", risk: .safe,
                       priority: .a0),

            // WebRTC IP 泄露防护（最重要）
            AuditCheck(id: "m14.webrtc_ip", name: "WebRTC IP 防泄露", module: id,
                       description: "防止 WebRTC 绕过代理暴露真实 IP，即使使用 VPN/代理也可能泄露",
                       command: chromeCmd("WebRtcIPHandlingPolicy"),
                       expected: "disable_non_proxied_udp", risk: .medium,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :WebRtcIPHandlingPolicy string disable_non_proxied_udp' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :WebRtcIPHandlingPolicy disable_non_proxied_udp' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                       priority: .a0),

            // DNS over HTTPS — 关闭让系统/Surge 接管
            AuditCheck(id: "m14.doh", name: "Chrome 内置 DoH", module: id,
                       description: "Chrome 默认会升级到 Google DoH 8.8.8.8，绕过本地 DNS/Surge 设置",
                       command: chromeCmd("DnsOverHttpsMode"),
                       expected: "off", risk: .medium,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :DnsOverHttpsMode string off' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :DnsOverHttpsMode off' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                       priority: .a0),

            AuditCheck(id: "m14.builtin_dns", name: "Chrome 内置 DNS 客户端", module: id,
                       description: "禁用让 OS/Surge 统一接管所有 DNS 解析",
                       command: chromeCmd("BuiltInDnsClientEnabled"),
                       expected: "0", risk: .medium,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :BuiltInDnsClientEnabled bool false' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :BuiltInDnsClientEnabled false' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                       priority: .a0),

            // 遥测/崩溃上报
            AuditCheck(id: "m14.metrics", name: "Chrome 遥测上报", module: id,
                        description: "禁用崩溃报告和使用统计发送到 Google",
                        command: chromeCmd("MetricsReportingEnabled"),
                        expected: "0", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :MetricsReportingEnabled bool false' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :MetricsReportingEnabled false' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            AuditCheck(id: "m14.safe_browsing_reporting", name: "Safe Browsing 扩展上报", module: id,
                        description: "禁用 Enhanced 模式的页面截图和文件信息上传，保留标准保护",
                        command: chromeCmd("SafeBrowsingExtendedReportingEnabled"),
                        expected: "0", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :SafeBrowsingExtendedReportingEnabled bool false' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :SafeBrowsingExtendedReportingEnabled false' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            // 网络预加载
            AuditCheck(id: "m14.network_predict", name: "Chrome 网络预加载", module: id,
                        description: "禁用预解析 DNS/预连接服务器，防止向未访问站点发送请求",
                        command: chromeCmd("NetworkPredictionOptions"),
                        expected: "2", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :NetworkPredictionOptions integer 2' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :NetworkPredictionOptions 2' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            AuditCheck(id: "m14.search_suggest", name: "Chrome 搜索建议", module: id,
                        description: "每次按键实时发送到 Google，禁用减少数据上报",
                        command: chromeCmd("SearchSuggestEnabled"),
                        expected: "0", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :SearchSuggestEnabled bool false' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :SearchSuggestEnabled false' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            // 云服务
            AuditCheck(id: "m14.translate", name: "Chrome 翻译服务", module: id,
                        description: "禁用页面翻译，防止页面内容发送到 Google",
                        command: chromeCmd("TranslateEnabled"),
                        expected: "0", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :TranslateEnabled bool false' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :TranslateEnabled false' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            AuditCheck(id: "m14.spellcheck", name: "Chrome 云端拼写检查", module: id,
                        description: "禁用将输入文字发送到 Google 服务器做拼写检查",
                        command: chromeCmd("SpellCheckServiceEnabled"),
                        expected: "0", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :SpellCheckServiceEnabled bool false' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :SpellCheckServiceEnabled false' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            // 扩展安全
            AuditCheck(id: "m14.ext_sideload", name: "Chrome 扩展旁加载", module: id,
                        description: "阻止第三方软件（安装包等）静默安装 Chrome 扩展",
                        command: chromeCmd("BlockExternalExtensions"),
                        expected: "1", risk: .safe,
                        fixRisk: .low,
                        fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add :BlockExternalExtensions bool true' '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null || sudo /usr/libexec/PlistBuddy -c 'Set :BlockExternalExtensions true' '/Library/Managed Preferences/com.google.Chrome.plist'; sudo chown root:wheel '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; sudo chmod 644 '/Library/Managed Preferences/com.google.Chrome.plist' 2>/dev/null; true",
                        priority: .a0),

            // 手动操作提示
            AuditCheck(id: "m14.signin", name: "Chrome Google 账号登录", module: id,
                        description: "手动操作: Chrome > Settings > 关闭 Sign in to Chrome（避免浏览数据同步到 Google）",
                        command: chromeCmd("BrowserSignin"),
                        expected: "0",
                        priority: .a0),

            AuditCheck(id: "m14.policy_check", name: "Chrome 策略生效验证", module: id,
                       description: "手动验证: 打开 chrome://policy 确认所有策略已生效",
                        command: "test -f '/Library/Managed Preferences/com.google.Chrome.plist' && echo 'exists' || echo 'missing'",
                        expected: "exists", risk: .safe,
                        priority: .a0),
        ].map { var c = $0; c.priority = .a0; return c }
    }

    /// 执行 Chrome 检测，未安装时跳过所有检查
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        // 如果 Chrome 未安装，跳过所有检测
        let installed = await executor.run("test -d '/Applications/Google Chrome.app' && echo 'yes' || echo 'no'")
        if installed.trimmedOutput != "yes" {
            return checks(for: version, device: device, arch: arch).map { check in
                .skip(check: check, reason: "Chrome 未安装")
            }
        }
        return await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
