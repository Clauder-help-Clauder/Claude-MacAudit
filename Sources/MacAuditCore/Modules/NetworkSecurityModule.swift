import Foundation

/// M2+M3+M8: 网络安全机制及调优（合并自 SecurityModule、NetworkModule、NetworkTuningModule）
public struct NetworkSecurityModule: AuditModule {
    public init() {}

    public let id = "network_security"
    public let name = "网络安全机制及调优"
    public let description = "系统安全、网络配置和内核参数检测"

    // MARK: - Wi-Fi 接口名
    // ⚠️ 不要改回 Process() 探测！历史教训：
    //   - 2026-04-xx: 最初用同步 Process() → SwiftUI 主线程 SIGSEGV
    //   - 2026-04-19 01:59: 改 static let + Process() → dispatch_once 递归死锁崩溃
    //     （waitUntilExit 跑 RunLoop → SwiftUI 观察者重入 layout → 再访问 static → 递归锁）
    // 硬编码安全：99% 的 Mac 默认就是 "Wi-Fi"，极端情况下 networksetup
    // 相关命令会优雅失败（接口不存在）而不是崩溃。
    private static let wifiInterfaceName = "Wi-Fi"

    // MARK: - sysctl 参数定义（原 NetworkTuningModule）
    private struct SysctlDef {
        let param: String
        let expected: String
        let name: String
        let description: String
        let versions: Set<MacOSVersion>
        let risk: RiskLevel
        init(_ param: String, _ expected: String, _ name: String,
             _ description: String = "",
             _ versions: Set<MacOSVersion> = [], _ risk: RiskLevel = .safe) {
            self.param = param; self.expected = expected; self.name = name
            self.description = description
            self.versions = versions; self.risk = risk
        }
    }

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
    public func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        let wifi = Self.wifiInterfaceName
        let wifiQ = "'\(wifi)'"
        var list: [AuditCheck] = []

