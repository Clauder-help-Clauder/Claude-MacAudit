//
//  PowerModule.swift
//  MacAudit
//
//  M7: 电源配置模块
//  检测 pmset 电源管理配置，包括接电/电池模式下的休眠策略、
//  网络唤醒、caffeinate 防休眠、定时关机计划等，
//  根据设备类型（笔记本/台式机）动态生成不同的检查项。
//

import Foundation
import MacAuditCore

/// M7: 电源配置模块
struct PowerModule: AuditModule {
    /// 模块唯一标识
    let id = "power"
    /// 模块显示名称
    let name = "电源配置"
    /// 模块功能描述
    let description = "pmset 电源管理配置检测（不需要 sudo）"

    /// 根据设备类型生成电源配置检查项：接电配置、电池配置（笔记本）、通用配置、休眠模式、服务器模式等
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        var list: [AuditCheck] = []

        /// 构建 pmset 读取命令
        func pmsetCmd(_ key: String) -> String {
            "val=$(pmset -g 2>/dev/null | awk '/^ *\(key) /{print $2}'); echo \"${val:-pmset_not_found}\""
        }

        // 接电配置 (6 项) — 服务器模式：永不休眠
        // (key, expected, name, description)
        let acItems: [(String, String, String, String)] = [
            ("sleep", "0", "接电-系统休眠",
             "接电时系统自动休眠的延迟（分钟，0=永不休眠）。服务器/开发机插电时应设为 0，防止长时间任务（AI 推理、构建、SSH）被中断。\n修复: sudo pmset -c sleep 0"),
            ("disksleep", "0", "接电-磁盘休眠",
             "接电时硬盘自动休眠的延迟（分钟，0=禁用磁盘休眠）。磁盘休眠会导致访问时的几秒延迟，影响数据库和日志写入。\n修复: sudo pmset -c disksleep 0"),
            ("displaysleep", "10", "接电-显示器关闭",
             "接电时显示器自动关闭的延迟（分钟，10=10分钟后关闭）。保持 10 分钟节省电力但不干扰工作。\n修复: sudo pmset -c displaysleep 10（0=永不关闭）"),
            ("standby", "0", "接电-待机",
             "接电时进入深度待机（Standby）模式的延迟（0=禁用待机）。Standby 会将内存内容写入磁盘并断电，恢复时间长，服务器应禁用。\n修复: sudo pmset -c standby 0"),
            ("powernap", "0", "接电-Power Nap",
             "接电时 Power Nap 后台唤醒功能（0=禁用）。Power Nap 会在系统休眠时定期唤醒处理邮件/iCloud 同步，不需要时应关闭。\n修复: sudo pmset -c powernap 0"),
            ("lowpowermode", "0", "接电-节能模式",
             "接电时低功耗模式（0=禁用，全功率运行）。低功耗模式会降低 CPU/GPU 频率，接电时无需节能，应保持全功率。\n修复: sudo pmset -c lowpowermode 0"),
        ]
        for (key, expected, name, desc) in acItems {
            list.append(AuditCheck(
                id: "m7.ac_\(key)", name: name, module: id,
                description: desc,
                command: pmsetCmd(key), expected: expected, risk: .safe,
                fixRisk: .high,
                fixCommand: "sudo pmset -c \(key) \(expected)",
                priority: .a2
            ))
        }

        // 电池配置 — 仅 laptop (服务器模式：永不休眠，合盖继续运行)
        if device == .laptop {
            let battItems: [(String, String, String, String)] = [
                ("sleep", "0", "电池-系统休眠",
                 "电池供电时系统休眠延迟（0=永不休眠）。笔记本用作移动服务器时应设为 0，防止合盖任务中断。\n修复: sudo pmset -b sleep 0"),
                ("disksleep", "0", "电池-磁盘休眠",
                 "电池供电时磁盘休眠延迟（0=禁用）。防止磁盘休眠造成的 I/O 延迟。\n修复: sudo pmset -b disksleep 0"),
                ("displaysleep", "10", "电池-显示器关闭",
                 "电池供电时显示器关闭延迟（分钟）。10 分钟可节省电量而不影响操作。\n修复: sudo pmset -b displaysleep 10"),
                ("standby", "0", "电池-待机",
                 "电池供电时深度待机延迟（0=禁用）。禁用待机防止任务被中断，注意这会增加电池消耗。\n修复: sudo pmset -b standby 0"),
                ("powernap", "0", "电池-Power Nap",
                 "电池供电时 Power Nap（0=禁用）。禁用可节省电量，防止电池在合盖静置时意外耗尽。\n修复: sudo pmset -b powernap 0"),
            ]
            for (key, expected, name, desc) in battItems {
                list.append(AuditCheck(
                    id: "m7.batt_\(key)", name: name, module: id,
                    description: desc,
                    command: pmsetCmd(key), expected: expected, risk: .safe,
                    fixRisk: .high,
                    fixCommand: "sudo pmset -b \(key) \(expected)",
                    devices: [.laptop],
                    priority: .a2
                ))
            }
        }

