// MenuController.swift
// 菜单控制器 — TUI 交互式主菜单的入口和路由，
// 整合系统审查、单模块审查、AI 服务审查、IP 质量检测、
// 系统深度调优、AI 服务调优、服务管理、开发环境安装助手、报告导出等全部功能入口。

import Foundation
import MacAuditCore

/// 首页系统信息快照
struct SystemSnapshot: Sendable {
    /// 设备型号（如 MacBookPro17,1）
    let model: String
    /// 芯片信息（如 Apple M1 Pro）
    let chip: String
    /// 内存容量（如 16 GB）
    let memory: String
    /// 磁盘可用/总量（如 200 GB / 500 GB）
    let disk: String
    /// 主机名
    let hostname: String

    /// 并发采集系统信息快照
    /// - Parameter executor: Shell 执行器
    /// - Returns: 采集完成的 SystemSnapshot
    static func collect(executor: ShellExecutor) async -> SystemSnapshot {
        async let model = executor.run("sysctl -n hw.model 2>/dev/null")
        async let chip = executor.run("sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m")
        async let mem = executor.run("echo \"$(( $(sysctl -n hw.memsize) / 1073741824 )) GB\"")
        async let disk = executor.run("df -h / | tail -1 | awk '{print $4 \" / \" $2}'")
        async let host = executor.run("scutil --get ComputerName 2>/dev/null || hostname -s")

        return SystemSnapshot(
            model: await model.trimmedOutput,
            chip: await chip.trimmedOutput,
            memory: await mem.trimmedOutput,
            disk: await disk.trimmedOutput,
            hostname: await host.trimmedOutput
        )
    }
}

/// 菜单控制器，管理 TUI 主菜单循环和各功能模块的路由
struct MenuController: Sendable {
    /// 全部模块（含 claude，供调优使用）
    let modules: [any AuditModule]
    /// 系统全面审查模块列表（含 ip_quality，不含 claude）
    let fullAuditModules: [any AuditModule]
    /// 单模块审查模块列表（不含 claude/ip_quality）
    let auditModules: [any AuditModule]
    /// 当前 macOS 版本
    let version: MacOSVersion?
    /// 设备类型
    let device: DeviceType
    /// CPU 架构
    let arch: CPUArchitecture
    /// Shell 命令执行器
    let executor: ShellExecutor
    /// 缓存的系统信息快照
    private var sysInfo: SystemSnapshot?
    /// 最近一次审查的结果
    private var lastResults: [AuditResult] = []
    /// 最近一次审查的耗时
    private var lastDuration: Duration = .zero
    /// 是否已完成过完整审查（用于控制报告导出）
    private var fullAuditDone = false

    /// 初始化菜单控制器
    /// - Parameters:
    ///   - modules: 全部审计模块列表
    ///   - executor: Shell 执行器
    init(modules: [any AuditModule], executor: ShellExecutor = ShellExecutor()) {
        self.modules = modules
        self.fullAuditModules = modules.filter { $0.id != "claude" }
        self.auditModules = modules.filter { $0.id != "claude" && $0.id != "ip_quality" }
        self.version = MacOSVersion.detect()
        self.device = DeviceType.detect()
        self.arch = .detect()
        self.executor = executor
    }

    // MARK: - 主菜单

    /// 启动主菜单循环，显示横幅和功能选项
    mutating func start() async {
        sysInfo = await SystemSnapshot.collect(executor: executor)

        // MARK: - CLT 前置检查

        let cltCheck = await executor.run("xcode-select -p 2>/dev/null")
        if !cltCheck.isSuccess || cltCheck.trimmedOutput.isEmpty {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.red.wrap("  ✗ 未检测到 Xcode Command Line Tools"))
            Layout.print(ANSIColor.yellow.wrap("  部分检测项（clang、swift 编译、brew 依赖）需要 CLT 才能正常运行。"))
            Layout.print(ANSIColor.dim.wrap("  安装命令: xcode-select --install"))
            Layout.printEmpty()
            Layout.printNoNL("  按 Return 继续，或 Ctrl+C 退出后安装 CLT...")
            _ = readLine()
        }

        // MARK: - 菜单循环