        // ── 安全机制（原 M2）──────────────────────────────────
        list.append(contentsOf: [
            AuditCheck(id: "m2.sip", name: "SIP 状态", module: id,
                       description: "添加防护: SIP（System Integrity Protection）应保持开启，防止恶意代码修改系统文件\n开启方法: 重启 Mac → 进入恢复模式（Apple Silicon 长按开机键，Intel 按 Cmd+R）→ 终端执行 csrutil enable → 重启\n取消防护（不推荐）: 恢复模式终端执行 csrutil disable",
                       command: "csrutil status 2>/dev/null | grep -o 'enabled\\|disabled'",
                       expected: "enabled", risk: .safe,
                       priority: .a0),
            AuditCheck(id: "m2.gatekeeper", name: "Gatekeeper", module: id,
                       description: "添加防护: 开启 Gatekeeper，阻止运行未经公证的应用\n复制以下命令到终端执行:\nsudo spctl --master-enable\n取消防护（不推荐）:\nsudo spctl --master-disable",
                       command: "spctl --status 2>/dev/null | head -1",
                       expected: "assessments enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo spctl --master-enable",
                       priority: .a0),
            AuditCheck(id: "m2.firewall", name: "防火墙全局状态", module: id,
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -o 'enabled\\|disabled'",
                       expected: "enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on",
                       priority: .a0),
            AuditCheck(id: "m2.stealth", name: "防火墙隐身模式", module: id,
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /enabled/{print \"enabled\";next} /disabled/{print \"disabled\";next} / on$/{print \"enabled\";next} / off$/{print \"disabled\";next}'",
                       expected: "enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on",
                       priority: .a0),
            AuditCheck(id: "m2.allowsigned", name: "防火墙签名应用", module: id,
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null | grep -oi 'ENABLED\\|DISABLED' | head -1 | tr '[:upper:]' '[:lower:]'",
                       expected: "enabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on"),
            AuditCheck(id: "m2.firewall_apps", name: "防火墙应用列表", module: id,
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | grep -c 'Allow\\|Block' || echo 0",
                       risk: .safe),
            AuditCheck(id: "m2.filevault", name: "FileVault 状态", module: id,
                       description: "添加防护: 开启 FileVault 磁盘加密，防止物理访问数据泄露\n开启方法: System Settings → Privacy & Security → FileVault → Turn On\n或终端执行: sudo fdesetup enable\n取消防护: System Settings → Privacy & Security → FileVault → Turn Off",
                       command: "fdesetup status 2>/dev/null | head -1",
                       expected: "FileVault is On.", risk: .safe),
            AuditCheck(id: "m2.filevault_key", name: "FileVault 恢复密钥", module: id,
                       command: "fdesetup haspersonalrecoverykey 2>/dev/null | grep -o 'true\\|false' || echo 'disabled'",
                       risk: .safe),
            AuditCheck(id: "m2.lock_password", name: "锁屏密码", module: id,
                       command: "defaults read com.apple.screensaver askForPassword 2>/dev/null || echo 'not set'",
                       expected: "1", risk: .safe, fixRisk: .low,
                       fixCommand: "defaults write com.apple.screensaver askForPassword -bool true"),
            AuditCheck(id: "m2.lock_delay", name: "锁屏延迟", module: id,
                       command: "defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo 'not set'",
                       expected: "0", risk: .safe, fixRisk: .low,
                       fixCommand: "defaults write com.apple.screensaver askForPasswordDelay -int 0"),
            AuditCheck(id: "m2.autologin", name: "自动登录", module: id,
                       description: "添加防护: 关闭自动登录，防止物理接触即可访问系统\n复制以下命令到终端执行:\nsudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser\n取消防护（不推荐）:\nsudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser $(whoami)",
                       command: "defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo 'disabled'",
                       expected: "disabled", risk: .safe,
                       fixRisk: .high,
                       fixCommand: "sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser"),
            AuditCheck(id: "m2.sysext", name: "系统扩展", module: id,
                       command: "systemextensionsctl list 2>/dev/null | grep -c 'activated'; true",
                       risk: .safe),
            AuditCheck(id: "m2.kext", name: "第三方 kext", module: id,
                       command: "kextstat 2>/dev/null | grep -cv com.apple; true",
                       risk: .safe),
            AuditCheck(id: "m2.launch_agents", name: "第三方 LaunchAgents", module: id,
                       command: "(ls ~/Library/LaunchAgents/ 2>/dev/null; ls /Library/LaunchAgents/ 2>/dev/null; ls /Library/LaunchDaemons/ 2>/dev/null) | wc -l | tr -d ' '",
                       risk: .safe),
            AuditCheck(id: "m2.xprotect", name: "XProtect 版本", module: id,
                       command: "/usr/libexec/PlistBuddy -c 'Print :Version' /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist 2>/dev/null || echo 'N/A'",
                       risk: .safe),
        ])

        // ── 网络安全（原 M3）──────────────────────────────────
        list.append(contentsOf: [
            AuditCheck(id: "m3.remote_login", name: "SSH 远程登录", module: id,
                       command: "launchctl print-disabled system/ 2>/dev/null | grep sshd | grep -o 'enabled\\|disabled' || echo 'unknown'",
                       expected: "disabled", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo systemsetup -setremotelogin off 2>/dev/null; true"),
            AuditCheck(id: "m3.remote_events", name: "远程 Apple Events", module: id,
                       command: "launchctl print-disabled system/ 2>/dev/null | grep eppc | grep -o 'enabled\\|disabled' || echo 'unknown'",
                       expected: "disabled", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo launchctl disable system/com.apple.eppc 2>/dev/null; true"),
            AuditCheck(id: "m3.airplay", name: "AirPlay 接收端", module: id,
                       description: "添加防护: 关闭 AirPlay 接收端，防止局域网设备投屏到本机\nSystem Settings → General → AirDrop & Handoff → AirPlay Receiver → Off\n取消防护: System Settings → General → AirDrop & Handoff → AirPlay Receiver → On",
                       command: "result=$(lsof -nP -iTCP:5000 -sTCP:LISTEN 2>/dev/null | grep -c ControlCe); echo \"${result:-0}\"",
                       expected: "0", risk: .safe),
            AuditCheck(id: "m3.smb", name: "SMB 共享点数", module: id,
                       description: "添加防护: 关闭所有 SMB 文件共享，防止局域网访问本机文件\n复制以下命令到终端执行:\nsudo launchctl disable system/com.apple.smbd && sudo launchctl stop com.apple.smbd\n或在 System Settings → General → Sharing → File Sharing 关闭\n取消防护:\nsudo launchctl enable system/com.apple.smbd && sudo launchctl start com.apple.smbd",
                       command: "sharing -l 2>/dev/null | grep -c 'name:'",
                       expected: "0", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo launchctl disable system/com.apple.smbd 2>/dev/null; sudo launchctl stop com.apple.smbd 2>/dev/null; true"),
            AuditCheck(id: "m3.listening_ports", name: "监听端口数", module: id,
                       command: "lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | tail -n +2 | wc -l | tr -d ' '",
                       risk: .safe),
            AuditCheck(id: "m3.interfaces", name: "活跃网络接口", module: id,
                       command: "ifconfig 2>/dev/null | grep -c 'flags=.*UP'",
                       risk: .safe),
            AuditCheck(id: "m3.dns", name: "DNS 服务器", module: id,
                       command: "scutil --dns 2>/dev/null | grep 'nameserver\\[0\\]' | head -3 | awk '{print $3}' | paste -sd ',' -",
                       risk: .safe),
            AuditCheck(id: "m3.surge_dns", name: "Surge Fake IP", module: id,
                       command: "scutil --dns 2>/dev/null | grep -c '198.18.0.2'",
                       risk: .safe),
            AuditCheck(id: "m3.ipv6", name: "IPv6 全局地址", module: id,
                       command: "ifconfig 2>/dev/null | grep inet6 | grep -v 'fe80\\|::1\\|%lo' | wc -l | tr -d ' '",
                       expected: "0", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo networksetup -setv6off \(wifiQ)",
                       networkRisk: true),
            AuditCheck(id: "m3.surge_dashboard", name: "Surge Dashboard", module: id,
                       command: "lsof -nP -iTCP:6170 -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print $9}'",
                       risk: .safe),
            AuditCheck(id: "m3.wifi_ipv6", name: "Wi-Fi IPv6", module: id,
                       command: "networksetup -getinfo \(wifiQ) 2>/dev/null | grep '^IPv6:' | awk '{print $2}'",
                       expected: "Off", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "sudo networksetup -setv6off \(wifiQ)",
                       networkRisk: true),
            AuditCheck(id: "m3.wifi_proxy", name: "Wi-Fi HTTP 代理", module: id,
                       command: "networksetup -getwebproxy \(wifiQ) 2>/dev/null | grep '^Enabled:' | awk '{print $2}'",
                       risk: .safe),
        ])

        // ── 网络内核调优（原 M8）──────────────────────────────
        let maxsockbufExpected = arch.isAppleSilicon ? "6291456" : "16777216"
        let maxsockbufDesc = arch.isAppleSilicon
            ? "Socket 缓冲区总上限（6MB，macOS arm64 内核硬限制）。\n限制单个 Socket 可使用的最大缓冲区。\n修复: sudo sysctl -w kern.ipc.maxsockbuf=6291456"
            : "Socket 缓冲区总上限（16MB，macOS x86_64 默认值）。\nIntel Mac 内核支持更大的缓冲区上限，保持默认即可。\n修复: sudo sysctl -w kern.ipc.maxsockbuf=16777216"
        list.append(AuditCheck(
            id: "m8.kern_ipc_maxsockbuf", name: "Socket 缓冲区上限", module: id,
            description: maxsockbufDesc,
            command: "sysctl -n kern.ipc.maxsockbuf 2>/dev/null || echo 'not set'",
            expected: maxsockbufExpected, risk: .safe,
            fixRisk: .high, fixCommand: "sudo sysctl -w kern.ipc.maxsockbuf=\(maxsockbufExpected)"))

        for p in sysctlParams.filter({ $0.versions.isEmpty || $0.versions.contains(version) }) {
            // net.inet6.ip6.* 在 macOS 上是只读 sysctl，无法通过 sysctl -w 修改
            // 正确做法：关闭接口 IPv6，RA/forwarding 自然停止
            let isReadOnlyIPv6 = p.param == "net.inet6.ip6.accept_rtadv" ||
                                  p.param == "net.inet6.ip6.forwarding"
            let fixCmd: String
            let fixDesc: String
            if isReadOnlyIPv6 {
                fixCmd = "networksetup -listallnetworkservices | grep -v '^An' | while IFS= read -r svc; do sudo networksetup -setv6off \"$svc\" 2>/dev/null; done && echo 'IPv6 disabled on all interfaces'"
                fixDesc = "此 sysctl 参数在 macOS 上为只读，无法通过 sysctl -w 修改。\n正确做法：关闭所有网络接口的 IPv6，路由通告/转发自然停止。\n修复命令已更正为 networksetup -setv6off。"
            } else {
                fixCmd = "sudo sysctl -w \(p.param)=\(p.expected)"
                fixDesc = ""
            }
            // 合并 SysctlDef 的通用 description 与平台特定的 fixDesc
            let mergedDesc: String
            if p.description.isEmpty {
                mergedDesc = fixDesc
            } else if fixDesc.isEmpty {
                mergedDesc = p.description
            } else {
                mergedDesc = "\(p.description)\n\n\(fixDesc)"
            }
            list.append(AuditCheck(
                id: "m8.\(p.param.replacingOccurrences(of: ".", with: "_"))",
                name: p.name, module: id,
                description: mergedDesc,
                command: "sysctl -n \(p.param) 2>/dev/null || echo 'not set'",
                expected: p.expected, risk: p.risk,
                fixRisk: isReadOnlyIPv6 ? .medium : .high,
                fixCommand: fixCmd,
                networkRisk: p.param.contains("inet6")
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
            fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add Label string com.server.sysctl' -c 'Add ProgramArguments array' -c 'Add ProgramArguments:0 string /usr/sbin/sysctl' -c 'Add ProgramArguments:1 string -w' -c 'Add ProgramArguments:2 string net.inet.tcp.sendspace=1048576' -c 'Add ProgramArguments:3 string net.inet.tcp.recvspace=1048576' -c 'Add ProgramArguments:4 string net.inet.tcp.autorcvbufmax=33554432' -c 'Add ProgramArguments:5 string net.inet.tcp.autosndbufmax=33554432' -c 'Add ProgramArguments:6 string net.inet.tcp.delayed_ack=0' -c 'Add ProgramArguments:7 string kern.ipc.maxsockbuf=6291456' -c 'Add ProgramArguments:8 string net.inet.tcp.win_scale_factor=8' -c 'Add RunAtLoad bool true' /Library/LaunchDaemons/com.server.sysctl.plist 2>/dev/null && sudo launchctl load /Library/LaunchDaemons/com.server.sysctl.plist 2>/dev/null; true"
        ))

        let dnsLeakIds: Set<String> = [
            "m3.dns", "m3.surge_dns", "m3.ipv6", "m3.wifi_ipv6", "m3.wifi_proxy", "m3.surge_dashboard",
        ]
        return list.map { var c = $0
            if dnsLeakIds.contains(c.id) || c.id.contains("inet6") { c.priority = .a0 }
            return c
        }
    }

    public func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
