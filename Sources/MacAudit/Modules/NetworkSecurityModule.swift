//
//  NetworkSecurityModule.swift
//  MacAudit
//
//  M2+M3+M8: 网络安全机制及调优模块（合并自 SecurityModule、NetworkModule、NetworkTuningModule）
//  检测系统安全机制（SIP、Gatekeeper、防火墙、FileVault 等）、
//  网络安全配置（SSH、AirPlay、SMB、IPv6、Surge 等）、
//  网络内核调优参数（TCP 缓冲区、延迟 ACK、窗口缩放等 sysctl 参数）。
//

import Foundation
import MacAuditCore

/// M2+M3+M8: 网络安全机制及调优（合并自 SecurityModule、NetworkModule、NetworkTuningModule）
struct NetworkSecurityModule: AuditModule {
    /// 模块唯一标识
    let id = "network_security"
    /// 模块显示名称
    let name = "网络安全机制及调优"
    /// 模块功能描述
    let description = "系统安全、网络配置和内核参数检测"

    // MARK: - Wi-Fi 接口名
    // 不要改回 Process() 探测！GUI 会在 dispatch_once 里递归死锁。
    // 详见 MacAuditCore 版同名注释。硬编码安全。
    // 如在 VM/服务器上运行（无 Wi-Fi 接口），相关 networksetup 命令会优雅失败。
    // 用户可手动将下方的 "Wi-Fi" 改为实际接口名（如 "Ethernet"）。

    /// Wi-Fi 接口名称，硬编码避免 Process() 死锁
    private static let wifiInterfaceName = "Wi-Fi"

    // MARK: - sysctl 参数定义（原 NetworkTuningModule）

    /// sysctl 参数定义
    private struct SysctlDef {
        /// sysctl 参数路径
        let param: String
        /// 期望值
        let expected: String
        /// 参数显示名称
        let name: String
        /// 参数说明
        let description: String
        /// 适用的 macOS 版本集合
        let versions: Set<MacOSVersion>
        /// 风险等级
        let risk: RiskLevel
        /// 便捷初始化器
        init(_ param: String, _ expected: String, _ name: String,
             _ description: String = "",
             _ versions: Set<MacOSVersion> = [], _ risk: RiskLevel = .safe) {
            self.param = param; self.expected = expected; self.name = name
            self.description = description
            self.versions = versions; self.risk = risk
        }
    }

