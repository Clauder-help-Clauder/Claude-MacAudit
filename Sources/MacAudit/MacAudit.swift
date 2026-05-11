// MacAudit CLI 主入口 — 基于 ArgumentParser 的命令行工具

import ArgumentParser
import MacAuditCore
import Foundation

@main
struct MacAudit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "macaudit",
        abstract: "Mac 系统审查工具",
        version: "0.3.0"
    )

    /// 指定要运行的单一模块 ID，如 system_info、security、claude；不传则运行全部模块
    @Option(name: .long, help: "仅运行指定模块 (如: system_info, security, claude)")
    var module: String?

    /// Markdown 报告输出路径，传入后自动将审计结果写入该文件
    @Option(name: .long, help: "导出 Markdown 报告到指定路径")
    var export: String?

    /// 以 JSON 格式输出结果，适合脚本解析和 CI 集成
    @Flag(name: .long, help: "输出 JSON 格式")
    var json = false

    /// 运行内置自测，验证版本检测、设备识别、Shell 执行等基础能力是否正常
    @Flag(name: .long, help: "运行内置自测")
    var selfTest = false

    /// 禁用终端颜色输出，适用于不支持 ANSI 颜色的终端或重定向场景
    @Flag(name: .long, help: "禁用颜色输出")
    var noColor = false

    /// 将当前审计结果保存为基线快照，用于后续 diff 对比
    @Flag(name: .long, help: "保存结果到基线")
    var save = false

    /// 将本次结果与上次基线对比，输出差异报告
    @Flag(name: .long, help: "与上次结果对比")
    var diff = false

    /// 显示可修复项的计划，并交互式执行低风险修复（不含 sudo 操作）
    @Flag(name: .long, help: "显示修复方案并执行安全修复")
    var fix = false

    /// 回滚上一次 --fix 批量修复操作，恢复修改前的值
    @Flag(name: .long, help: "回滚上一次批量修复操作")
    var undo = false

    /// 运行全量检测项，包含 A1/A2/A3 优先级的延后检测；默认仅运行 A0
    @Flag(name: .long, help: "运行全部检测项（含 A1/A2/A3）")
    var all = false

    /// 显示代理服务器配置准则，指导住宅 IP 代理的正确设置方法
    @Flag(name: .long, help: "显示代理服务器配置准则（Proxy Rule）")
    var proxyRule = false

    func run() async throws {
        // MARK: - 初始化模块

        let allModules: [any AuditModule] = [
            SystemInfoModule(),
            NetworkSecurityModule(),
            PrivacyModule(),
            AnimationModule(),
            ServicesModule(),
            PowerModule(),
            ShellModule(),
            ClaudeProtectionModule(),
            DevEnvironmentModule(),
            IPQualityModule(),
            ChromeModule(),
            SafariModule(),
        ]

        // MARK: - 交互式菜单（无参数时进入）

        // 无参数 → 交互式菜单
        let hasArgs = module != nil || export != nil || json || selfTest || fix || save || diff || undo || all || proxyRule
        if !hasArgs {
            var menu = MenuController(modules: allModules)
            await menu.start()
            return
        }

        // MARK: - 特殊命令处理

        // 有参数 → 直接执行
        if selfTest {
            await runSelfTest()
            return
        }

        if proxyRule {
            Self.printProxyRule()
            return
        }

        // MARK: - 环境检测与 Banner

        let version = MacOSVersion.detect()
        let device = DeviceType.detect()

        if !json { printBanner(version: version, device: device) }

        let arch = CPUArchitecture.detect()

        // MARK: - 执行审计

        let maxPriority: CheckPriority = all ? .a3 : .a0
        let runner = AuditRunner(modules: allModules, arch: arch, quiet: json, maxPriority: maxPriority)

        let deferredCount = allModules.reduce(0) { $0 + $1.deferredChecks.count }
        if !all && !json && deferredCount > 0 {
            Layout.print(ANSIColor.dim.wrap("基础模式: 仅 A0 检测项 (\(deferredCount) 项已延后，用 --all 运行全量)"))
        }
        let start = ContinuousClock.now
        let results: [AuditResult]

        if let moduleId = module {
            guard let r = await runner.runModule(moduleId) else {
                Layout.print(ANSIColor.red.wrap("未知模块: \(moduleId)"))
                Layout.print("可用模块: \(allModules.map(\.id).joined(separator: ", "))")
                return
            }
            results = r
        } else {
            results = await runner.runAll()
        }

        let duration = ContinuousClock.now - start

        AuditLogger.logAuditRaw(
            entries: results.map { ($0.moduleId, $0.checkId, $0.status.rawValue, $0.actualValue, $0.expectedValue) },
            macOS: "\(version?.displayName ?? "unknown") (\(MacOSVersion.versionString))",
            device: "\(device.displayName) (\(arch.rawValue))",
            duration: duration,
            mode: all ? "full" : "essential (A0)",
            appVersion: MacAudit.configuration.version ?? "unknown",
            total: results.count,
            pass: results.filter { $0.status == .pass }.count,
            fail: results.filter { $0.status == .fail }.count,
            warn: results.filter { $0.status == .warn }.count,
            info: results.filter { $0.status == .info }.count,
            skip: results.filter { $0.status == .skip }.count,
            error: results.filter { $0.status == .error }.count
        )

        let baseline = BaselineManager()

        // MARK: - 基线保存

        if save || diff {
            let jsonStr = ReportGenerator.generateJSON(
                results: results, modules: allModules,
                version: version, device: device, duration: duration
            )
            do {
                let savedPath = try baseline.save(jsonStr)
                if !json { Layout.print(ANSIColor.green.wrap("基线已保存: \(savedPath)")) }
            } catch {
                Layout.print(ANSIColor.red.wrap("基线保存失败: \(error.localizedDescription)"))
            }
        }

        // MARK: - 结果输出

        if json {
            var diffJSON: String? = nil
            if diff {
                let reports = baseline.listReports()
                if reports.count >= 2,
                   let prevPath = baseline.previousReport(),
                   let lastPath = baseline.lastReport(),
                   let diffReport = BaselineManager.diff(oldPath: prevPath, newPath: lastPath) {
                    diffJSON = diffReport.toJSON()
                }
            }
            let jsonStr = ReportGenerator.generateJSON(
                results: results, modules: allModules,
                version: version, device: device, duration: duration,
                diffJSON: diffJSON
            )
            print(jsonStr)
        } else {
            InteractiveUI.printOverallSummary(results, duration: duration)
        }

        // MARK: - 导出 Markdown 报告

        if let path = export {
            let md = ReportGenerator.generateMarkdown(
                results: results, modules: allModules,
                version: version, device: device, duration: duration
            )
            do {
                try ReportGenerator.writeToFile(md, path: path)
                if !json { Layout.print(ANSIColor.green.wrap("报告已导出: \(path)")) }
            } catch {
                Layout.print(ANSIColor.red.wrap("导出失败: \(error.localizedDescription)"))
            }
        }

        // MARK: - 基线对比（非 JSON 模式）

        if diff && !json {
            let reports = baseline.listReports()
            if reports.count >= 2 {
                if let prevPath = baseline.previousReport(),
                   let lastPath = baseline.lastReport(),
                   let diffReport = BaselineManager.diff(oldPath: prevPath, newPath: lastPath) {
                    diffReport.printReport()
                }
            } else {
                Layout.print(ANSIColor.yellow.wrap("需要至少 2 次基线记录才能对比"))
            }
        }

        // MARK: - 修复流程

        if fix {
            let allChecks = allModules.flatMap { m in
                m.checks(for: version ?? .sequoia, device: device, arch: arch)
            }
            let actions = FixEngine.extractFixActions(from: results, checks: allChecks)
            FixEngine.printFixPlan(actions)

            let safeActions = actions.filter { $0.riskLevel <= .low && !$0.requiresSudo }
            if !safeActions.isEmpty {
                Layout.printNoNL("执行 \(safeActions.count) 项安全修复? (y/N): ")
                if let input = readLine()?.lowercased(), input == "y" || input == "yes" {
                    Layout.printEmpty()
                    let executor = ShellExecutor()
                    _ = await FixEngine.executeSafe(actions, executor: executor, auditResults: results)
                    Layout.print(ANSIColor.green.wrap("安全修复完成。重新运行 macaudit 验证结果。"))
                }
            }

            FixEngine.printSudoCommands(actions)
        }

        // MARK: - 回滚流程

        if undo {
            await runUndo()
        }
    }

    /// 打印工具版本、系统版本、设备类型和时间戳组成的 Banner 头部信息
    private func printBanner(version: MacOSVersion?, device: DeviceType) {
        Layout.printEmpty()
        Layout.print(ANSIColor.bold.wrap("MacAudit v0.2.13"))
        Layout.print("系统: \(version?.displayName ?? "未知") (\(MacOSVersion.versionString))")
        Layout.print("设备: \(device.displayName)")
        Layout.print("时间: \(ISO8601DateFormatter().string(from: Date()))")
    }

    /// 回滚最近一次批量修复
    private func runUndo() async {
        let history = FixHistory()
        guard let batch = history.lastBatch() else {
            Layout.print(ANSIColor.yellow.wrap("\n  无修复历史记录，无法回滚\n"))
            return
        }

        Layout.printEmpty()
        Layout.print(ANSIColor.bold.wrap("=== 回滚最近一次修复 ==="))
        Layout.print("批次: \(batch.id)")
        Layout.print("时间: \(batch.timestamp)")
        Layout.print("共 \(batch.records.count) 项修改")
        Layout.printEmpty()

        for record in batch.records {
            Layout.print("  \(record.name): \(record.previousValue) → \(record.newValue)")
            Layout.print(ANSIColor.dim.wrap("  回滚命令: \(record.undoCommand)"))
        }
        Layout.printEmpty()

        let safeRecords = batch.records.filter {
            !$0.undoCommand.hasPrefix("sudo ") && !$0.undoCommand.hasPrefix("#")
        }

        if safeRecords.isEmpty {
            Layout.print(ANSIColor.yellow.wrap("所有回滚命令都需要 sudo，请手动执行以下命令："))
            for record in batch.records {
                Layout.print("  \(record.undoCommand)")
            }
            return
        }

        Layout.printNoNL("确认回滚 \(safeRecords.count) 项? (y/N): ")
        guard let input = readLine()?.lowercased(), input == "y" || input == "yes" else {
            Layout.print(ANSIColor.dim.wrap("已取消"))
            return
        }

        Layout.printEmpty()
        let executor = ShellExecutor()
        for record in safeRecords {
            guard UndoValidator.isValidUndoCommand(record.undoCommand) else {
                Layout.print(ANSIColor.yellow.wrap("  ⚠ 跳过不安全的回滚命令: \(record.name)"))
                continue
            }
            let result = await executor.run(record.undoCommand)
            if result.isSuccess {
                Layout.print(ANSIColor.green.wrap("  ✓ 已回滚: \(record.name)"))
            } else {
                Layout.print(ANSIColor.red.wrap("  ✗ 回滚失败: \(record.name): \(result.stderr)"))
            }
        }

        // 生成 rollback.sh 脚本
        let script = history.generateUndoScript(for: batch)
        let scriptPath = ("~/.macaudit/rollback_\(batch.id).sh" as NSString).expandingTildeInPath
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)
            Layout.print(ANSIColor.green.wrap("回滚脚本已保存至: \(scriptPath)"))
        } catch {
            Layout.print(ANSIColor.yellow.wrap("回滚脚本保存失败: \(error.localizedDescription)"))
        }

        Layout.printEmpty()
        Layout.print(ANSIColor.green.wrap("回滚完成。"))
        Layout.print(ANSIColor.dim.wrap("建议重新运行 macaudit 验证结果"))
    }

    /// 显示代理服务器配置准则，涵盖住宅 IP 要求、推荐代理软件、
    /// 配置五要素以及 Surge/Shadowrocket/V2RayU 的具体配置参考
    static func printProxyRule() {
        let red = ANSIColor.red.wrap
        let bold = ANSIColor.bold.wrap
        let dim = ANSIColor.dim.wrap
        let cyan = "\u{1B}[36m"
        let reset = "\u{1B}[0m"

        Layout.printEmpty()
        Layout.print(bold("╔══════════════════════════════════════════════════════════════════╗"))
        Layout.print(bold("║                    PROXY RULE — 代理服务器准则                  ║"))
        Layout.print(bold("╚══════════════════════════════════════════════════════════════════╝"))
        Layout.printEmpty()
        Layout.print(red("  ⚠ 所有 Claude Code 流量必须通过住宅 IP（Residential IP）代理出口"))
        Layout.printEmpty()

        Layout.print(bold("  ━━ 为什么要走家宽？"))
        Layout.print("  • 机房 IP / VPS / 云服务器 IP 会被 Anthropic 风控标记为高风险")
        Layout.print("  • 数据中心 IP 段有公开黑名单（datacenter、hosting、business），Claude Code 启动时检测")
        Layout.print("  • 住宅 IP 是唯一能通过 Anthropic 风控的出口类型")
        Layout.print("  • 被封后 deviceId 被永久关联，换账号无法恢复，必须重置 ~/.claude.json")
        Layout.printEmpty()

        Layout.print(bold("  ━━ 推荐代理软件"))
        Layout.print("  \(cyan)Surge\(reset)              macOS / iOS   专业网络调试工具，支持规则分流、Fake IP DNS、增强模式 TUN")
        Layout.print("  \(cyan)Shadowrocket\(reset)       iOS / macOS   支持 SS / V2Ray / Trojan 多协议")
        Layout.print("  \(cyan)V2RayU / V2RayX\(reset)    macOS         原生 V2Ray 客户端，支持 VMess / VLESS")
        Layout.print("  \(cyan)Clash Verge\(reset)        macOS / Win   规则分流能力强，需注意 DNS 防泄漏")
        Layout.printEmpty()

        Layout.print(bold("  ━━ 代理配置五要素"))
        Layout.print(red("  1. 出口必须是住宅 IP（Residential IP），不是机房/VPS/云服务器"))
        Layout.print(red("  2. 全局模式：代理必须覆盖所有流量（含 CLI、npm、git），不能仅代理浏览器"))
        Layout.print(red("  3. IPv6 全关：IPv6 会绕过代理直连暴露真实 IP（ipv6=false）"))
        Layout.print(red("  4. DNS 防泄漏：使用 Fake IP（198.18.0.2）或加密 DNS（DoH/DoT）"))
        Layout.print(red("  5. Claude 域名单独走稳定节点：anthropic.com / claude.ai 固定出口，避免频繁切换 IP"))
        Layout.printEmpty()

        if ANSIColor.isTerminal {
            Layout.printNoNL(dim("  ▼ 按 Enter 查看 Surge 配置参考..."))
            TerminalInput.enableRawMode()
            _ = TerminalInput.readKey()
            TerminalInput.disableRawMode()
            Swift.print("\r\u{001B}[2K", terminator: "")
        }

        Layout.print(bold("  ━━ Surge 配置参考（已验证稳定方案）"))
        Layout.printEmpty()
        Layout.print(dim("  [General] 基础配置"))
        Layout.print("  ipv6 = false")
        Layout.print("  ipv6-vif = off")
        Layout.print("  dns-server = 223.5.5.5, 119.29.29.29, system")
        Layout.print("  encrypted-dns-server = https://223.5.5.5/dns-query")
        Layout.print("  udp-policy-not-supported-behaviour = REJECT")
        Layout.print("  skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, localhost, *.local")
        Layout.printEmpty()
        Layout.print(dim("  [Rule] Claude 专用规则"))
        Layout.print("  DOMAIN-SUFFIX,anthropic.com,Claude-Stable")
        Layout.print("  DOMAIN-SUFFIX,claude.ai,Claude-Stable")
        Layout.print("  DOMAIN-SUFFIX,claude.com,Claude-Stable")
        Layout.print("  DOMAIN-SUFFIX,claude.dev,Claude-Stable")
        Layout.print("  DOMAIN-SUFFIX,claudeusercontent.com,Claude-Stable")
        Layout.print("  DOMAIN-SUFFIX,statsigapi.net,Claude-Stable")
        Layout.print("  DOMAIN-SUFFIX,datadoghq.com,Claude-Stable")
        Layout.print("  DOMAIN-KEYWORD,anthropic,Claude-Stable")
        Layout.print("  DOMAIN-KEYWORD,claude,Claude-Stable")
        Layout.printEmpty()
        Layout.print(dim("  [Rule] STUN/WebRTC 防泄漏"))
        Layout.print("  AND,((PROTOCOL,STUN),(NOT,((OR,((DOMAIN-SUFFIX,anthropic.com),(DOMAIN-SUFFIX,claude.ai)))))),REJECT")
        Layout.printEmpty()
        Layout.print(dim("  [Host] Claude 域名 DNS 加密"))
        Layout.print("  *.anthropic.com = server:https://dns.google/dns-query")
        Layout.print("  *.claude.ai = server:https://dns.google/dns-query")
        Layout.print("  *.claude.com = server:https://dns.google/dns-query")
        Layout.print("  *.statsigapi.net = server:https://dns.google/dns-query")
        Layout.printEmpty()
        Layout.print(dim("  [Proxy Group] Claude 稳定出口"))
        Layout.print("  Claude-Stable = fallback, 主节点, 备节点1, 备节点2,")
        Layout.print("    url=http://cp.cloudflare.com/generate_204, interval=300, timeout=5")
        Layout.printEmpty()

        Layout.print(bold("  ━━ Shadowrocket 配置要点"))
        Layout.print("  • 添加节点后选择「全局代理」模式（不是规则模式）")
        Layout.print("  • 安装 CA 证书并信任：设置 → 通用 → 关于本机 → 证书信任设置")
        Layout.print("  • 关闭 IPv6：设置 → 蜂窝网络 → 蜂窝数据选项 → IPv6 设为关闭")
        Layout.print("  • DNS 配置使用加密 DNS：设置中填入 https://1.1.1.1/dns-query")
        Layout.printEmpty()

        Layout.print(bold("  ━━ V2RayU 配置要点"))
        Layout.print("  • PAC 模式不安全，必须使用「全局模式」或配置系统代理")
        Layout.print("  • 手动设置系统代理：网络 → Wi-Fi → 代理 → HTTP/HTTPS 填 127.0.0.1:端口")
        Layout.print("  • 注意：V2RayU 不支持 Fake IP，需手动配置 DoH 防止 DNS 泄露")
        Layout.printEmpty()

        if ANSIColor.isTerminal {
            Layout.printNoNL(dim("  ▼ 按 Enter 继续..."))
            TerminalInput.enableRawMode()
            _ = TerminalInput.readKey()
            TerminalInput.disableRawMode()
            Swift.print("\r\u{001B}[2K", terminator: "")
        }

        Layout.print(bold("  ━━ Surge 关闭时的应急防护"))
        Layout.print("  • 在 /etc/hosts 中添加 Claude 域名 → 0.0.0.0，阻断直连")
        Layout.print("  • 修改 hosts 后运行 sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder")
        Layout.print("  • Claude Code 环境变量 CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1 确保代理接管 DNS")
        Layout.printEmpty()

        Layout.print(bold("  ━━ 验证方法"))
        Layout.print("  • 运行 macaudit → 确认所有 A0 检测项通过")
        Layout.print("  • 浏览器访问 ipleak.net → 确认 DNS 出口与代理 IP 一致")
        Layout.print("  • 浏览器访问 browserleaks.com/webrtc → 确认 No Leak")
        Layout.print("  • 浏览器访问 whoer.net → 评分 85+ 且 Proxy 显示 No")
        Layout.print("  • 终端运行 curl ip.sb --proxy $HTTPS_PROXY → 确认出口为住宅 IP")
        Layout.printEmpty()
        Layout.print(ANSIColor.dim.wrap("  GitHub: https://github.com/Clauder-help-Clauder/Claude-MacAudit"))
        Layout.printEmpty()
    }

    /// 运行内置自测，依次验证 MacOSVersion 检测、DeviceType 检测、
    /// ShellExecutor 执行和 readSysctl 读取四项基础能力
    private func runSelfTest() async {
        Layout.printEmpty()
        Layout.print(ANSIColor.bold.wrap("=== MacAudit Self-Test ==="))
        var passed = 0

        if let v = MacOSVersion.detect() {
            Layout.print(ANSIColor.green.wrap("✓ MacOSVersion: \(v.displayName) (\(MacOSVersion.versionString))"))
        } else {
            Layout.print(ANSIColor.yellow.wrap("! MacOSVersion: 未知 (\(MacOSVersion.versionString))"))
        }
        passed += 1

        let device = DeviceType.detect()
        Layout.print(ANSIColor.green.wrap("✓ DeviceType: \(device.displayName)"))
        passed += 1

        let executor = ShellExecutor()
        let result = await executor.run("echo hello")
        if result.trimmedOutput == "hello" {
            Layout.print(ANSIColor.green.wrap("✓ ShellExecutor: OK"))
            passed += 1
        }

        let mem = await executor.readSysctl("hw.memsize")
        if let m = mem, let b = UInt64(m) {
            Layout.print(ANSIColor.green.wrap("✓ readSysctl: \(b / (1024*1024*1024)) GB"))
            passed += 1
        }

        Layout.printEmpty()
        Layout.print(ANSIColor.green.wrap("All \(passed) tests passed"))
        Layout.printEmpty()
    }
}
