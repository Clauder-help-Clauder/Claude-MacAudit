import Foundation

/// M6: 服务状态模块 — 检测 launchd 服务禁用状态
public struct ServicesModule: AuditModule {
    public init() {}

    public let id = "services"
    public let name = "服务状态"
    public let description = "launchd 服务禁用状态检测（期望禁用不需要的服务）"

    /// 服务定义（含用户说明）
    struct ServiceDef {
        let name: String
        let group: String
        let hint: String
        let versions: Set<MacOSVersion>
        let architectures: Set<CPUArchitecture>
        let priority: CheckPriority

        init(_ name: String, _ group: String, _ hint: String = "", _ versions: Set<MacOSVersion> = [], architectures: Set<CPUArchitecture> = [], priority: CheckPriority = .a2) {
            self.name = name
            self.group = group
            self.hint = hint
            self.versions = versions
            self.architectures = architectures
            self.priority = priority
        }
    }

    private let services: [ServiceDef] = [
        // Siri/AI 类
        ServiceDef("com.apple.assistant_service", "Siri/AI", "Siri 核心请求处理，响应语音指令", priority: .a1),
        ServiceDef("com.apple.assistantd", "Siri/AI", "Siri 后台守护进程，常驻内存", priority: .a1),
        ServiceDef("com.apple.assistant_cdmd", "Siri/AI", "Siri 多设备上下文匹配", priority: .a1),
        ServiceDef("com.apple.Siri.agent", "Siri/AI", "响应「嘿 Siri」唤醒词的前台代理", priority: .a1),
        ServiceDef("com.apple.siriactionsd", "Siri/AI", "Siri 快捷指令动作执行引擎", priority: .a1),
        ServiceDef("com.apple.siriinferenced", "Siri/AI", "预测用户下一步操作的意图引擎", priority: .a1),
        ServiceDef("com.apple.sirittsd", "Siri/AI", "Siri 语音合成，文字转语音播报", priority: .a1),
        ServiceDef("com.apple.SiriTTSTrainingAgent", "Siri/AI", "收集语音样本改善 Siri 发音", priority: .a1),
        ServiceDef("com.apple.siriknowledged", "Siri/AI", "存储个人化 Siri 上下文数据", priority: .a1),
        ServiceDef("com.apple.parsec-fbf", "Siri/AI", "联邦学习框架，本地训练 AI 模型", priority: .a1),
        ServiceDef("com.apple.parsecd", "Siri/AI", "自然语言解析，支持 Siri 理解语句", priority: .a1),
        ServiceDef("com.apple.intelligenceflowd", "Siri/AI", "Apple Intelligence 流程调度", [.sequoia, .tahoe], architectures: [.arm64], priority: .a1),
        ServiceDef("com.apple.intelligencecontextd", "Siri/AI", "Apple Intelligence 上下文感知", [.sequoia, .tahoe], architectures: [.arm64], priority: .a1),
        ServiceDef("com.apple.intelligenceplatformd", "Siri/AI", "Apple Intelligence 平台基础服务", [.sequoia, .tahoe], architectures: [.arm64], priority: .a1),
        ServiceDef("com.apple.knowledgeconstructiond", "Siri/AI", "从行为构建本地知识图谱", [.sequoia, .tahoe], architectures: [.arm64], priority: .a1),
        ServiceDef("com.apple.generativeexperiencesd", "Siri/AI", "生成式 AI 功能体验服务", [.sequoia, .tahoe], architectures: [.arm64], priority: .a1),
        ServiceDef("com.apple.knowledge-agent", "Siri/AI", "个人知识索引，支持 Spotlight 搜索", priority: .a1),
        ServiceDef("com.apple.suggestd", "Siri/AI", "Siri 建议，各处推送预测性内容", priority: .a1),
        ServiceDef("com.apple.naturallanguaged", "Siri/AI", "系统级自然语言处理后台服务", priority: .a1),
        ServiceDef("com.apple.proactived", "Siri/AI", "主动式 Siri 建议推送引擎", [.sequoia, .tahoe], priority: .a1),
        ServiceDef("com.apple.milod", "Siri/AI", "机器学习模型本地推理优化", [.sequoia, .tahoe], architectures: [.arm64], priority: .a1),
        ServiceDef("com.apple.corespeechd", "Siri/AI", "核心语音识别框架守护进程", [.sequoia, .tahoe], priority: .a1),

        // 媒体/娱乐类
        ServiceDef("com.apple.watchlistd", "媒体/娱乐", "Apple TV 想看列表同步服务"),
        ServiceDef("com.apple.gamed", "媒体/娱乐", "Game Center 游戏成就与好友"),
        ServiceDef("com.apple.voicebankingd", "媒体/娱乐", "辅助功能个性化语音库服务"),
        ServiceDef("com.apple.newsd", "媒体/娱乐", "Apple News 新闻后台刷新服务"),
        ServiceDef("com.apple.weatherd", "媒体/娱乐", "系统天气数据获取与缓存"),
        ServiceDef("com.apple.tipsd", "媒体/娱乐", "macOS 使用技巧推送通知"),
        ServiceDef("com.apple.financed", "媒体/娱乐", "Apple 股票/金融数据同步"),
        ServiceDef("com.apple.mediaanalysisd", "媒体/娱乐", "媒体文件内容分析以支持搜索"),
        ServiceDef("com.apple.shazamd", "媒体/娱乐", "Shazam 音乐识别后台服务", [.sequoia, .tahoe]),
        ServiceDef("com.apple.sportsd", "媒体/娱乐", "Apple 体育赛事数据推送", [.sequoia, .tahoe]),
        ServiceDef("com.apple.homeenergyd", "媒体/娱乐", "家庭能源管理与电价感知", [.sequoia, .tahoe]),
        ServiceDef("com.apple.translationd", "媒体/娱乐", "系统翻译框架后台语言包下载", [.sequoia, .tahoe]),
        ServiceDef("com.apple.AMPDownloadAgent", "媒体/娱乐", "Apple Music 后台下载离线音乐"),

        // 照片/地图/社交类
        ServiceDef("com.apple.photoanalysisd", "照片/地图/社交", "照片 AI 分析，支持人物场景识别"),
        ServiceDef("com.apple.Maps.pushdaemon", "照片/地图/社交", "地图推送通知，路况提醒服务"),
        ServiceDef("com.apple.Maps.mapssyncd", "照片/地图/社交", "地图收藏与历史 iCloud 同步"),
        ServiceDef("com.apple.maps.destinationd", "照片/地图/社交", "目的地预测与路线缓存服务"),
        ServiceDef("com.apple.navd", "照片/地图/社交", "导航引擎后台实时路线计算"),
        ServiceDef("com.apple.geodMachServiceBridge", "照片/地图/社交", "地理位置服务 Mach 桥接层"),
        ServiceDef("com.apple.geoanalyticsd", "照片/地图/社交", "位置使用行为统计数据上报"),
        ServiceDef("com.apple.imautomatichistorydeletionagent", "照片/地图/社交", "iMessage 消息自动删除定时任务"),
        ServiceDef("com.apple.GameController.gamecontrollerd", "照片/地图/社交", "游戏手柄驱动与事件分发"),

        // iCloud/家庭类
        ServiceDef("com.apple.iCloudNotificationAgent", "iCloud/家庭", "iCloud 变更推送通知接收代理"),
        ServiceDef("com.apple.iCloudUserNotifications", "iCloud/家庭", "iCloud 用户级通知展示服务"),
        ServiceDef("com.apple.familycircled", "iCloud/家庭", "家人共享圈位置内容共享"),
        ServiceDef("com.apple.familycontrols.useragent", "iCloud/家庭", "家长控制策略执行用户代理"),
        ServiceDef("com.apple.familynotificationd", "iCloud/家庭", "家人共享变更通知推送"),
        ServiceDef("com.apple.ScreenTimeAgent", "iCloud/家庭", "屏幕使用时间统计与限制执行"),
        ServiceDef("com.apple.macos.studentd", "iCloud/家庭", "课堂 App 学生端管理服务"),
        ServiceDef("com.apple.progressd", "iCloud/家庭", "学生学习进度追踪上报"),
        ServiceDef("com.apple.TMHelperAgent", "iCloud/家庭", "Time Machine 备份状态监控助手"),

        // 遥测/分析类
        ServiceDef("com.apple.UsageTrackingAgent", "遥测/分析", "追踪 App 使用频率上报 Apple", priority: .a1),
        ServiceDef("com.apple.BiomeAgent", "遥测/分析", "用户行为生物特征数据采集", priority: .a1),
        ServiceDef("com.apple.biomesyncd", "遥测/分析", "生物行为数据跨设备同步", priority: .a1),
        ServiceDef("com.apple.inputanalyticsd", "遥测/分析", "键盘输入习惯分析数据采集", priority: .a1),
        ServiceDef("com.apple.ap.adprivacyd", "遥测/分析", "广告隐私归因处理服务", priority: .a1),
        ServiceDef("com.apple.ap.promotedcontentd", "遥测/分析", "App Store 推广内容个性化推送", priority: .a1),
        ServiceDef("com.apple.triald", "遥测/分析", "A/B 测试框架，向用户分发实验功能", priority: .a1),
        ServiceDef("com.apple.routined", "遥测/分析", "学习日常作息规律供 Siri 预测", priority: .a1),
        ServiceDef("com.apple.duetexpertd", "遥测/分析", "AI 专家系统，优化设备使用建议", priority: .a1),
        ServiceDef("com.apple.ContextStoreAgent", "遥测/分析", "用户活动上下文存储与检索", priority: .a1),
        ServiceDef("com.apple.analyticsd", "遥测/分析", "系统诊断数据采集与上报", priority: .a1),
        ServiceDef("com.apple.ecosystemanalyticsd", "遥测/分析", "Apple 生态系统跨设备使用分析", priority: .a1),
        ServiceDef("com.apple.audioanalyticsd", "遥测/分析", "麦克风与音频环境分析采集", priority: .a1),
        ServiceDef("com.apple.wifianalyticsd", "遥测/分析", "Wi-Fi 连接质量行为统计上报", priority: .a1),
        ServiceDef("com.apple.biomed", "遥测/分析", "健康传感器数据采集服务", priority: .a1),
        ServiceDef("com.apple.triald.system", "遥测/分析", "系统级 A/B 测试框架", priority: .a1),

        // 共享/Handoff 类
        ServiceDef("com.apple.screensharing.agent", "共享/Handoff", "屏幕共享代理，响应远程连接"),
        ServiceDef("com.apple.screensharing.menuextra", "共享/Handoff", "屏幕共享菜单栏图标与状态"),
        ServiceDef("com.apple.screensharing.MessagesAgent", "共享/Handoff", "iMessage 发起屏幕共享桥接"),
        ServiceDef("com.apple.replicatord", "共享/Handoff", "设备间内容复制同步服务"),
        ServiceDef("com.apple.helpd", "共享/Handoff", "macOS 帮助查看器数据服务"),
        ServiceDef("com.apple.followupd", "共享/Handoff", "跨设备任务接力与 Handoff"),
        ServiceDef("com.apple.icloud.searchpartyuseragent", "共享/Handoff", "「查找」网络设备定位代理"),
    ]