    /// 网络内核调优 sysctl 参数定义列表
    private let sysctlParams: [SysctlDef] = [
        SysctlDef("net.inet.tcp.sendspace", "1048576", "TCP 发送缓冲区",
            "TCP 发送缓冲区大小（字节）。默认 131072（128KB），调优至 1MB 可提升大文件传输和 AI API 流式响应速度。\n修复: sudo sysctl -w net.inet.tcp.sendspace=1048576\n持久化: 见 m8.sysctl_plist"),
        SysctlDef("net.inet.tcp.recvspace", "1048576", "TCP 接收缓冲区",
            "TCP 接收缓冲区大小（字节）。调优至 1MB 可改善高延迟网络（代理链路）下的吞吐量。\n修复: sudo sysctl -w net.inet.tcp.recvspace=1048576"),
        SysctlDef("net.inet.tcp.autorcvbufmax", "33554432", "TCP 自动接收上限",
            "TCP 自动调节接收缓冲区的最大值（32MB）。允许内核在高速连接时自动扩大缓冲区。\n修复: sudo sysctl -w net.inet.tcp.autorcvbufmax=33554432"),
        SysctlDef("net.inet.tcp.autosndbufmax", "33554432", "TCP 自动发送上限",
            "TCP 自动调节发送缓冲区的最大值（32MB）。\n修复: sudo sysctl -w net.inet.tcp.autosndbufmax=33554432"),
        SysctlDef("net.inet.tcp.mssdflt", "1460", "TCP MSS 默认值",
            "TCP 最大报文段大小。以太网标准值 1460（MTU 1500 - IP头 20 - TCP头 20）。\n若使用 VPN/代理，可能需要调小至 1360 避免分片。\n修复: sudo sysctl -w net.inet.tcp.mssdflt=1460"),
         SysctlDef("net.inet.tcp.delayed_ack", "0", "延迟 ACK",
             "禁用延迟 ACK（Nagle 算法的伴生机制）。\n对实时性要求高的应用（如 Claude Code 流式响应）禁用延迟 ACK 可降低 RTT。\n修复: sudo sysctl -w net.inet.tcp.delayed_ack=0"),
         SysctlDef("net.inet.tcp.win_scale_factor", "8", "窗口缩放因子",
            "TCP 窗口缩放因子（RFC 1323）。值为 8 时最大窗口 = 65535 × 2^8 = 16MB，适合高带宽高延迟网络。\n修复: sudo sysctl -w net.inet.tcp.win_scale_factor=8"),
        SysctlDef("net.inet.tcp.local_slowstart_flightsize", "20", "本地慢启动拥塞窗口",
            "本地网络 TCP 慢启动初始拥塞窗口（数据包数）。提高至 20 可加快局域网传输初始速度。\n修复: sudo sysctl -w net.inet.tcp.local_slowstart_flightsize=20"),
        SysctlDef("net.inet.tcp.sack", "1", "SACK 启用",
            "选择性确认（Selective ACK，RFC 2018）。启用后丢包重传更高效，减少不必要的重传。\n修复: sudo sysctl -w net.inet.tcp.sack=1"),
        SysctlDef("net.inet.tcp.always_keepalive", "1", "TCP 保活探测",
            "对所有 TCP 连接启用保活探测，防止长时间空闲连接被防火墙/NAT 静默断开。\n对 Claude Code MCP 长连接尤其重要。\n修复: sudo sysctl -w net.inet.tcp.always_keepalive=1"),
        SysctlDef("net.inet.tcp.msl", "5000", "TCP MSL",
            "TCP 最大报文生存时间（毫秒）。默认 15000ms，调低至 5000ms 可加快 TIME_WAIT 状态回收，减少端口占用。\n修复: sudo sysctl -w net.inet.tcp.msl=5000"),
        SysctlDef("net.inet.tcp.blackhole", "2", "TCP 黑洞",
            "对未监听端口的 TCP 连接静默丢弃（不发送 RST 或 ICMP）。\n值为 2：完全黑洞模式，可防止端口扫描探测。\n修复: sudo sysctl -w net.inet.tcp.blackhole=2",
            [], .medium),
        SysctlDef("net.inet.udp.blackhole", "1", "UDP 黑洞",
            "对未监听端口的 UDP 数据包静默丢弃（不发送 ICMP Port Unreachable）。\n防止 UDP 端口扫描探测。\n修复: sudo sysctl -w net.inet.udp.blackhole=1",
            [], .medium),
        SysctlDef("net.inet6.ip6.accept_rtadv", "0", "IPv6 路由通告",
            "禁止接受 IPv6 路由通告（Router Advertisement）。\n防止自动配置 IPv6 路由，避免通过 IPv6 绕过代理直连目标服务器。\n注意：此参数在 macOS 上为只读 sysctl，实际通过 networksetup 管理。\n修复（关闭 Wi-Fi IPv6）: sudo networksetup -setv6off Wi-Fi",
            [], .medium),
        SysctlDef("net.inet6.ip6.forwarding", "0", "IPv6 转发",
            "禁用 IPv6 数据包转发（路由功能）。\n普通工作站不应启用 IPv6 转发，否则可能成为网络中继节点。\n注意：此参数在 macOS 上为只读 sysctl，通过 networksetup 管理。\n修复: sudo networksetup -setv6off Wi-Fi",
            [], .medium),
    ]

    // MARK: - checks()
    /// 生成安全机制（M2）、网络安全（M3）、网络内核调优（M8）三类检查项
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        let wifi = Self.wifiInterfaceName
        let wifiQ = "'\(wifi)'"
        var list: [AuditCheck] = []