        while true {
            MenuUI.clearScreen()

            if !lastResults.isEmpty {
                let pass = lastResults.filter { $0.status == .pass }.count
                let fail = lastResults.filter { $0.status == .fail }.count
                Layout.print(ANSIColor.dim.wrap("上次审查: \(lastResults.count) 项 | \(pass) 通过 | \(fail) 失败"))
                Layout.printEmpty()
            }

            let mainItems: [MenuItem] = [
                MenuItem("系统全面审查", "运行全部 11 个模块", .green),
                MenuItem("单模块审查", "选择一个模块运行", .green),
                MenuItem("AI服务效率审查", "Claude/Gemini/GPT/Grok", .green),
                MenuItem("IP 质量检测", "IP 地址质量(!请打开全局代理)", .green),
                MenuItem("系统深度调优", "分模块查看和执行/恢复调优", .yellow),
                MenuItem("AI服务深度调优", "Claude/Gemini/GPT/Grok 调优", .yellow),
                MenuItem("服务管理", "交互式管理 launchd 服务", .yellow),
                MenuItem("开发环境安装助手", "查看所有开发工具官方安装命令", .yellow),
                MenuItem("Proxy Rules", "住宅 IP 代理配置准则（防封必读）", .red),
                MenuItem("自测", "验证工具运行状态", .dim),
            ]

            let mainGroups: [(Int, String)] = [
                (0, "审查"),
                (4, "调优"),
                (8, "防护"),
                (9, "系统"),
            ]

            let choice = MenuUI.interactiveSelect(
                items: mainItems, groups: mainGroups, exitLabel: "退出"
            )

            switch choice {
            case 0:
                Layout.print(ANSIColor.dim.wrap("再见！"))
                return
            case 1: await runFullAudit()
            case 2: await runSingleModule()
            case 3: await runClaudeAudit()
            case 4: await runIPQuality()
            case 5: await systemOptimize()
            case 6: await aiServiceOptimize()
            case 7: await manageServices()
            case 8: showDevInstaller()
            case 9:
                MacAudit.printProxyRule()
                Layout.printNoNL(ANSIColor.dim.wrap("\n按 Return 返回菜单..."))
                _ = readLine()
            case 10: await runSelfTest()
            default: break
            }
        }
    }

    // MARK: - 审查

    /// 运行系统全面审查（全部模块，交互模式）
    private mutating func runFullAudit() async {
        let runner = AuditRunner(
            modules: fullAuditModules, version: version, device: device,
            executor: executor, interactive: true
        )
        let start = ContinuousClock.now
        lastResults = await runner.runAll()
        lastDuration = ContinuousClock.now - start
        fullAuditDone = true

        MenuUI.clearScreen()
        InteractiveUI.printOverallSummary(lastResults, duration: lastDuration)
        InteractiveUI.printFailureSummary(lastResults)
        MenuUI.waitForReturn()
    }

    /// 将模块 id 转换为菜单中显示的友好名称
    /// - Parameter id: 模块 ID
    /// - Returns: 友好名称字符串
    private func moduleTag(_ id: String) -> String {
        switch id {
        case "claude": return "Claude/Gemini/GPT/Grok"
        default:       return id
        }
    }

    /// 单模块审查子菜单，选择一个模块并运行
    private mutating func runSingleModule() async {
        while true {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("选择要审查的模块:"))
            Layout.printEmpty()
            let moduleItems = auditModules.map { MenuItem($0.name, "(\(moduleTag($0.id)))", .green) }
            let choice = MenuUI.interactiveSelect(items: moduleItems, exitLabel: "返回主菜单")
            guard choice > 0 else { return }

            MenuUI.clearScreen()
            let runner = AuditRunner(modules: auditModules, version: version, device: device, executor: executor)
            let start = ContinuousClock.now
            if let results = await runner.runModule(auditModules[choice - 1].id) {
                lastResults = results
                lastDuration = ContinuousClock.now - start
                InteractiveUI.printOverallSummary(results, duration: lastDuration)
                InteractiveUI.printFailureSummary(results)
            }
            MenuUI.waitForReturn()
        }
    }

    /// 运行 AI 服务效率审查（Claude/Gemini/GPT/Grok 模块）
    private mutating func runClaudeAudit() async {
        MenuUI.clearScreen()
        let runner = AuditRunner(modules: modules, version: version, device: device, executor: executor)
        let start = ContinuousClock.now
        if let results = await runner.runModule("claude") {
            lastResults = results
            lastDuration = ContinuousClock.now - start
            InteractiveUI.printOverallSummary(results, duration: lastDuration)
            InteractiveUI.printFailureSummary(results)
        }
        MenuUI.waitForReturn()
    }

    /// 运行 IP 质量检测模块，审查完毕后附加外部检查建议
    private mutating func runIPQuality() async {
        MenuUI.clearScreen()
        let runner = AuditRunner(modules: modules, version: version, device: device, executor: executor)
        let start = ContinuousClock.now
        if let results = await runner.runModule("ip_quality") {
            lastResults = results
            lastDuration = ContinuousClock.now - start
            InteractiveUI.printOverallSummary(results, duration: lastDuration)
            InteractiveUI.printFailureSummary(results)
        }
        printIPExternalChecks()
        MenuUI.waitForReturn()
    }

    /// 打印外部 IP 检查建议（ipleak.net、browserleaks 等在线工具的使用指引）
    private func printIPExternalChecks() {
        Layout.printEmpty()
        Layout.printLine()
        Layout.print(ANSIColor.bold.wrap("【外部附加检查】(!请打开全局代理)"))
        Layout.printLine()
        Layout.printEmpty()

        let checks: [(String, String, [(String, String)])] = [
            ("1. ipleak.net", "检查 DNS 实际出口",
             [("操作", "打开 ipleak.net"),
              ("检查项", "DNS 实际请求来自哪个国家 — 必须与代理 IP 所在地一致")]),

            ("2. browserleaks.com/webrtc", "检查 WebRTC 泄漏",
             [("WebRTC Leak Test", "显示 No Leak 才合格"),
              ("Public IP Address", "必须是代理 IP，不能是真实 IP"),
              ("Local IP Address", "显示空（-）才合格")]),

            ("3. browserleaks.com/javascript", "检查时区与语言",
             [("Timezone", "必须与代理 IP 所在地一致（如 America/Los_Angeles）"),
              ("Language", "必须是 en-US")]),

            ("4. whoer.net", "IP 地址综合评分",
             [("评分标准", "85分以上合格，90分以上优秀"),
              ("Proxy", "显示 No（未被识别为代理）"),
              ("Anonymizer", "显示 No"),
              ("Blacklist", "显示 No（IP 不在黑名单）")]),
        ]

        for (title, subtitle, items) in checks {
            Layout.print(ANSIColor.blue.wrap(title) + "  " + ANSIColor.dim.wrap(subtitle))
            for (key, val) in items {
                Layout.print("  \(ANSIColor.dim.wrap("•")) \(ANSIColor.bold.wrap(key)): \(val)")
            }
            Layout.printEmpty()
        }
    }

    // MARK: - 系统深度调优

    /// 系统深度调优子菜单，选择模块后自动检测并展示可调优项
    private mutating func systemOptimize() async {
        let effectiveVersion = version ?? .sequoia

        // claude 模块独立入口，此处只保留系统模块
        let optimizableModules = modules.filter { m in
            m.id != "claude" &&
            m.checks(for: effectiveVersion, device: device, arch: arch).contains { $0.fixCommand != nil }
        }

        while true {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("系统深度调优"))
            Layout.print(ANSIColor.dim.wrap("选择模块 → 自动检测 → 选择是否调优"))
            Layout.printEmpty()

            let items = optimizableModules.map { MenuItem($0.name, "(\(moduleTag($0.id)))", .yellow) }

            let choice = MenuUI.interactiveSelect(items: items, exitLabel: "返回主菜单")
            guard choice > 0 else { return }

            let selected = optimizableModules[choice - 1]

            // 自动跑该模块检测
            MenuUI.clearScreen()
            Layout.print(ANSIColor.dim.wrap("正在检测 \(selected.name)..."))
            let runner = AuditRunner(modules: [selected], version: version, device: device, executor: executor)
            guard let results = await runner.runModule(selected.id) else { continue }

            let failedResults = results.filter { $0.status == .fail }
            let checks = selected.checks(for: effectiveVersion, device: device, arch: arch)
            let actions = FixEngine.extractFixActions(from: failedResults, checks: checks)

            // 无 fixCommand 但有手动操作说明的失败项
            let checkMap = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
            let manualItems: [(name: String, description: String)] = failedResults.compactMap { r in
                guard let check = checkMap[r.checkId],
                      check.fixCommand == nil,
                      !check.description.isEmpty else { return nil }
                return (check.name, check.description)
            }

            // 展示检测结果
            MenuUI.waitForReturn()
            MenuUI.clearScreen()
            InteractiveUI.printOverallSummary(results, duration: .zero)

            if actions.isEmpty && manualItems.isEmpty {
                if failedResults.isEmpty {
                    Layout.print(ANSIColor.green.wrap("✓ \(selected.name) 所有项已通过，无需调优"))
                } else {
                    Layout.print(ANSIColor.dim.wrap("有 \(failedResults.count) 项未通过，但均需手动操作"))
                    InteractiveUI.printFailureSummary(results)
                }
                MenuUI.waitForReturn()
                continue
            }

            // 有可修复项或手动提示 → 进入模块优化
            await moduleOptimize(module: selected, actions: actions, manualItems: manualItems)
        }
    }

    // MARK: - AI服务深度调优

    /// AI 服务深度调优，直接检测 Claude 模块并展示调优方案
    private mutating func aiServiceOptimize() async {
        let effectiveVersion = version ?? .sequoia

        guard let claudeModule = modules.first(where: { $0.id == "claude" }) else { return }

        // 直接检测 claude 模块，跳过二级菜单
        MenuUI.clearScreen()
        Layout.print(ANSIColor.dim.wrap("正在检测 \(claudeModule.name)..."))
        let runner = AuditRunner(modules: [claudeModule], version: version, device: device, executor: executor)
        guard let results = await runner.runModule(claudeModule.id) else { return }

        let failedResults = results.filter { $0.status == .fail }
        let checks = claudeModule.checks(for: effectiveVersion, device: device, arch: arch)
        let actions = FixEngine.extractFixActions(from: failedResults, checks: checks)

        let checkMap = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
        let manualItems: [(name: String, description: String)] = failedResults.compactMap { r in
            guard let check = checkMap[r.checkId],
                  check.fixCommand == nil,
                  !check.description.isEmpty else { return nil }
            return (check.name, check.description)
        }

        MenuUI.waitForReturn()
        MenuUI.clearScreen()
        InteractiveUI.printOverallSummary(results, duration: .zero)

        if actions.isEmpty && manualItems.isEmpty {
            if failedResults.isEmpty {
                Layout.print(ANSIColor.green.wrap("✓ \(claudeModule.name) 所有项已通过，无需调优"))
            } else {
                Layout.print(ANSIColor.dim.wrap("有 \(failedResults.count) 项未通过，但均需手动操作"))
                InteractiveUI.printFailureSummary(results)
            }
            MenuUI.waitForReturn()
            return
        }

        await moduleOptimize(module: claudeModule, actions: actions, manualItems: manualItems)
    }

    /// 单模块优化详情子菜单（自动调优 / sudo 命令 / 全部步骤 / 调优复原）
    /// - Parameters:
    ///   - module: 当前模块
    ///   - actions: 可执行的修复操作列表
    ///   - manualItems: 需手动操作的项列表
    private func moduleOptimize(
        module: any AuditModule,
        actions: [FixAction],
        manualItems: [(name: String, description: String)] = []
    ) async {
        let safeActions = actions.filter { $0.riskLevel <= .low && !$0.requiresSudo }
        let sudoActions = actions.filter { $0.requiresSudo || $0.riskLevel >= .high }
        let mediumActions = actions.filter { $0.riskLevel == .medium && !$0.requiresSudo }

        while true {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("\(module.name) — 调优方案"))
            Layout.printLine()
            Layout.printEmpty()

            // 显示概要
            if !safeActions.isEmpty {
                Layout.print(ANSIColor.green.wrap("基础调优: \(safeActions.count) 项（安全，可一键执行）"))
            }
            if !mediumActions.isEmpty {
                Layout.print(ANSIColor.yellow.wrap("中级调优: \(mediumActions.count) 项（需逐条确认）"))
            }
            if !sudoActions.isEmpty {
                Layout.print(ANSIColor.orange.wrap("深度调优: \(sudoActions.count) 项（需 sudo，手动执行）"))
            }
            if !manualItems.isEmpty {
                Layout.print(ANSIColor.blue.wrap("手动操作: \(manualItems.count) 项（需在系统设置中完成）"))
            }
            Layout.printEmpty()

            var menuItems: [MenuItem] = []
            if !safeActions.isEmpty {
                menuItems.append(MenuItem("自动调优", "自动执行 \(safeActions.count) 项，安全可撤销", .green))
            }
            // sudo 命令超过 1 个才单独列出，否则并入"全部调优步骤"
            if sudoActions.count > 1 {
                menuItems.append(MenuItem("需要 sudo 的命令", "需要 root 权限，复制到终端执行 [可复制]", .orange))
            }
            menuItems.append(MenuItem("全部调优步骤", "所有命令 + 手动设置指引 [部分需手动设置]", .dim))
            menuItems.append(MenuItem("调优复原", "撤销本模块已执行的调优操作", .yellow))

            let choice = MenuUI.interactiveSelect(items: menuItems, exitLabel: "返回上级")
            guard choice > 0 else { return }

            let label = menuItems[choice - 1].label
            if label.contains("自动调优") {
                await executeBasicOptimize(safeActions)
            } else if label.contains("sudo") {
                showDeepOptimize(sudoActions)
            } else if label.contains("全部调优步骤") {
                showAllSteps(actions: actions, manualItems: manualItems)
            } else if label.contains("调优复原") {
                await systemRestore()
            }
        }
    }

    /// 执行基础优化（safe/low 级别），用户确认后批量执行
    /// - Parameter actions: 已过滤的安全操作列表
    private func executeBasicOptimize(_ actions: [FixAction]) async {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("一键基础调优"))
        Layout.printLine()
        Layout.printEmpty()

        for action in actions {
            Layout.print("\(ANSIColor.dim.wrap("•")) \(action.name)")
        }

        Layout.printEmpty()
        Layout.printNoNL("确认执行 \(actions.count) 项基础调优? (y/N): ")
        guard let input = readLine()?.lowercased(), input == "y" || input == "yes" else {
            Layout.print(ANSIColor.yellow.wrap("已取消"))
            MenuUI.waitForReturn()
            return
        }

        Layout.printEmpty()
        _ = await FixEngine.executeSafe(
            actions.map { $0 }, // 已经过滤过
            executor: executor,
            auditResults: lastResults
        )
        Layout.printEmpty()
        Layout.print(ANSIColor.green.wrap("✓ 基础调优完成。建议重新运行系统全面审查验证。"))
        MenuUI.waitForReturn()
    }

    /// 显示全部调优步骤：可执行命令 + 手动操作项合并一屏展示
    /// - Parameters:
    ///   - actions: 有修复命令的操作列表
    ///   - manualItems: 需手动设置的项列表
    private func showAllSteps(actions: [FixAction], manualItems: [(name: String, description: String)]) {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("全部调优步骤"))
        Layout.printLine()
        Layout.printEmpty()

        // MARK: - 第一部分：有命令的优化项

        if !actions.isEmpty {
            Layout.print(ANSIColor.green.wrap("── 可执行命令 ──────────────────"))
            Layout.printEmpty()
            for action in actions {
                let tags = [
                    action.riskLevel.color.wrap("(\(action.riskLevel.label))"),
                    action.requiresSudo ? ANSIColor.orange.wrap("(SUDO)") : "",
                    action.networkRisk  ? ANSIColor.red.wrap("(网络风险)") : "",
                ].filter { !$0.isEmpty }.joined(separator: " ")
                Swift.print(ANSIColor.dim.wrap("# \(action.name)  \(tags)"))
                Swift.print(action.command)
                Swift.print("")
            }
        }

        // MARK: - 第二部分：手动操作项

        if !manualItems.isEmpty {
            Layout.print(ANSIColor.blue.wrap("── 需手动设置 ──────────────────"))
            Layout.printEmpty()
            for (i, item) in manualItems.enumerated() {
                Swift.print(ANSIColor.bold.wrap("\(i + 1). \(item.name)"))
                for line in item.description.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    let hasChinese = trimmed.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
                    let shellPrefixes = ["echo ", "export ", "unset ", "sudo ", "source ",
                                         "cat ", "sed ", "grep ", "networksetup", "launchctl",
                                         "defaults ", "pmset", "{ ", "}", "&&", "jq ", "mkdir",
                                         "tee ", "rm ", "cp ", "mv "]
                    let isShellCmd = shellPrefixes.contains { trimmed.hasPrefix($0) }
                                   || trimmed == "}" || trimmed == "{"
                    let isNote = !isShellCmd && (hasChinese || trimmed.hasPrefix("(") || trimmed.hasPrefix("#"))
                    if isNote {
                        Swift.print(ANSIColor.dim.wrap("   \(trimmed)"))
                    } else {
                        Swift.print("   \(trimmed)")
                    }
                }
                Swift.print("")
            }
        }

        MenuUI.waitForReturn()
    }

    /// 显示手动操作步骤（支持"添加防护/取消防护"分屏模式和普通模式）
    /// - Parameter items: 手动操作项列表
    private func showManualSteps(_ items: [(name: String, description: String)]) {
        // 判断是否含"添加/取消防护"格式（AI服务效率调优模块）
        let hasProtectionFormat = items.contains { $0.description.contains("添加防护:") }

        if hasProtectionFormat {
            // 分两屏：先"添加防护"，再"取消防护"
            for mode in ["添加防护", "取消防护"] {
                MenuUI.clearScreen()
                let titleColor: ANSIColor = mode == "添加防护" ? .green : .yellow
                Layout.print(ANSIColor.bold.wrap("手动操作 — \(mode)"))
                Layout.printLine()
                Layout.printEmpty()
                Layout.print(titleColor.wrap(mode == "添加防护"
                    ? "以下命令可启用 AI 服务效率调优（在终端执行）："
                    : "以下命令可撤销 AI 服务效率调优（在终端执行）："))
                Layout.printEmpty()

                for (i, item) in items.enumerated() {
                    // 从 description 中提取对应 mode 的行
                    let lines = item.description.components(separatedBy: "\n")
                    let prefix = "\(mode):"
                    var modeLines: [String] = []
                    var collecting = false
                    for line in lines {
                        if line.hasPrefix(prefix) {
                            collecting = true
                            let rest = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                            if !rest.isEmpty { modeLines.append(rest) }
                        } else if collecting {
                            if line.hasPrefix("添加防护:") || line.hasPrefix("取消防护:") {
                                break
                            }
                            if !line.isEmpty { modeLines.append(line) }
                        }
                    }
                    if modeLines.isEmpty { continue }
                    Swift.print(ANSIColor.dim.wrap("# \(item.name)"))
                    for line in modeLines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        let hasChinese = trimmed.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
                        // shell 命令关键词开头 → 始终当命令行（即使含中文）
                        let shellPrefixes = ["echo ", "export ", "unset ", "sudo ", "source ",
                                             "cat ", "sed ", "grep ", "find ", "networksetup",
                                             "launchctl", "defaults ", "pmset", "{ ", "}", "&&",
                                             "jq ", "mkdir", "tee ", "rm ", "cp ", "mv "]
                        let isShellCmd = shellPrefixes.contains { trimmed.hasPrefix($0) }
                                      || trimmed == "}" || trimmed == "{" || trimmed.hasPrefix("} ")
                        let isNote = !isShellCmd && (hasChinese || trimmed.hasPrefix("(") || trimmed.isEmpty)
                        if isNote {
                            if !trimmed.isEmpty {
                                Swift.print(ANSIColor.dim.wrap("# \(trimmed)"))
                            }
                        } else {
                            Swift.print(trimmed)
                        }
                    }
                    Swift.print("")
                    _ = i
                }
                MenuUI.waitForReturn()
            }
        } else {
            // 普通手动步骤（系统设置路径等）
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("手动操作步骤"))
            Layout.printLine()
            Layout.printEmpty()
            Layout.print(ANSIColor.blue.wrap("以下项目需要在系统设置中手动完成："))
            Layout.printEmpty()

            for (i, item) in items.enumerated() {
                Swift.print("\(i + 1). \(item.name)")
                for line in item.description.components(separatedBy: "\n") {
                    Swift.print(ANSIColor.dim.wrap("   \(line)"))
                }
                Swift.print("")
            }
            MenuUI.waitForReturn()
        }
    }

    /// 显示深度调优命令（sudo 命令，供用户复制到另一个终端执行）
    /// - Parameter actions: 修复操作列表
    private func showDeepOptimize(_ actions: [FixAction]) {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("深度调优命令"))
        Layout.printLine()
        Layout.printEmpty()
        Layout.print(ANSIColor.red.wrap("⚠ 以下命令需要在另一个终端窗口中手动执行"))
        Layout.print(ANSIColor.red.wrap("⚠ 调优有风险，请确认理解命令含义后再执行"))
        Layout.printEmpty()

        for action in actions {
            let tags = [
                action.riskLevel.color.wrap("[\(action.riskLevel.label)]"),
                action.requiresSudo ? ANSIColor.orange.wrap("(SUDO)") : "",
                action.networkRisk  ? ANSIColor.red.wrap("(网络风险)") : "",
            ].filter { !$0.isEmpty }.joined(separator: " ")
            // 注释行：名称 + 风险标签（# 开头，shell 忽略）
            Swift.print(ANSIColor.dim.wrap("# \(action.name)  \(tags)"))
            if action.networkRisk {
                Swift.print(ANSIColor.dim.wrap("# ⚠ 此命令可能导致网络断开"))
            }
            // 命令行：纯文本，方便整行复制
            Swift.print(action.command)
            Swift.print("")
        }
        MenuUI.waitForReturn()
    }

    /// 显示所有优化项详情（命令 + 风险标签）
    /// - Parameter actions: 修复操作列表
    private func showAllActions(_ actions: [FixAction]) {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("全部调优项"))
        Layout.printLine()
        Layout.printEmpty()

        for action in actions {
            let tags = [
                action.riskLevel.color.wrap("[\(action.riskLevel.label)]"),
                action.requiresSudo ? ANSIColor.orange.wrap("(SUDO)") : "",
                action.networkRisk  ? ANSIColor.red.wrap("(网络风险)") : "",
            ].filter { !$0.isEmpty }.joined(separator: " ")
            // 注释行：名称 + 风险标签（灰色，# 开头）
            Swift.print(ANSIColor.dim.wrap("# \(action.name)  \(tags)"))
            // 命令行：纯文本
            Swift.print(action.command)
            Swift.print("")
        }
        MenuUI.waitForReturn()
    }

    // MARK: - 系统调优复原

    /// 调优复原子菜单，展示历史批次供用户选择回滚
    private func systemRestore() async {
        let history = FixHistory()
        let batches = history.loadAll()

        if batches.isEmpty {
            MenuUI.clearScreen()
            Layout.printEmpty()
            Layout.print(ANSIColor.dim.wrap("暂无调优历史记录"))
            Layout.print(ANSIColor.dim.wrap("执行调优操作后，历史记录将自动保存"))
            MenuUI.waitForReturn()
            return
        }

        while true {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("系统调优复原"))
            Layout.print(ANSIColor.dim.wrap("选择要复原的调优批次"))
            Layout.printEmpty()

            let items = batches.reversed().prefix(10).enumerated().map { (i, batch) in
                let count = batch.records.count
                let time = String(batch.timestamp.prefix(19))
                return MenuItem("批次 \(batch.id)", "\(time) | \(count) 项修改", .yellow)
            }

            let choice = MenuUI.interactiveSelect(items: Array(items), exitLabel: "返回主菜单")
            guard choice > 0 else { return }

            let batch = Array(batches.reversed().prefix(10))[choice - 1]
            await showRestoreDetail(batch)
        }
    }

    /// 显示单个批次的复原详情，支持一键复原安全项或显示全部复原命令
    /// - Parameter batch: 目标修复批次
    private func showRestoreDetail(_ batch: FixBatch) async {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("复原详情: \(batch.id)"))
        Layout.print(ANSIColor.dim.wrap("时间: \(batch.timestamp)"))
        Layout.printLine()
        Layout.printEmpty()

        for record in batch.records {
            Layout.print("\(record.name)")
            Layout.print(ANSIColor.dim.wrap("  修改: \(record.previousValue) → \(record.newValue)"))
            Layout.print(ANSIColor.blue.wrap("  复原: \(record.undoCommand)"))
            Layout.printEmpty()
        }

        Layout.printSection("操作")
        let menuItems = [
            MenuItem("一键复原安全项", "自动执行不需 sudo 的复原", .green),
            MenuItem("显示全部复原命令", "复制到终端手动执行", .blue),
        ]

        let choice = MenuUI.interactiveSelect(items: menuItems, exitLabel: "返回上级")
        guard choice > 0 else { return }

        if choice == 1 {
            await executeAutoRestore(batch)
        } else {
            showRestoreCommands(batch)
        }
    }

    /// 检查 undo 命令是否安全可执行（委托给 UndoValidator）
    /// - Parameter cmd: 待检查的命令
    /// - Returns: 是否安全
    private func isValidUndoCommand(_ cmd: String) -> Bool {
        UndoValidator.isValidUndoCommand(cmd)
    }

    /// 自动执行不需 sudo 的复原命令
    /// - Parameter batch: 目标修复批次
    private func executeAutoRestore(_ batch: FixBatch) async {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("执行复原"))
        Layout.printLine()
        Layout.printEmpty()

        let safeRecords = batch.records.filter { !$0.undoCommand.hasPrefix("sudo ") && !$0.undoCommand.hasPrefix("#") }

        if safeRecords.isEmpty {
            Layout.print(ANSIColor.yellow.wrap("所有复原命令都需要 sudo，请手动执行"))
            MenuUI.waitForReturn()
            return
        }

        Layout.printNoNL("确认复原 \(safeRecords.count) 项? (y/N): ")
        guard let input = readLine()?.lowercased(), input == "y" || input == "yes" else {
            Layout.print(ANSIColor.yellow.wrap("已取消"))
            MenuUI.waitForReturn()
            return
        }

        Layout.printEmpty()
        for record in safeRecords {
            guard isValidUndoCommand(record.undoCommand) else {
                Layout.print(ANSIColor.yellow.wrap("⚠ 跳过不安全的复原命令: \(record.name)"))
                continue
            }
            let result = await executor.run(record.undoCommand)
            if result.isSuccess {
                Layout.print(ANSIColor.green.wrap("✓ 已复原: \(record.name)"))
            } else {
                Layout.print(ANSIColor.red.wrap("✗ 复原失败: \(record.name)"))
            }
        }

        Layout.printEmpty()
        Layout.print(ANSIColor.green.wrap("复原完成。建议重新运行系统全面审查验证。"))
        MenuUI.waitForReturn()
    }

    /// 显示复原命令列表，供用户手动复制执行
    /// - Parameter batch: 目标修复批次
    private func showRestoreCommands(_ batch: FixBatch) {
        MenuUI.clearScreen()
        Layout.print(ANSIColor.bold.wrap("复原命令列表"))
        Layout.print(ANSIColor.dim.wrap("请复制到终端手动执行"))
        Layout.printLine()
        Layout.printEmpty()

        for record in batch.records {
            Layout.print(ANSIColor.dim.wrap("# \(record.name)"))
            Layout.print(ANSIColor.bold.wrap(record.undoCommand))
            Layout.printEmpty()
        }
        MenuUI.waitForReturn()
    }

    // MARK: - 服务管理

    /// 进入服务管理子界面
    private func manageServices() async {
        await ServiceManager.run(executor: executor)
    }

    // MARK: - 开发环境安装助手

    /// 开发环境安装助手，展示常用开发工具的官方安装命令
    private func showDevInstaller() {
        struct ToolInstall {
            let name: String
            let description: String
            let install: String
            let note: String?
            init(_ name: String, _ description: String, _ install: String, note: String? = nil) {
                self.name = name; self.description = description
                self.install = install; self.note = note
            }
        }

        struct ToolGroup {
            let title: String
            let color: ANSIColor
            let tools: [ToolInstall]
        }

        let groups: [ToolGroup] = [
            ToolGroup(title: "基础工具链", color: .green, tools: [
                ToolInstall("Xcode CLT", "Clang/Swift 编译器、Make 等",
                    "xcode-select --install"),
                ToolInstall("Homebrew", "macOS 包管理器（必装）",
                    "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                    note: "安装完成后按提示将 brew 加入 PATH"),
            ]),
            ToolGroup(title: "运行时环境", color: .green, tools: [
                ToolInstall("nvm", "Node.js 版本管理器",
                    "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash",
                    note: "安装后重启终端，再用 nvm install --lts 安装 Node.js；⚠ 官方不支持 brew 安装 nvm，如之前用过 brew install nvm 请先 brew uninstall nvm"),
                ToolInstall("Node.js (via nvm)", "JavaScript 运行时",
                    "nvm install --lts && nvm use --lts"),
                ToolInstall("Bun", "高性能 JS/TS 运行时 & 包管理器",
                    "curl -fsSL https://bun.com/install | bash"),
                ToolInstall("TypeScript", "TypeScript 编译器",
                    "npm install -g typescript"),
                ToolInstall("pnpm", "高效 Node.js 包管理器",
                    "npm install -g pnpm"),
                ToolInstall("Yarn", "Node.js 包管理器",
                    "npm install -g yarn"),
                ToolInstall("Deno", "安全的 JS/TS 运行时",
                    "brew install deno"),
                ToolInstall("pyenv", "Python 版本管理器",
                    "brew install pyenv",
                    note: "安装后将 eval \"$(pyenv init -)\" 加入 ~/.zshrc"),
                ToolInstall("Python (via pyenv)", "Python 运行时",
                    "pyenv install 3.12 && pyenv global 3.12"),
                ToolInstall("uv", "极速 Python 包管理器 (Astral)",
                    "curl -LsSf https://astral.sh/uv/install.sh | sh"),
                ToolInstall("Rust (rustup)", "系统编程语言",
                    "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
                    note: "安装后执行 source ~/.cargo/env；⚠ 不要同时用 brew install rust，会导致 PATH 冲突"),
                ToolInstall("Go", "Go 语言编译器",
                    "brew install go"),
                ToolInstall("Java (via brew)", "Java 运行时 (OpenJDK)",
                    "brew install openjdk",
                    note: "安装后将 $(brew --prefix)/opt/openjdk/bin 加入 PATH"),
                ToolInstall("Swift", "包含在 Xcode CLT 中，无需单独安装",
                    "xcode-select --install"),
            ]),
            ToolGroup(title: "AI CLI 工具", color: .yellow, tools: [
                ToolInstall("Claude Code", "Anthropic 官方 CLI（推荐方式）",
                    "curl -fsSL https://claude.ai/install.sh | bash",
                    note: "或通过 Homebrew: brew install --cask claude-code"),
                ToolInstall("Codex CLI (OpenAI)", "OpenAI 代码生成 CLI",
                    "npm install -g @openai/codex"),
                ToolInstall("OpenCode", "开源 AI 编程助手 (SST)",
                    "curl -fsSL https://opencode.ai/install | bash",
                    note: "或 brew install anomalyco/tap/opencode"),
                ToolInstall("Gemini CLI (Google)", "Google Gemini 命令行工具",
                    "brew install gemini-cli"),
            ]),
            ToolGroup(title: "容器 & 本地 AI", color: .yellow, tools: [
                ToolInstall("OrbStack", "Docker/Linux VM 管理（比 Docker Desktop 轻量）",
                    "brew install orbstack",
                    note: "或从 https://orbstack.dev 下载 .dmg 安装"),
                ToolInstall("Docker (via OrbStack)", "OrbStack 包含 Docker 引擎，无需单独安装",
                    "brew install orbstack"),
                ToolInstall("Ollama", "本地大模型推理引擎",
                    "curl -fsSL https://ollama.com/install.sh | sh",
                    note: "安装后执行 ollama pull llama3.2 下载模型；macOS 推荐从 https://ollama.com 下载 .app，需要 macOS 14+"),
                ToolInstall("llama.cpp", "高效本地 LLM 推理（Metal GPU 加速）",
                    "brew install llama.cpp"),
                ToolInstall("MLX (macOS 26 / Apple Silicon)", "苹果官方 ML 框架（Apple Silicon 专属）",
                    "pip install mlx",
                    note: "需要 Apple Silicon + macOS 14+ + native ARM Python 3.10+（非 Rosetta）；请先完成上方 pyenv → Python 安装步骤"),
            ]),
            ToolGroup(title: "Git 工具链", color: .blue, tools: [
                ToolInstall("git-lfs", "Git 大文件存储扩展",
                    "brew install git-lfs && git lfs install"),
                ToolInstall("GitHub CLI (gh)", "GitHub 官方命令行工具",
                    "brew install gh",
                    note: "安装后执行 gh auth login 完成认证"),
                ToolInstall("lazygit", "终端 Git TUI 界面",
                    "brew install lazygit"),
                ToolInstall("delta", "Git diff 语法高亮增强",
                    "brew install git-delta",
                    note: "安装后在 ~/.gitconfig 中配置 core.pager = delta"),
            ]),
            ToolGroup(title: "效率工具", color: .blue, tools: [
                ToolInstall("ripgrep (rg)", "极速代码搜索工具",
                    "brew install ripgrep"),
                ToolInstall("fzf", "命令行模糊查找",
                    "brew install fzf"),
                ToolInstall("jq", "JSON 命令行处理器",
                    "brew install jq"),
                ToolInstall("bat", "带语法高亮的 cat 替代",
                    "brew install bat"),
                ToolInstall("eza", "现代化 ls 替代（带颜色/图标）",
                    "brew install eza"),
                ToolInstall("fd", "快速文件查找（find 替代）",
                    "brew install fd"),
                ToolInstall("yq", "YAML/JSON/TOML 命令行处理器",
                    "brew install yq"),
                ToolInstall("htop", "交互式进程监视器",
                    "brew install htop"),
                ToolInstall("ncdu", "终端磁盘使用分析",
                    "brew install ncdu"),
                ToolInstall("wget", "网络文件下载工具",
                    "brew install wget"),
                ToolInstall("tree", "目录树形结构显示",
                    "brew install tree"),
                ToolInstall("lazydocker", "Docker 容器 TUI 管理",
                    "brew install jesseduffield/lazydocker/lazydocker"),
            ]),
        ]

        while true {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("开发环境安装助手"))
            Layout.print(ANSIColor.dim.wrap("所有安装命令均来自官方文档 / GitHub README"))
            Layout.printLine()
            Layout.printEmpty()

            let groupItems = groups.map { MenuItem($0.title, "(\($0.tools.count) 个工具)", $0.color) }
            let choice = MenuUI.interactiveSelect(items: groupItems, exitLabel: "返回主菜单")
            guard choice > 0 else { return }

            let group = groups[choice - 1]

        // MARK: - 展示分组详情

        MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap(group.title))
            Layout.print(ANSIColor.dim.wrap("复制命令到终端执行即可安装"))
            Layout.printLine()
            Layout.printEmpty()
            for tool in group.tools {
                Swift.print(group.color.wrap("▸ \(tool.name)"))
                Swift.print(ANSIColor.dim.wrap("  \(tool.description)"))
                Swift.print("  \(tool.install)")
                if let note = tool.note {
                    Swift.print(ANSIColor.dim.wrap("  ⚠ \(note)"))
                }
                Swift.print("")
            }
            MenuUI.waitForReturn()
        }
    }


    // MARK: - 报告

    /// 导出 Markdown 格式的审查报告到指定文件
    private func exportMarkdown() {
        guard fullAuditDone else {
            Layout.print(ANSIColor.yellow.wrap("\n请先执行系统全面审查（选项 1）"))
            MenuUI.waitForReturn()
            return
        }
        let path = MenuUI.readPath(prompt: "输出路径", defaultPath: "~/macaudit_report.md")
        let md = ReportGenerator.generateMarkdown(
            results: lastResults, modules: modules,
            version: version, device: device, duration: lastDuration
        )
        do {
            try ReportGenerator.writeToFile(md, path: path)
            Layout.print(ANSIColor.green.wrap("报告已导出: \(path)"))
        } catch {
            Layout.print(ANSIColor.red.wrap("导出失败: \(error.localizedDescription)"))
        }
        MenuUI.waitForReturn()
    }

    /// 导出 JSON 格式的审查报告到指定文件
    private func exportJSON() {
        guard fullAuditDone else {
            Layout.print(ANSIColor.yellow.wrap("\n请先执行系统全面审查（选项 1）"))
            MenuUI.waitForReturn()
            return
        }
        let path = MenuUI.readPath(prompt: "输出路径", defaultPath: "~/macaudit_report.json")
        let jsonStr = ReportGenerator.generateJSON(
            results: lastResults, modules: modules,
            version: version, device: device, duration: lastDuration
        )
        do {
            try ReportGenerator.writeToFile(jsonStr, path: path)
            Layout.print(ANSIColor.green.wrap("JSON 已导出: \(path)"))
        } catch {
            Layout.print(ANSIColor.red.wrap("导出失败: \(error.localizedDescription)"))
        }
        MenuUI.waitForReturn()
    }

    /// 保存当前审查结果为基线快照
    private func saveBaseline() {
        guard fullAuditDone else {
            Layout.print(ANSIColor.yellow.wrap("\n请先执行系统全面审查（选项 1）"))
            MenuUI.waitForReturn()
            return
        }
        let baseline = BaselineManager()
        let jsonStr = ReportGenerator.generateJSON(
            results: lastResults, modules: modules,
            version: version, device: device, duration: lastDuration
        )
        do {
            let saved = try baseline.save(jsonStr)
            Layout.print(ANSIColor.green.wrap("基线已保存: \(saved)"))
        } catch {
            Layout.print(ANSIColor.red.wrap("保存失败: \(error.localizedDescription)"))
        }
        MenuUI.waitForReturn()
    }

    /// 对比最近两次基线报告，展示 diff 结果
    private func runDiff() {
        let baseline = BaselineManager()
        let reports = baseline.listReports()
        if reports.count < 2 {
            Layout.print(ANSIColor.yellow.wrap("需要至少 2 次基线记录才能对比"))
            Layout.print(ANSIColor.dim.wrap("当前基线数: \(reports.count)"))
            MenuUI.waitForReturn()
            return
        }
        if let prev = baseline.previousReport(),
           let last = baseline.lastReport(),
           let diff = BaselineManager.diff(oldPath: prev, newPath: last) {
            diff.printReport()
        }
        MenuUI.waitForReturn()
    }

    // MARK: - 系统

    /// 自测：验证 MacOSVersion、DeviceType、ShellExecutor、readSysctl 等基础组件是否正常
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

        Layout.print(ANSIColor.green.wrap("✓ DeviceType: \(device.displayName)"))
        passed += 1

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
        MenuUI.waitForReturn()
    }
}