    // MARK: - 辅助方法：从 ServiceDef 构建 AuditCheck（含 hint description）
    func makeCheck(from svc: ServiceDef, command: String = "") -> AuditCheck {
        let desc = "\(svc.hint)\n【分组】\(svc.group)\n【禁用此服务】\n  launchctl disable gui/$(id -u)/\(svc.name) && launchctl bootout gui/$(id -u)/\(svc.name) 2>/dev/null; true\n【重新启用】\n  launchctl enable gui/$(id -u)/\(svc.name)"
        return AuditCheck(
            id: "m6.\(svc.name)",
            name: svc.name.replacingOccurrences(of: "com.apple.", with: ""),
            module: id,
            description: desc,
            command: command,
            expected: "true",
            risk: .safe,
            fixRisk: .low,
            fixCommand: "launchctl disable gui/$(id -u)/\(svc.name) && launchctl bootout gui/$(id -u)/\(svc.name) 2>/dev/null; true",
            tags: [svc.group],
            priority: svc.priority
        )
    }

    private func isApplicable(_ svc: ServiceDef, version: MacOSVersion, arch: CPUArchitecture) -> Bool {
        let versionOk = svc.versions.isEmpty || svc.versions.contains(version)
        let archOk = svc.architectures.isEmpty || svc.architectures.contains(arch)
        return versionOk && archOk
    }