        // 通用配置
        var generalChecks: [AuditCheck] = [
            AuditCheck(id: "m7.womp", name: "网络唤醒 (AC)", module: id,
                       description: "接电时允许通过网络数据包（Magic Packet）远程唤醒本机（Wake on LAN/Bonjour）。服务器场景应开启，便于远程管理。\n修复: sudo pmset -a womp 1\n关闭: sudo pmset -a womp 0",
                       command: pmsetCmd("womp"), expected: "1", risk: .safe,
                       fixRisk: .high, fixCommand: "sudo pmset -a womp 1",
                       priority: .a2),
            AuditCheck(id: "m7.powermetrics", name: "powermetrics 工具", module: id,
                       description: "powermetrics 是 macOS 内置的系统性能分析工具（通常位于 /usr/bin/powermetrics）。\n使用示例:\n  sudo powermetrics --samplers cpu_power,gpu_power,thermal -i 1000 -n 5   # 1秒采样5次\n  sudo powermetrics --samplers tasks -i 1000 -n 1 | head -30              # 查看高耗能进程\nClaude Code 电量分析: 安装并用此工具监测 AI 推理任务的 CPU/GPU 功耗。",
                       command: "which powermetrics 2>/dev/null || echo 'not found'",
                       risk: .safe,
                       priority: .a2),
            AuditCheck(id: "m7.caffeinate_running", name: "caffeinate 运行", module: id,
                       description: "添加防护: caffeinate -dims &\n（-d 防显示器休眠，-i 防系统休眠，-m 防磁盘休眠，-s 接电时保持，& 后台运行）\n取消防护: pkill caffeinate",
                       command: "pgrep -l caffeinate 2>/dev/null | head -1 || echo 'not running'",
                       risk: .safe,
                       priority: .a2),
            AuditCheck(id: "m7.caffeinate_system", name: "caffeinate 系统级", module: id,
                       description: "添加防护: 创建系统级 LaunchDaemon 让 caffeinate 开机自动运行\nsudo tee /Library/LaunchDaemons/com.server.caffeinate.plist << 'EOF'\n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict>\n  <key>Label</key><string>com.server.caffeinate</string>\n  <key>ProgramArguments</key><array><string>/usr/bin/caffeinate</string><string>-dims</string></array>\n  <key>KeepAlive</key><true/><key>RunAtLoad</key><true/>\n</dict></plist>\nEOF\nsudo launchctl load /Library/LaunchDaemons/com.server.caffeinate.plist\n取消防护:\nsudo launchctl unload /Library/LaunchDaemons/com.server.caffeinate.plist\nsudo rm /Library/LaunchDaemons/com.server.caffeinate.plist",
                       command: "test -f /Library/LaunchDaemons/com.server.caffeinate.plist && echo 'exists' || echo 'missing'",
                       risk: .safe,
                       priority: .a2),
            AuditCheck(id: "m7.caffeinate_user", name: "caffeinate 用户级", module: id,
                       description: "添加防护: 创建用户级 LaunchAgent 让 caffeinate 登录自动运行\nmkdir -p ~/Library/LaunchAgents\ntee ~/Library/LaunchAgents/com.user.caffeinate.plist << 'EOF'\n<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict>\n  <key>Label</key><string>com.user.caffeinate</string>\n  <key>ProgramArguments</key><array><string>/usr/bin/caffeinate</string><string>-dims</string></array>\n  <key>KeepAlive</key><true/><key>RunAtLoad</key><true/>\n</dict></plist>\nEOF\nlaunchctl load ~/Library/LaunchAgents/com.user.caffeinate.plist\n取消防护:\nlaunchctl unload ~/Library/LaunchAgents/com.user.caffeinate.plist\nrm ~/Library/LaunchAgents/com.user.caffeinate.plist",
                       command: "test -f ~/Library/LaunchAgents/com.user.caffeinate.plist && echo 'exists' || echo 'missing'",
                       risk: .safe,
                       priority: .a2),
            AuditCheck(id: "m7.schedule", name: "定时关机计划", module: id,
                       description: "检测是否存在 pmset 定时关机/休眠计划（期望为 0，即无定时任务）。\n服务器不应有定时关机，否则会中断运行中的服务。\n查看现有计划: pmset -g sched\n取消所有计划: sudo pmset schedule cancelall\n添加定时关机（如需要）: sudo pmset schedule shutdown \"01/01/2025 03:00:00\"",
                       command: "result=$(pmset -g sched 2>/dev/null | grep -c 'Scheduled'); echo \"${result:-0}\"",
                       expected: "0", risk: .safe,
                       fixRisk: .high, fixCommand: "sudo pmset schedule cancelall",
                       priority: .a2),
            AuditCheck(id: "m7.screensaver", name: "屏保空闲时间", module: id,
                       description: "当前主机屏保触发的空闲等待时间（秒，0=不触发）。\n查看: defaults -currentHost read com.apple.screensaver idleTime\n设为永不触发（服务器/开发机）: defaults -currentHost write com.apple.screensaver idleTime -int 0\n设为 10 分钟: defaults -currentHost write com.apple.screensaver idleTime -int 600\n注意：与 M5 的 screensaver.idleTime 是同一设置，两者应保持一致。",
                       command: "defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo 'not set'",
                       risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults -currentHost write com.apple.screensaver idleTime -int 0",
                       priority: .a2),
            AuditCheck(id: "m7.maxfiles", name: "文件描述符限制", module: id,
                       description: "系统级文件描述符限制（soft/hard 两个值）。\n查看: launchctl limit maxfiles\n推荐值: 65536 524288（soft 65536，hard 524288）\n当前 session 调整: ulimit -n 65536\n持久化（需要 LaunchDaemon，参见 m9.maxfiles_plist）:\n  sudo launchctl limit maxfiles 65536 524288\n注意：此处显示的是 launchctl 级别的限制，与 ulimit -n 显示值可能不同。",
                       command: "launchctl limit maxfiles 2>/dev/null | awk '{print $2}'",
                       risk: .safe,
                       priority: .a2),
            AuditCheck(id: "m7.memory_pressure", name: "内存压力级别", module: id,
                       description: "当前系统内存压力等级（0=正常，1=警告，2=紧急）。\n实时监控: memory_pressure（macOS 内置工具）\n压力过高时的处理步骤:\n  1. Activity Monitor → Memory 列按使用量降序排列\n  2. 关闭占用 > 1GB 的不必要应用\n  3. 减少 LLM 模型并行加载数（OLLAMA_MAX_LOADED_MODELS）\n  4. 临时清理文件缓存（慎用）: sudo purge",
                       command: "sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 'unknown'",
                        risk: .safe,
                        priority: .a2),
         ]
        list.append(contentsOf: generalChecks)

