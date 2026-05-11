//
//  AnimationModule.swift
//  MacAudit
//
//  M5: 视觉动画优化模块
//  检测 macOS defaults 中动画、Dock、Finder、屏保等 UI 相关配置，
//  通过关闭不必要的动画和视觉效果来提升系统响应速度并节省 GPU 资源。
//

import Foundation
import MacAuditCore

/// M5: 视觉动画优化模块
struct AnimationModule: AuditModule {
    /// 模块唯一标识
    let id = "animation"
    /// 模块显示名称
    let name = "视觉动画优化"
    /// 模块功能描述
    let description = "defaults 动画和 UI 优化配置检测"

    /// defaults 检查项定义（domain, key, expected, name, versions, description）
    private struct DefaultsDef {
        /// defaults domain，如 "-g"（NSGlobalDomain）或 "com.apple.dock"
        let domain: String
        /// defaults key 名称
        let key: String
        /// 期望值（字符串形式）
        let expected: String
        /// 检查项显示名称
        let name: String
        /// 适用的 macOS 版本集合，为空则全版本适用
        let versions: Set<MacOSVersion>
        /// 检查项详细说明
        let description: String

        /// 便捷初始化器
        init(_ domain: String, _ key: String, _ expected: String, _ name: String,
             _ versions: Set<MacOSVersion> = [], description: String = "") {
            self.domain = domain
            self.key = key
            self.expected = expected
            self.name = name
            self.versions = versions
            self.description = description
        }
    }