        // ── 安全机制（原 M2）──────────────────────────────────
        list.append(contentsOf: [
            AuditCheck(id: "m2.sip", name: "SIP 状态", module: id,
                       description: """
SIP（System Integrity Protection）保护系统目录不被修改，是 macOS 最重要的安全机制之一。
【开启方法（需进入恢复模式）】
  Apple Silicon: 关机 → 长按电源键直到显示"继续按住..." → 进入恢复模式 → 打开"终端" → csrutil enable → 重启
  Intel Mac: 重启时按住 Cmd+R → 恢复模式 → 终端 → csrutil enable → 重启
【关闭方法（强烈不推荐）】
  恢复模式终端: csrutil disable
关闭 SIP 会使恶意软件能够修改系统文件，仅在特殊需求时临时关闭后立即重新开启。
""",
                       command: "csrutil status 2>/dev/null | grep -o 'enabled\\|disabled'",
                       expected: "enabled", risk: .safe,
                       priority: .a0),

            AuditCheck(id: "m2.gatekeeper", name: "Gatekeeper", module: id,
                       description: """
Gatekeeper 阻止运行未经 Apple 公证的应用程序，防止恶意软件伪装成普通应用执行。
开启（推荐）: sudo spctl --master-enable
关闭（不推荐）: sudo spctl --master-disable
临时绕过（运行单个未公证 App）: sudo xattr -r -d com.apple.quarantine /path/to/App.app
验证当前状态: spctl --status
""",
                       command: "spctl --status 2>/dev/null | head -1",
                       expected: "assessments enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo spctl --master-enable",
                       priority: .a0),

            AuditCheck(id: "m2.firewall", name: "防火墙全局状态", module: id,
                       description: """
macOS 应用层防火墙（ALF）控制哪些应用可以接受入站连接。
开启: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
关闭（不推荐）: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
验证: /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
GUI 路径: System Settings → Network → Firewall
""",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -o 'enabled\\|disabled'",
                       expected: "enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on",
                       priority: .a0),

            AuditCheck(id: "m2.stealth", name: "防火墙隐身模式", module: id,
                       description: """
防火墙隐身模式：不响应 ICMP ping 请求和未授权的 TCP/UDP 连接尝试，降低网络可发现性。
开启: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
关闭: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off
注意：开启后 ping 本机 IP 会超时（这是正常现象，不影响正常网络使用）。
""",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /enabled/{print \"enabled\";next} /disabled/{print \"disabled\";next} / on$/{print \"enabled\";next} / off$/{print \"disabled\";next}'",
                       expected: "enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on",
                       priority: .a0),

            AuditCheck(id: "m2.allowsigned", name: "防火墙签名应用", module: id,
                        description: """
允许已签名的 Apple 应用和 App Store 应用自动通过防火墙（不逐一弹窗询问）。
开启（推荐）: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
关闭（所有应用都需手动授权）: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
关闭会导致 Claude Code、Xcode 等签名应用启动时弹出防火墙授权提示。
注意: macOS 15 已合并 allowsigned 和 allowsignedapp 为单一 --setallowsigned 参数。
""",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null | grep -oi 'ENABLED\\|DISABLED' | head -1 | tr '[:upper:]' '[:lower:]'",
                       expected: "enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on",
                       priority: .a2),

            AuditCheck(id: "m2.firewall_apps", name: "防火墙应用列表", module: id,
                       description: """
防火墙中已配置规则的应用数量（ALF 条目数）。
查看已配置的应用列表: /usr/libexec/ApplicationFirewall/socketfilterfw --listapps
管理特定应用规则（允许入站）: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/App.app
移除应用规则: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --remove /path/to/App.app
""",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | grep -c 'Allow\\|Block' || echo 0",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m2.filevault", name: "FileVault 状态", module: id,
                       description: """
FileVault 对整个系统磁盘进行 AES-XTS 256 位加密，防止物理接触后数据被读取。
开启（推荐）:
  GUI: System Settings → Privacy & Security → FileVault → Turn On FileVault
  命令行: sudo fdesetup enable
注意：首次开启需 1-4 小时加密，期间可正常使用电脑（性能略有影响）。
关闭（不推荐）:
  GUI: System Settings → Privacy & Security → FileVault → Turn Off FileVault
恢复密钥: 开启时务必保存个人恢复密钥到安全位置（不要存在 iCloud）。
""",
                       command: "fdesetup status 2>/dev/null | head -1",
                       expected: "FileVault is On.", risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m2.filevault_key", name: "FileVault 恢复密钥", module: id,
                       description: """
FileVault 个人恢复密钥状态。恢复密钥是 FileVault 忘记密码时的唯一救命稻草。
检查是否有个人恢复密钥: fdesetup haspersonalrecoverykey
查看当前恢复密钥类型: sudo fdesetup status
生成新的个人恢复密钥（如丢失旧密钥）:
  sudo fdesetup changerecovery -personal
  按提示操作，会显示新的恢复密钥，务必记录到安全位置。
⚠ 警告：若恢复密钥丢失且忘记登录密码，数据将无法恢复。
""",
                       command: "fdesetup haspersonalrecoverykey 2>/dev/null | grep -o 'true\\|false' || echo 'disabled'",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m2.lock_password", name: "锁屏密码", module: id,
                       description: """
锁屏后（或屏保启动后）唤醒时是否要求输入密码。
开启（推荐）: defaults write com.apple.screensaver askForPassword -int 1
关闭（不推荐）: defaults write com.apple.screensaver askForPassword -int 0
GUI: System Settings → Lock Screen → Require password after screen saver begins
注意：需配合 m2.lock_delay 将延迟设为 0 秒（立即要求密码）。
""",
                       command: "defaults read com.apple.screensaver askForPassword 2>/dev/null || echo 'not set'",
                       expected: "1", risk: .safe, fixRisk: .low,
                         fixCommand: "defaults write com.apple.screensaver askForPassword 1",
                         priority: .a2),

            AuditCheck(id: "m2.lock_delay", name: "锁屏延迟", module: id,
                       description: """
锁屏密码生效延迟（秒）。0 = 立即要求密码（推荐）。
设为 0 秒: defaults write com.apple.screensaver askForPasswordDelay -int 0
设为 5 分钟: defaults write com.apple.screensaver askForPasswordDelay -int 300
GUI: System Settings → Lock Screen → Require password after screen saver begins → Immediately
""",
                       command: "defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo 'not set'",
                       expected: "0", risk: .safe, fixRisk: .low,
                         fixCommand: "defaults write com.apple.screensaver askForPasswordDelay -int 0",
                         priority: .a2),

            AuditCheck(id: "m2.autologin", name: "自动登录", module: id,
                       description: """
自动登录允许系统启动时无需输入密码直接进入桌面，严重降低物理安全性。
关闭自动登录（推荐）:
  sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser
  GUI: System Settings → General → Login Items & Extensions → 关闭 "Automatic login"
注意：开启 FileVault 后系统会强制要求输入密码，自动登录会被自动禁用。
验证: defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser（应报错 Domain not found）
""",
                       command: "defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo 'disabled'",
                       expected: "disabled", risk: .safe,
                       fixRisk: .high,
                         fixCommand: "sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser",
                         priority: .a2),

            AuditCheck(id: "m2.sysext", name: "系统扩展", module: id,
                       description: """
已激活的第三方系统扩展（System Extensions）数量。
系统扩展运行在用户空间（替代旧版内核扩展 kext），用于防病毒、VPN、网络过滤等功能。
查看所有扩展: systemextensionsctl list
移除扩展（需要相关应用支持）: 在应用设置中选择「卸载扩展」，或直接卸载应用。
高风险扩展标志：非知名开发者 + 请求网络过滤权限。
""",
                       command: "systemextensionsctl list 2>/dev/null | grep -c 'activated'; true",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m2.kext", name: "第三方 kext", module: id,
                       description: """
第三方内核扩展（Kernel Extensions）数量。
kext 运行在内核空间，具有最高权限，是恶意软件的高价值目标。
macOS Ventura+ 已逐步弃用 kext，建议迁移到系统扩展。
查看所有 kext: kextstat | grep -v com.apple
查看 kext 签名: kextstat | grep -v com.apple | awk '{print $6}'
移除第三方 kext: sudo kextunload /System/Library/Extensions/xxx.kext（需重启）
若发现不认识的 kext，立即调查其来源。
""",
                       command: "kextstat 2>/dev/null | grep -cv com.apple; true",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m2.launch_agents", name: "第三方 LaunchAgents", module: id,
                       description: """
第三方 LaunchAgents 和 LaunchDaemons 总数（用户目录 + 系统目录）。
LaunchAgents/Daemons 是 macOS 持久化运行代码的标准机制，也是恶意软件常用的持久化手段。
查看所有第三方 launch item:
  ls ~/Library/LaunchAgents/ 2>/dev/null       # 用户级 Agents
  ls /Library/LaunchAgents/ 2>/dev/null        # 系统级 Agents
  ls /Library/LaunchDaemons/ 2>/dev/null       # 系统级 Daemons
禁用可疑 launch item:
  launchctl disable gui/$(id -u)/com.suspicious.item
  launchctl disable system/com.suspicious.daemon
推荐工具审查: 使用 KnockKnock (https://objective-see.com) 扫描持久化项目。
""",
                       command: "(ls ~/Library/LaunchAgents/ 2>/dev/null; ls /Library/LaunchAgents/ 2>/dev/null; ls /Library/LaunchDaemons/ 2>/dev/null) | wc -l | tr -d ' '",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m2.xprotect", name: "XProtect 版本", module: id,
                       description: """
XProtect 是 macOS 内置的基于签名的反恶意软件引擎，Apple 自动更新签名库。
查看版本: /usr/libexec/PlistBuddy -c 'Print :Version' /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist
手动触发更新（通常自动更新）:
  macOS 15 Sequoia+: softwareupdate --background
  也可通过 System Settings → General → Software Update 触发
验证 XProtect 签名文件: ls /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/
注意：XProtect 版本号越高越新，应与当前 macOS 版本匹配。
""",
                       command: "/usr/libexec/PlistBuddy -c 'Print :Version' /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist 2>/dev/null || echo 'N/A'",
                       risk: .safe,
                       priority: .a2),
        ])

        // ── 网络安全（原 M3）──────────────────────────────────
        list.append(contentsOf: [
            AuditCheck(id: "m3.remote_login", name: "SSH 远程登录", module: id,
                       description: """
SSH 远程登录服务（sshd）状态。
若不需要远程 SSH 登录，应禁用以减小攻击面。
禁用（推荐，如不需要远程登录）:
  sudo systemsetup -setremotelogin off
  或: sudo launchctl disable system/com.openssh.sshd
启用（如需要远程登录）:
  sudo systemsetup -setremotelogin on
  GUI: System Settings → General → Sharing → Remote Login
安全建议：若需要 SSH，配置密钥认证并禁用密码登录:
  sudo sh -c 'echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
""",
                       command: "launchctl print-disabled system/ 2>/dev/null | grep sshd | grep -o 'enabled\\|disabled' || echo 'unknown'",
                       expected: "disabled", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo systemsetup -setremotelogin off 2>/dev/null; true",
                       priority: .a2),

            AuditCheck(id: "m3.remote_events", name: "远程 Apple Events", module: id,
                       description: """
远程 Apple Events（eppc）允许其他设备通过网络发送 AppleScript 命令控制本机应用。
这是一个少用但高风险的功能，建议关闭。
禁用（推荐）:
  sudo launchctl disable system/com.apple.eppc
  GUI: System Settings → General → Sharing → 关闭 Remote Apple Events
启用（如需要 AppleScript 远程控制）:
  sudo launchctl enable system/com.apple.eppc
验证: launchctl print-disabled system/ | grep eppc
""",
                       command: "launchctl print-disabled system/ 2>/dev/null | grep eppc | grep -o 'enabled\\|disabled' || echo 'unknown'",
                       expected: "disabled", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo launchctl disable system/com.apple.eppc 2>/dev/null; true",
                       priority: .a2),

            AuditCheck(id: "m3.airplay", name: "AirPlay 接收端", module: id,
                       description: """
AirPlay 接收端允许局域网内的其他 Apple 设备将视频/音频投射到本机（端口 5000/7000）。
若不需要接收 AirPlay 内容，建议关闭以减少网络暴露面。
关闭:
  GUI: System Settings → General → AirDrop & Handoff → AirPlay Receiver → Off
  命令行（macOS 15）: sudo defaults write /Library/Preferences/com.apple.AirPlayReceiver enabled -int 0
开启:
  GUI: System Settings → General → AirDrop & Handoff → AirPlay Receiver → On
""",
                       command: "result=$(lsof -nP -iTCP:5000 -sTCP:LISTEN 2>/dev/null | grep -c ControlCe); echo \"${result:-0}\"",
                       expected: "0", risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m3.smb", name: "SMB 共享点数", module: id,
                       description: """
SMB/AFP 文件共享活跃共享点数量。期望为 0（不开放任何共享）。
禁用所有文件共享:
  sudo launchctl disable system/com.apple.smbd
  sudo launchctl stop com.apple.smbd
  GUI: System Settings → General → Sharing → 关闭 File Sharing
启用（如需局域网共享）:
  sudo launchctl enable system/com.apple.smbd
  sudo launchctl start com.apple.smbd
安全提醒：SMB 共享在局域网内无需认证即可被发现，建议只在需要时临时开启。
""",
                       command: "sharing -l 2>/dev/null | grep -c 'name:'",
                       expected: "0", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo launchctl disable system/com.apple.smbd 2>/dev/null; sudo launchctl stop com.apple.smbd 2>/dev/null; true",
                       priority: .a2),

            AuditCheck(id: "m3.listening_ports", name: "监听端口数", module: id,
                       description: """
当前监听 TCP 入站连接的端口数量。
查看所有监听端口（含进程）: lsof -nP -iTCP -sTCP:LISTEN
查看高风险端口（非标准端口）: lsof -nP -iTCP -sTCP:LISTEN | grep -v ':(80|443|22|631) '
关闭不明端口步骤：
1. 找到占用进程: lsof -nP -iTCP:PORT_NUM -sTCP:LISTEN
2. 查看进程详情: ps aux | grep PID
3. 禁用对应服务或应用
安全基线：只保留必要的监听端口（如 SSH 22、开发服务器等）。
""",
                       command: "lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | tail -n +2 | wc -l | tr -d ' '",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m3.interfaces", name: "活跃网络接口", module: id,
                       description: """
当前 UP 状态的网络接口数量（含以太网、Wi-Fi、虚拟接口等）。
查看所有接口: ifconfig | grep -E '^[a-z]'
查看活跃接口详情: ifconfig | grep -A 4 'flags=.*UP'
关注点：
  utun* 接口 = VPN/代理隧道（Surge TUN 模式会创建 utun 接口）
  bridge* 接口 = 虚拟化网桥（Docker/OrbStack 创建）
  过多 utun 接口可能表示多个 VPN 同时运行，可能产生路由冲突。
""",
                       command: "ifconfig 2>/dev/null | grep -c 'flags=.*UP'",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m3.dns", name: "DNS 服务器", module: id,
                       description: """
当前使用的 DNS 服务器列表。DNS 服务器可见你访问的所有域名，是重要的隐私点。
查看当前 DNS 配置: scutil --dns | grep nameserver
使用加密 DNS（DoH/DoT）推荐配置：
  Cloudflare（推荐）: 1.1.1.1 和 1.0.0.1
    设置: networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1
  Google: 8.8.8.8 和 8.8.4.4
  NextDNS（支持自定义过滤）: 45.90.28.x
使用 Surge 时：Surge 的 Fake IP（198.18.0.2）会接管所有 DNS 解析，为正常现象。
恢复自动 DNS: networksetup -setdnsservers Wi-Fi Empty
""",
                       command: "scutil --dns 2>/dev/null | grep 'nameserver\\[0\\]' | head -3 | awk '{print $3}' | paste -sd ',' -",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m3.surge_dns", name: "Surge Fake IP", module: id,
                       description: """
检测 Surge 增强模式（Enhanced Mode）Fake IP DNS 是否激活。
Surge Fake IP（198.18.0.2）接管系统 DNS 时，所有 DNS 查询经过 Surge 处理，
防止 DNS 泄露到本地 ISP DNS 服务器。
启用方法: Surge → 启用增强模式（Enhanced Mode）
验证: scutil --dns | grep 198.18.0.2
若不使用 Surge，此项显示为 0 属于正常，可使用其他代理软件的 DNS 接管方案。
""",
                       command: "scutil --dns 2>/dev/null | grep -c '198.18.0.2'",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m3.ipv6", name: "IPv6 全局地址", module: id,
                       description: """
具有全局路由能力的 IPv6 地址数量（不含 fe80 链路本地和 ::1 回环地址）。
⚠ 风险：IPv6 地址可绕过仅覆盖 IPv4 的代理，直接连接目标服务器，暴露真实 IP。
关闭所有接口的 IPv6（推荐在使用代理时）:
  networksetup -listallnetworkservices | grep -v '^\\*' | tail -n +2 | while read svc; do sudo networksetup -setv6off "$svc"; done
只关闭 Wi-Fi 的 IPv6:
  sudo networksetup -setv6off Wi-Fi
恢复（允许 IPv6）:
  sudo networksetup -setv6automatic Wi-Fi
""",
                       command: "ifconfig 2>/dev/null | grep inet6 | grep -v 'fe80\\|::1\\|%lo' | wc -l | tr -d ' '",
                       expected: "0", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo networksetup -setv6off \(wifiQ)",
                       networkRisk: true,
                       priority: .a2),

            AuditCheck(id: "m3.surge_dashboard", name: "Surge Dashboard", module: id,
                       description: """
Surge Dashboard 控制端口（6170）监听状态。
若 Surge 正在运行且 Dashboard 已绑定，此处显示 TCP 监听端口信息。
安全提醒：Dashboard 端口若暴露在公网会有安全风险，确保防火墙阻止外部访问 6170 端口。
查看 Surge 代理状态: lsof -nP -iTCP:6152 -sTCP:LISTEN
""",
                       command: "lsof -nP -iTCP:6170 -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print $9}'",
                       risk: .safe,
                       priority: .a2),

            AuditCheck(id: "m3.wifi_ipv6", name: "Wi-Fi IPv6", module: id,
                       description: """
Wi-Fi 接口的 IPv6 状态。建议关闭以防止 IPv6 绕过代理。
macOS 15 Sequoia 和 macOS 26 Tahoe 均支持以下命令:
  关闭: sudo networksetup -setv6off Wi-Fi
  自动（恢复）: sudo networksetup -setv6automatic Wi-Fi
  手动: sudo networksetup -setv6manual Wi-Fi <address> <prefix-length> <router>
验证: networksetup -getinfo Wi-Fi | grep IPv6
""",
                       command: "networksetup -getinfo \(wifiQ) 2>/dev/null | grep '^IPv6:' | awk '{print $2}'",
                       expected: "Off", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo networksetup -setv6off \(wifiQ)",
                       networkRisk: true,
                       priority: .a2),

            AuditCheck(id: "m3.wifi_proxy", name: "Wi-Fi HTTP 代理", module: id,
                       description: """
Wi-Fi 接口的系统级 HTTP 代理设置状态（Enabled/Disabled）。
设置系统代理（以 Surge 6152 为例）:
  sudo networksetup -setwebproxy Wi-Fi 127.0.0.1 6152
  sudo networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 6152
取消系统代理:
  sudo networksetup -setwebproxystate Wi-Fi off
  sudo networksetup -setsecurewebproxystate Wi-Fi off
注意：Surge 等代理软件通常会自动管理系统代理设置，无需手动操作。
""",
                       command: "networksetup -getwebproxy \(wifiQ) 2>/dev/null | grep '^Enabled:' | awk '{print $2}'",
                       risk: .safe,
                       priority: .a2),
        ])

        // ── 网络内核调优（原 M8）──────────────────────────────
        let maxsockbufExpected = arch.isAppleSilicon ? "6291456" : "16777216"
        let maxsockbufDesc = arch.isAppleSilicon
            ? "Socket 缓冲区总上限（6MB，macOS arm64 内核硬限制，无法超过此值）。\n限制单个 Socket 可使用的最大缓冲区。\n若当前值低于 6291456，可通过以下命令恢复: sudo sysctl -w kern.ipc.maxsockbuf=6291456\n⚠ arm64 硬限制: 无法通过 sysctl 提升至 6291456 以上，需通过 LaunchDaemon 持久化设置。"
            : "Socket 缓冲区总上限（16MB，macOS x86_64 默认值）。\nIntel Mac 内核支持更大的缓冲区上限，保持默认即可。\n修复: sudo sysctl -w kern.ipc.maxsockbuf=16777216"
        list.append(AuditCheck(
            id: "m8.kern_ipc_maxsockbuf", name: "Socket 缓冲区上限", module: id,
            description: maxsockbufDesc,
            command: "sysctl -n kern.ipc.maxsockbuf 2>/dev/null || echo 'not set'",
            expected: maxsockbufExpected, risk: .safe,
            fixRisk: .high, fixCommand: "sudo sysctl -w kern.ipc.maxsockbuf=\(maxsockbufExpected)",
            priority: .a2
        ))

        for p in sysctlParams.filter({ $0.versions.isEmpty || $0.versions.contains(version) }) {
            // net.inet6.ip6.accept_rtadv 和 net.inet6.ip6.forwarding 是只读 sysctl
            // 实际通过 networksetup 管理，fixCommand 指向 networksetup
            let isReadonlySysctl = p.param == "net.inet6.ip6.accept_rtadv" || p.param == "net.inet6.ip6.forwarding"
            let actualFixCmd = isReadonlySysctl
                ? "sudo networksetup -setv6off \(wifiQ)"
                : "sudo sysctl -w \(p.param)=\(p.expected)"
            list.append(AuditCheck(
                id: "m8.\(p.param.replacingOccurrences(of: ".", with: "_"))",
                name: p.name, module: id,
                description: p.description,
                command: "sysctl -n \(p.param) 2>/dev/null || echo 'not set'",
                expected: p.expected, risk: p.risk,
                fixRisk: .high,
                fixCommand: actualFixCmd,
                networkRisk: p.param.contains("inet6"),
                priority: .a2
            ))
        }

        list.append(AuditCheck(
            id: "m8.sysctl_plist", name: "sysctl 持久化 plist", module: id,
            description: """
/Library/LaunchDaemons/com.server.sysctl.plist 不存在。
通过 sudo sysctl -w 设置的参数在重启后会失效，需创建 LaunchDaemon 实现持久化。
创建方法（包含所有推荐调优参数）:
  sudo /usr/libexec/PlistBuddy \\
    -c 'Add Label string com.server.sysctl' \\
    -c 'Add ProgramArguments array' \\
    -c 'Add ProgramArguments:0 string /usr/sbin/sysctl' \\
    -c 'Add ProgramArguments:1 string -w' \\
    -c 'Add ProgramArguments:2 string net.inet.tcp.sendspace=1048576' \\
    -c 'Add ProgramArguments:3 string net.inet.tcp.recvspace=1048576' \\
    -c 'Add ProgramArguments:4 string net.inet.tcp.autorcvbufmax=33554432' \\
    -c 'Add ProgramArguments:5 string net.inet.tcp.autosndbufmax=33554432' \\
    -c 'Add ProgramArguments:6 string net.inet.tcp.delayed_ack=0' \\
    -c 'Add ProgramArguments:7 string kern.ipc.maxsockbuf=6291456' \\
    -c 'Add ProgramArguments:8 string net.inet.tcp.win_scale_factor=8' \\
    -c 'Add RunAtLoad bool true' \\
    /Library/LaunchDaemons/com.server.sysctl.plist
  sudo launchctl load /Library/LaunchDaemons/com.server.sysctl.plist
取消持久化:
  sudo launchctl unload /Library/LaunchDaemons/com.server.sysctl.plist
  sudo rm /Library/LaunchDaemons/com.server.sysctl.plist
""",
            command: "test -f /Library/LaunchDaemons/com.server.sysctl.plist && echo 'exists' || echo 'missing'",
            risk: .safe,
            fixRisk: .high,
            fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add Label string com.server.sysctl' -c 'Add ProgramArguments array' -c 'Add ProgramArguments:0 string /usr/sbin/sysctl' -c 'Add ProgramArguments:1 string -w' -c 'Add ProgramArguments:2 string net.inet.tcp.sendspace=1048576' -c 'Add ProgramArguments:3 string net.inet.tcp.recvspace=1048576' -c 'Add ProgramArguments:4 string net.inet.tcp.autorcvbufmax=33554432' -c 'Add ProgramArguments:5 string net.inet.tcp.autosndbufmax=33554432' -c 'Add ProgramArguments:6 string net.inet.tcp.delayed_ack=0' -c 'Add ProgramArguments:7 string kern.ipc.maxsockbuf=6291456' -c 'Add ProgramArguments:8 string net.inet.tcp.win_scale_factor=8' -c 'Add RunAtLoad bool true' /Library/LaunchDaemons/com.server.sysctl.plist 2>/dev/null && sudo launchctl load /Library/LaunchDaemons/com.server.sysctl.plist 2>/dev/null; true",
            priority: .a2
        ))

        let dnsLeakIds: Set<String> = [
            "m3.dns", "m3.surge_dns", "m3.ipv6", "m3.wifi_ipv6", "m3.wifi_proxy", "m3.surge_dashboard",
        ]
        return list.map { var c = $0
            if dnsLeakIds.contains(c.id) || c.id.contains("inet6") { c.priority = .a0 }
            return c
        }
    }

    /// 执行网络安全检查，返回检测结果
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