        if device == .desktop {
            list.append(AuditCheck(id: "m7.autorestart", name: "断电自动重启", module: id,
                       description: "断电恢复后自动重启（1=开启）。台式机/服务器场景必须开启，防止短暂停电后机器不自动恢复服务。\n注意: 笔记本不支持此 pmset key（有电池作为备份电源）。\n修复: sudo pmset -a autorestart 1\n关闭: sudo pmset -a autorestart 0",
                       command: pmsetCmd("autorestart"), expected: "1", risk: .safe,
                       fixRisk: .high, fixCommand: "sudo pmset -a autorestart 1",
                       priority: .a2))
        }

        // wifi 接电唤醒 (item 14) — always present
        list.append(AuditCheck(
            id: "m7.wifi_ac", name: "Wi-Fi 接电唤醒", module: id,
            description: "接电时允许通过 Wi-Fi 网络数据包唤醒本机（womp=1）。服务器/开发机通过 Wi-Fi 管理时应开启，便于远程 SSH 唤醒。\n修复: sudo pmset -c womp 1\n关闭: sudo pmset -c womp 0",
            command: pmsetCmd("womp"), expected: "1", risk: .safe,
            fixRisk: .high, fixCommand: "sudo pmset -c womp 1",
            priority: .a2
        ))