    /// 所有 defaults 检查项定义，按类别分组：通用动画、Dock 优化、Finder 和其他、屏保截图、Sequoia 专属、Tahoe 专属、软件更新
    private let defs: [DefaultsDef] = [
        // ── 通用动画 (15) ─────────────────────────────────────────────────
        DefaultsDef("-g", "NSAutomaticWindowAnimationsEnabled", "0", "窗口动画",
            description: "禁用窗口自动展开/收起动画（Sheets、Popovers、下拉面板等）。关闭后 UI 操作立即响应，无滑入延迟。\n修复: defaults write -g NSAutomaticWindowAnimationsEnabled -int 0"),

        DefaultsDef("-g", "NSWindowResizeTime", "0.001", "窗口缩放速度",
            description: "窗口拖拽调整大小时的动画持续时间（秒）。默认约 0.2 秒，设为 0.001 使调整窗口大小几乎即时完成。\n修复: defaults write -g NSWindowResizeTime -float 0.001"),

        DefaultsDef("-g", "NSToolbarFullScreenAnimationDuration", "0", "全屏工具栏动画",
            description: "进入/退出全屏模式时工具栏滑入滑出的动画时间（秒）。默认约 0.5 秒，设为 0 立即完成切换。\n修复: defaults write -g NSToolbarFullScreenAnimationDuration -int 0"),

        DefaultsDef("-g", "NSDocumentRevisionsWindowTransformAnimation", "0", "文档版本动画",
            description: "打开文档版本历史（Time Machine for documents）时的 3D 翻转入场动画。设为 0 直接显示版本列表。\n修复: defaults write -g NSDocumentRevisionsWindowTransformAnimation -int 0"),

        DefaultsDef("-g", "NSBrowserColumnAnimationSpeedMultiplier", "0", "浏览器列动画",
            description: "Finder 列视图切换时的列滑入动画速率倍数。设为 0 禁用所有列切换动画，Finder 导航更流畅。\n修复: defaults write -g NSBrowserColumnAnimationSpeedMultiplier -int 0"),

        DefaultsDef("-g", "NSScrollAnimationEnabled", "0", "滚动动画",
            description: "平滑滚动动画（如按 Home/End 跳转时的惯性滚动效果）。禁用后跳转立即到位，无过渡动画。\n修复: defaults write -g NSScrollAnimationEnabled -int 0"),

        DefaultsDef("-g", "NSScrollViewRubberbanding", "0", "橡皮筋回弹",
            description: "滚动超出内容边界时的弹性回弹动画（类似 iOS 的弹簧效果）。禁用后减少误操作和晕屏感。\n修复: defaults write -g NSScrollViewRubberbanding -int 0"),

        DefaultsDef("-g", "QLPanelAnimationDuration", "0", "Quick Look 动画",
            description: "按空格键触发 Quick Look 文件预览时的淡入/淡出动画时间（秒）。设为 0 立即显示/关闭预览窗口。\n修复: defaults write -g QLPanelAnimationDuration -int 0"),

        DefaultsDef("-g", "NSInitialToolTipDelay", "0", "工具提示延迟",
            description: "鼠标悬停在按钮/图标上时显示工具提示（Tooltip）前的等待时间（毫秒）。默认约 750ms，设为 0 立即显示。\n修复: defaults write -g NSInitialToolTipDelay -int 0"),

        DefaultsDef("-g", "com.apple.springing.delay", "0", "弹簧加载延迟",
            description: "拖拽文件到文件夹/Dock 图标上时，自动弹出目标内容的等待时间（秒）。设为 0 立即弹出，提升拖拽操作效率。\n修复: defaults write -g com.apple.springing.delay -int 0"),

        DefaultsDef("NSGlobalDomain", "NSAppSleepDisabled", "1", "App Nap 禁用",
            description: """
禁用 App Nap（防止系统对后台不活跃应用强制降低优先级或暂停执行）。
⚠ 重要: Ollama 本地 LLM 服务、Claude Code 后台任务、MCP 服务器等 AI 工具必须禁用 App Nap，否则可能被意外暂停。
修复: defaults write NSGlobalDomain NSAppSleepDisabled -int 1
取消: defaults write NSGlobalDomain NSAppSleepDisabled -int 0
"""),

        DefaultsDef("-g", "KeyRepeat", "1", "键盘重复速度",
            description: "按住键盘按键后的重复触发速率（值越小越快，范围 1-15，macOS 默认 2）。设为 1 在代码编辑、Vim 键位导航时明显提升效率。\n修复: defaults write -g KeyRepeat -int 1"),

        DefaultsDef("-g", "InitialKeyRepeat", "10", "键盘重复延迟",
            description: "按住按键后触发重复输入的初始延迟（值越小延迟越短，范围 10-120，macOS 默认 15）。设为 10 减少等待感。\n修复: defaults write -g InitialKeyRepeat -int 10"),

        DefaultsDef("com.apple.universalaccess", "reduceMotion", "1", "减少动态效果",
            description: """
减少全屏切换、Notification Center 弹出、App 切换等处的运动动画（Reduce Motion）。
效果：降低视觉疲劳；在低端 GPU 或内存压力大时可提升性能。
【手动操作】macOS 15 Sequoia / 26 Tahoe:
  System Settings → Accessibility → Display → Reduce motion
【命令行无效】com.apple.universalaccess 受 TCC 保护，defaults write 无法修改，必须通过系统设置操作。
"""),

        DefaultsDef("com.apple.universalaccess", "reduceTransparency", "1", "减少透明度",
            description: """
关闭菜单栏、Dock、侧边栏的毛玻璃透明模糊效果（Reduce Transparency）。
效果：显著降低 GPU 渲染负担；界面变为纯色背景，文字对比度更高，可读性更强。
【手动操作】macOS 15 Sequoia / 26 Tahoe:
  System Settings → Accessibility → Display → Reduce transparency
【命令行无效】受 TCC 保护，必须通过系统设置操作。
"""),

        // ── Dock 优化 (15) ───────────────────────────────────────────────
        DefaultsDef("com.apple.dock", "autohide-delay", "0", "Dock 隐藏延迟",
            description: "Dock 自动隐藏时，鼠标移到边缘触发 Dock 出现前的延迟时间（秒）。默认约 0.5 秒，设为 0 立即响应。\n修复: defaults write com.apple.dock autohide-delay -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "autohide-time-modifier", "0", "Dock 隐藏动画",
            description: "Dock 滑入/滑出的动画持续时间倍数（0=无动画，1=默认速度，0.5=快一倍）。设为 0 禁用所有 Dock 出入动画。\n修复: defaults write com.apple.dock autohide-time-modifier -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "launchanim", "0", "启动弹跳动画",
            description: "点击 Dock 图标启动应用时的弹跳动画（图标反复跳动直到应用完全加载）。设为 0/false 禁用弹跳，视觉更简洁。\n修复: defaults write com.apple.dock launchanim -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "magnification", "0", "Dock 放大效果",
            description: "鼠标悬停 Dock 图标时的放大效果。设为 0/false 禁用，节省 GPU 资源，减少 Dock 区域的视觉抖动。\n修复: defaults write com.apple.dock magnification -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "expose-animation-duration", "0.1", "Mission Control 动画",
            description: "Mission Control（三指上滑显示所有窗口）切换动画时间（秒）。默认 0.2 秒，缩短至 0.1 秒明显更流畅。\n修复: defaults write com.apple.dock expose-animation-duration -float 0.1 && killall Dock"),

        DefaultsDef("com.apple.dock", "springboard-show-duration", "0", "Launchpad 显示动画",
            description: "Launchpad 打开时的缩放淡入动画时间（秒）。设为 0 立即显示所有应用图标，无缩放过渡。\n修复: defaults write com.apple.dock springboard-show-duration -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "springboard-hide-duration", "0", "Launchpad 隐藏动画",
            description: "Launchpad 关闭时的淡出动画时间（秒）。设为 0 立即消失，无动画残留。\n修复: defaults write com.apple.dock springboard-hide-duration -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "springboard-page-duration", "0", "Launchpad 翻页动画",
            description: "Launchpad 多页应用之间翻页的滑动动画时间（秒）。设为 0 立即切换页面。\n修复: defaults write com.apple.dock springboard-page-duration -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "mineffect", "scale", "最小化效果",
            description: "窗口最小化到 Dock 的动画效果。scale（缩放）比默认的 genie（精灵灯吸入效果）执行更快、视觉更简洁。\n可选值: scale（推荐）| genie（默认）| suck\n修复: defaults write com.apple.dock mineffect -string scale && killall Dock"),

        DefaultsDef("com.apple.dock", "tilesize", "36", "Dock 图标尺寸",
            description: "Dock 图标大小（像素）。默认 48px，设为 36px 更紧凑，在屏幕上留出更多工作空间。可根据喜好调整（推荐 32-48）。\n修复: defaults write com.apple.dock tilesize -int 36 && killall Dock"),

        DefaultsDef("com.apple.dock", "show-recents", "0", "最近应用",
            description: "隐藏 Dock 末尾的「最近使用的应用程序」分区（分隔线后的动态区域）。减少 Dock 杂乱，只保留你手动固定的应用。\n修复: defaults write com.apple.dock show-recents -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "wvous-tl-corner", "0", "热角-左上",
            description: "鼠标快速移到屏幕左上角时触发的热角操作（0=禁用）。常见误操作：意外触发 Mission Control 或锁屏。\n如需热角功能可设为: 2=Mission Control, 4=桌面, 5=屏幕保护程序, 10=睡眠显示器\n修复: defaults write com.apple.dock wvous-tl-corner -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "wvous-tr-corner", "0", "热角-右上",
            description: "鼠标快速移到屏幕右上角时触发的热角操作（0=禁用）。防止误触发 Notification Center 或 Launchpad。\n修复: defaults write com.apple.dock wvous-tr-corner -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "wvous-bl-corner", "0", "热角-左下",
            description: "鼠标快速移到屏幕左下角时触发的热角操作（0=禁用）。修复: defaults write com.apple.dock wvous-bl-corner -int 0 && killall Dock"),

        DefaultsDef("com.apple.dock", "wvous-br-corner", "0", "热角-右下",
            description: "鼠标快速移到屏幕右下角时触发的热角操作（0=禁用）。修复: defaults write com.apple.dock wvous-br-corner -int 0 && killall Dock"),

        // ── Finder 和其他 (7) ────────────────────────────────────────────
        DefaultsDef("com.apple.finder", "DisableAllAnimations", "1", "Finder 动画",
            description: "禁用 Finder 所有内置动画（文件夹展开收起、侧边栏项目展开、信息面板滑入等）。Finder 操作全部立即响应。\n修复: defaults write com.apple.finder DisableAllAnimations -int 1 && killall Finder"),

        DefaultsDef("com.apple.LaunchServices", "LSQuarantine", "0", "应用确认弹窗",
            description: """
禁用「应用被隔离」弹窗（从互联网下载应用首次运行时的「您确定要打开吗？」安全确认对话框）。
用于开发/测试场景：频繁安装和测试未公证应用时避免重复确认。
⚠ 安全注意: 禁用后需自行判断应用来源的可信度。
修复: defaults write com.apple.LaunchServices LSQuarantine -int 0
取消（恢复安全弹窗）: defaults write com.apple.LaunchServices LSQuarantine -int 1
"""),

        DefaultsDef("com.apple.TimeMachine", "DoNotOfferNewDisksForBackup", "1", "TM 新磁盘提示",
            description: "插入新外置磁盘时，不弹出「是否将此磁盘用于 Time Machine 备份？」询问对话框。避免每次插 U 盘时被打扰。\n修复: defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -int 1"),

        DefaultsDef("com.apple.controlcenter", "NSStatusItem Visible NowPlaying", "0", "NowPlaying 状态栏",
            description: "隐藏菜单栏右侧的「正在播放」媒体控件（NowPlaying 小组件）。节省菜单栏空间，减少视觉干扰。\n修复: defaults write com.apple.controlcenter 'NSStatusItem Visible NowPlaying' -int 0 && killall SystemUIServer"),

        DefaultsDef("NSGlobalDomain", "AppleShowAllExtensions", "1", "显示文件扩展名",
            description: "始终在文件名中显示扩展名（如 document.pdf，而非仅 document）。\n安全价值：防止被双扩展名攻击（如 photo.jpg.app 会显示为 photo.jpg 诱使点击）。\n修复: defaults write NSGlobalDomain AppleShowAllExtensions -int 1 && killall Finder"),

        DefaultsDef("com.apple.finder", "_FXSortFoldersFirst", "1", "文件夹优先排序",
            description: "Finder 按名称排序时，文件夹始终显示在文件前面（类似 Windows Explorer 的排序习惯）。提升目录浏览效率。\n修复: defaults write com.apple.finder _FXSortFoldersFirst -int 1 && killall Finder"),

        DefaultsDef("com.apple.screencapture", "disable-shadow", "1", "截图阴影",
            description: "截图窗口时禁用窗口阴影（默认截图会在窗口周围包含半透明阴影，导致白边和文件体积增大）。\n修复: defaults write com.apple.screencapture disable-shadow -int 1\n立即生效（无需重启）: killall SystemUIServer"),

        // ── 屏保和截图 (2) ───────────────────────────────────────────────
        DefaultsDef("com.apple.screensaver", "idleTime", "0", "屏保空闲时间",
            description: "屏保启动前的系统空闲时间（秒，0=不启动屏保）。服务器/开发机推荐设为 0，防止屏保中断长时间运行的任务。\n修复: defaults write com.apple.screensaver idleTime -int 0\n恢复（10 分钟）: defaults write com.apple.screensaver idleTime -int 600"),

        DefaultsDef("com.apple.screencapture", "type", "png", "截图格式",
            description: "系统截图（Cmd+Shift+3/4/5）保存的文件格式。\n可选值: png（无损，推荐，默认）| jpg（有损压缩，文件更小）| heic（Apple 格式，macOS 11+）| pdf\n修复: defaults write com.apple.screencapture type -string png"),

        // ── Sequoia 专属 (2) ─────────────────────────────────────────────
        DefaultsDef("-g", "NSUseAnimatedFocusRing", "0", "焦点环动画",
            [.sequoia],
            description: "键盘焦点指示器（蓝色聚焦环）出现时的缩放动画。Sequoia 新增的细节动画，设为 0 关闭后焦点环立即显示。\n【仅 macOS 15 Sequoia】修复: defaults write -g NSUseAnimatedFocusRing -int 0"),

        DefaultsDef("-g", "NSDisableAutomaticTermination", "1", "禁止自动终止",
            [.sequoia],
            description: """
禁止 macOS 在内存紧张时自动终止「后台暂停」的应用（Automatic Termination 机制）。
⚠ 重要（Sequoia）: Ollama 服务、本地 AI 模型推理、MCP 服务器等后台进程在 Sequoia 更容易被此机制终止，必须关闭。
【仅 macOS 15 Sequoia】修复: defaults write -g NSDisableAutomaticTermination -int 1
"""),

        // ── Tahoe 专属 (2) ───────────────────────────────────────────────
        DefaultsDef("com.apple.universalaccess", "reduceBlurring", "1", "Liquid Glass 模糊",
            [.tahoe],
            description: """
减少 macOS 26 Tahoe 新增的 Liquid Glass 动态毛玻璃模糊效果（影响窗口、工具栏、侧边栏等大面积 UI 元素）。
效果：明显降低 GPU 连续渲染负担；电池寿命改善约 5-15%（Liquid Glass 效果非常耗电）。
【仅 macOS 26 Tahoe】
【手动操作】System Settings → Accessibility → Display → Reduce transparency / Reduce blurring
【命令行无效】受 TCC 保护，必须通过系统设置操作。
"""),

        DefaultsDef("com.apple.WindowManager", "EnableStandardClickToShowDesktop", "0", "Stage Manager 点击桌面",
            [.tahoe],
            description: """
禁止在 Stage Manager 模式下点击桌面空白区域来隐藏所有窗口（Show Desktop 行为）。
防止意外触发：在 Tahoe 的 Liquid Glass 透明界面中，桌面边缘更难识别，容易误点。
【仅 macOS 26 Tahoe】修复: defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -int 0
恢复: defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -int 1
"""),

        // ── 软件更新 (2) ─────────────────────────────────────────────────
        DefaultsDef("com.apple.SoftwareUpdate", "AutomaticDownload", "0", "自动下载更新",
            description: "禁止 macOS 在后台自动下载软件更新（节省带宽，自行选择合适时机更新）。\n注意：禁用自动下载不影响安全更新的通知，你仍会收到更新提醒，只是需要手动触发下载。\n修复: defaults write com.apple.SoftwareUpdate AutomaticDownload -int 0"),

        DefaultsDef("com.apple.SoftwareUpdate", "AutomaticallyInstallMacOSUpdates", "0", "自动安装更新",
            description: "禁止 macOS 自动安装系统更新并重启（防止在工作时意外重启，丢失未保存内容）。\n服务器/开发机强烈建议关闭，手动选择维护窗口更新。\n修复: defaults write com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -int 0"),
    ]