    public func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        services
            .filter { isApplicable($0, version: version, arch: arch) }
            .map { makeCheck(from: $0) }
    }

    public func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        let result = await executor.run("launchctl print-disabled gui/$(id -u) 2>/dev/null")
        let output = result.trimmedOutput
        var disabledMap: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("=>") else { continue }
            let parts = trimmed.components(separatedBy: "=>")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\"", with: "")
                let val = parts[1].trimmingCharacters(in: .whitespaces)
                disabledMap[key] = val
            }
        }

        let applicableServices = services.filter {
            isApplicable($0, version: version, arch: arch)
        }
        var results: [AuditResult] = []

        for svc in applicableServices {
            let check = makeCheck(from: svc, command: "launchctl print-disabled")

            if let status = disabledMap[svc.name] {
                if status == "disabled" {
                    results.append(.pass(check: check, actual: "disabled"))
                } else {
                    results.append(.fail(check: check, actual: "enabled"))
                }
            } else {
                results.append(.warn(check: check, actual: "未管理", duration: 0))
            }
        }
        return results
    }

    /// 供 ServiceManager 使用：返回带说明的服务列表
    func servicesForManagement(version: MacOSVersion, arch: CPUArchitecture) -> [ServiceDef] {
        services.filter { isApplicable($0, version: version, arch: arch) }
    }
}