        // wifi 电池唤醒 — laptop only (item 15)
        if device == .laptop {
            list.append(AuditCheck(
                id: "m7.wifi_battery", name: "Wi-Fi 电池唤醒", module: id,
                description: "电池供电时允许通过 Wi-Fi 唤醒本机（womp=1，仅笔记本）。移动服务器场景开启，注意会增加电池消耗。\n修复: sudo pmset -b womp 1\n关闭: sudo pmset -b womp 0",
                command: pmsetCmd("womp"), expected: "1", risk: .safe,
                fixRisk: .high, fixCommand: "sudo pmset -b womp 1",
                devices: [.laptop],
                priority: .a2
            ))
        }

        // hibernatemode
        let hibernateDesc: String
        if device == .laptop {
            hibernateDesc = """
休眠模式（笔记本推荐 mode 3 = Safe Sleep）。
模式说明:
  0 = 禁用休眠，内存内容不写磁盘（断电即失数据，台式机用）
  3 = Safe Sleep，睡眠时同时保持内存通电 + 写磁盘镜像（笔记本推荐，兼顾速度和安全）
  25 = 深度休眠，完全断电后从磁盘恢复（最省电但恢复最慢）
修复: sudo pmset -a hibernatemode 3
"""
        } else {
            hibernateDesc = """
休眠模式（台式机/Mac mini 推荐 mode 0 = 禁用休眠）。
台式机通常接电，无需将内存内容写入磁盘保护，mode 0 速度最快。
模式说明:
  0 = 禁用休眠（台式机推荐）
  3 = Safe Sleep（笔记本默认）
修复: sudo pmset -a hibernatemode 0
"""
        }
        list.append(AuditCheck(
            id: "m7.hibernatemode", name: "休眠模式", module: id,
            description: hibernateDesc,
            command: pmsetCmd("hibernatemode"),
            expected: device == .laptop ? "3" : "0",
            risk: .safe,
            fixRisk: .high,
            fixCommand: "sudo pmset -a hibernatemode \(device == .laptop ? 3 : 0)",
            priority: .a2
        ))

        // 合盖不休眠 — laptop only
        if device == .laptop {
            list.append(AuditCheck(
                id: "m7.lidwake", name: "合盖不唤醒（保持运行）", module: id,
                description: "添加防护: sudo pmset -a lidwake 0\n（合盖后不因开盖自动唤醒，配合 caffeinate 使合盖继续运行任务）\n注意: Apple Silicon 合盖会进入低功耗状态，lidwake 无法完全阻止，建议同时运行:\ncaffeinate -dims &\n取消防护: sudo pmset -a lidwake 1",
                command: pmsetCmd("lidwake"),
                expected: "0", risk: .safe,
                fixRisk: .high,
                fixCommand: "sudo pmset -a lidwake 0 && caffeinate -dims &",
                devices: [.laptop],
                priority: .a2
            ))
        }

        // Amphetamine — 防意外休眠推荐工具
        list.append(AuditCheck(
            id: "m7.amphetamine", name: "Amphetamine（防休眠工具）", module: id,
            description: "推荐安装: 在 App Store 搜索「Amphetamine」免费安装\n功能: 灵活控制系统保持唤醒，支持定时、按 App、按网络条件触发，比 caffeinate 更直观\n取消: 从 /Applications 删除 Amphetamine.app",
            command: "test -d '/Applications/Amphetamine.app' && echo 'installed' || echo 'not installed'",
            risk: .safe,
            priority: .a2
        ))

        // 服务器模式一键命令（汇总项）
        let serverCmd: String
        if device == .desktop {
            serverCmd = "sudo pmset -a sleep 0 disksleep 0 displaysleep 10 standby 0 powernap 0 lowpowermode 0 autorestart 1 womp 1 lidwake 0 hibernatemode 0 && caffeinate -dims &"
        } else {
            serverCmd = "sudo pmset -a sleep 0 disksleep 0 displaysleep 10 standby 0 powernap 0 lowpowermode 0 womp 1 lidwake 0 hibernatemode 3 && caffeinate -dims &"
        }
        list.append(AuditCheck(
            id: "m7.server_mode", name: "服务器模式（一键设定）", module: id,
            description: "添加防护: 以下一条命令设定为服务器模式（永不休眠、合盖继续运行）:\n\(serverCmd)\n取消防护: sudo pmset -a sleep 10 disksleep 10 displaysleep 5 standby 1 powernap 1 lidwake 1 && pkill caffeinate",
            command: "pmset -g 2>/dev/null | awk '/^ *sleep /{print $2}' | head -1",
            expected: "0",
            risk: .safe,
            fixRisk: .high,
            fixCommand: serverCmd,
            priority: .a2
        ))

        return list
    }

    /// 执行电源配置检查，返回检测结果
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