    /// 根据 macOS 版本筛选适用的 defaults 检查项，自动生成读取命令和修复命令
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        var result: [AuditCheck] = []
        for (i, d) in defs.enumerated() {
            if !d.versions.isEmpty && !d.versions.contains(version) { continue }
            let cmd: String
            // key 含空格时用单引号包裹，避免 defaults 把空格后的词当多余参数
            let quotedKey = d.key.contains(" ") ? "'\(d.key)'" : d.key
            if d.domain == "-g" {
                cmd = "defaults read -g \(quotedKey) 2>/dev/null || echo 'not set'"
            } else {
                cmd = "defaults read \(d.domain) \(quotedKey) 2>/dev/null || echo 'not set'"
            }
            // 自动生成 fixCommand — 根据期望值推断类型
            let fixCmd: String
            let valueType: String
            if d.expected == "true" {
                valueType = "-int 1"
            } else if d.expected == "false" {
                valueType = "-int 0"
            } else if d.expected.contains(".") && Double(d.expected) != nil {
                valueType = "-float \(d.expected)"
            } else if let intVal = Int(d.expected) {
                valueType = "-int \(intVal)"
            } else if d.expected == "scale" || d.expected == "none" || d.expected == "png" {
                valueType = "-string \(d.expected)"
            } else {
                valueType = "-string \(d.expected)"
            }

            if d.domain == "-g" {
                fixCmd = "defaults write -g \(quotedKey) \(valueType)"
            } else if d.domain == "com.apple.universalaccess" {
                // com.apple.universalaccess 受 TCC 保护，defaults write 会失败
                // 需手动在系统设置中操作
                fixCmd = ""
            } else {
                fixCmd = "defaults write \(d.domain) \(quotedKey) \(valueType)"
            }

            // 使用 struct 中的 description（已全部填充）
            let description = d.description

            result.append(AuditCheck(
                id: "m5.\(i)_\(d.key.lowercased().prefix(20))",
                name: d.name,
                module: id,
                description: description,
                command: cmd,
                expected: d.expected,
                versions: d.versions,
                risk: .safe,
                fixRisk: fixCmd.isEmpty ? nil : .low,
                fixCommand: fixCmd.isEmpty ? nil : fixCmd,
                priority: .a2
            ))
        }
        return result
    }

    /// 执行动画优化检查，返回检测结果
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
