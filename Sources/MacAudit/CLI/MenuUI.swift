// MenuUI.swift
// 菜单 UI — 提供终端全屏交互式菜单（备用屏幕缓冲区 + 原始模式键盘输入），
// 支持 vim 风格上下选择、数字跳转、分组标题，以及非终端环境的 fallback 输入。

import Foundation
#if canImport(Darwin)
import Darwin
#endif

// Module-level state for SIGINT handler (C function pointers cannot capture context).
nonisolated(unsafe) private var _menuSIGINTRestore = false
nonisolated(unsafe) private var _menuSavedTermios = termios()

/// 菜单项定义
struct MenuItem: Sendable {
    /// 菜单项标题
    let label: String
    /// 菜单项描述文字
    let description: String
    /// 标题颜色
    let color: ANSIColor

    /// 初始化菜单项
    /// - Parameters:
    ///   - label: 标题文本
    ///   - desc: 描述文本
    ///   - color: 标题 ANSI 颜色
    init(_ label: String, _ desc: String = "", _ color: ANSIColor = .green) {
        self.label = label; self.description = desc; self.color = color
    }
}

/// 菜单 UI 组件，提供全屏交互式选择器和通用 UI 辅助方法
struct MenuUI: Sendable {

    /// 清除终端屏幕并将光标移到左上角
    static func clearScreen() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
    }

    /// 显示顶部横幅（版本号、系统信息、设备类型）
    /// - Parameters:
    ///   - version: macOS 版本
    ///   - device: 设备类型
    ///   - sysInfo: 系统快照信息（可选）
    static func showBanner(version: MacOSVersion?, device: DeviceType, sysInfo: SystemSnapshot? = nil) {
        let ver = version?.displayName ?? "未知"
        let verStr = MacOSVersion.versionString

        Layout.printEmpty()
        Layout.printBox([
            "MacAudit v0.3.1",
            "Mac 系统审查工具",
        ])
        Layout.printEmpty()

        if let info = sysInfo {
            Layout.printInfoBox([
                "主机: \(info.hostname)",
                "系统: \(ver) (\(verStr))",
                "型号: \(info.model)",
                "芯片: \(info.chip)",
                "内存: \(info.memory)",
                "磁盘: \(info.disk) 可用",
                "类型: \(device.displayName)",
            ])
        } else {
            Layout.print("系统: \(ver) (\(verStr)) | \(device.displayName)")
        }
        Layout.printEmpty()
    }

    // MARK: - 交互式选择器

    /// 交互式菜单选择器，支持上下方向键、数字跳转、ESC 退出
    /// - Parameters:
    ///   - items: 菜单项数组
    ///   - groups: 分组定义数组，每个元素为 (起始索引, 分组标题)
    ///   - exitLabel: 退出选项的显示文字
    /// - Returns: 选中项的序号（1-based），0 表示退出
    static func interactiveSelect(
        items: [MenuItem],
        groups: [(Int, String)] = [],
        exitLabel: String = "退出"
    ) -> Int {
        guard ANSIColor.isTerminal else {
            return fallbackSelect(items: items, groups: groups, exitLabel: exitLabel)
        }

        var selected = 0
        let total = items.count + 1

        // Capture original termios before entering raw mode so the SIGINT
        // handler can restore it without accessing TerminalInput internals.
        tcgetattr(STDIN_FILENO, &_menuSavedTermios)
        _menuSIGINTRestore = true

        // SIGINT handler: restore terminal before exit so Ctrl+C doesn't leave
        // the terminal in raw mode with alt screen and hidden cursor.
        signal(SIGINT) { _ in
            if _menuSIGINTRestore {
                // Leave alt screen
                _ = Darwin.write(STDOUT_FILENO, "\u{001B}[?1049l", 8)
                // Show cursor
                _ = Darwin.write(STDOUT_FILENO, "\u{001B}[?25h", 6)
                // Restore original termios
                tcsetattr(STDIN_FILENO, TCSAFLUSH, &_menuSavedTermios)
            }
            _Exit(130)
        }

        TerminalInput.enableRawMode()
        TerminalInput.hideCursor()

        // 进入备用屏幕 (\e[?1049h) — 像 vim/less 那样独占全屏
        // 这样菜单绘制不会被终端 scroll buffer 干扰，光标定位稳定
        // 退出时自动恢复原终端内容
        Swift.print("\u{001B}[?1049h\u{001B}[H\u{001B}[2J", terminator: "")
        fflush(stdout)

        defer {
            _menuSIGINTRestore = false
            Swift.print("\u{001B}[?1049l", terminator: "")
            fflush(stdout)
            TerminalInput.showCursor()
            TerminalInput.disableRawMode()
        }

        _ = drawMenu(items: items, groups: groups, exitLabel: exitLabel, selected: selected)

        while true {
            let key = TerminalInput.readKey()

            switch key {
            case .up:
                selected = (selected - 1 + total) % total
            case .down:
                selected = (selected + 1) % total
            case .enter:
                if selected == items.count { return 0 }
                return selected + 1
            case .digit(let n):
                if n == 0 {
                    return 0
                }
                if n >= 1 && n <= items.count {
                    return n
                }
                continue
            case .escape:
                return 0
            default:
                continue
            }

            // 光标回 (1,1) + 清空当前屏幕内容 — 备用屏幕不会滚动，绝对干净
            Swift.print("\u{001B}[H\u{001B}[2J", terminator: "")
            fflush(stdout)
            _ = drawMenu(items: items, groups: groups, exitLabel: exitLabel, selected: selected)
        }
    }

    /// 绘制菜单内容到终端，返回占用的行数
    /// - Parameters:
    ///   - items: 菜单项数组
    ///   - groups: 分组定义
    ///   - exitLabel: 退出选项文字
    ///   - selected: 当前选中索引（0-based）
    /// - Returns: 绘制的行数
    @discardableResult
    private static func drawMenu(
        items: [MenuItem],
        groups: [(Int, String)],
        exitLabel: String,
        selected: Int
    ) -> Int {
        Swift.print("\u{001B}[H\u{001B}[2J", terminator: "")
        fflush(stdout)
        var lines = 0
        let groupMap = Dictionary(uniqueKeysWithValues: groups)
        let m = Layout.margin
        let maxW = Layout.terminalWidth - 1  // 留 1 字符防止终端自动换行

        TerminalInput.clearLine()
        Swift.print("\(m)\(ANSIColor.dim.wrap("MacAudit v0.3.1 | https://github.com/Clauder-help-Clauder/Claude-MacAudit"))")
        lines += 1
        TerminalInput.clearLine()
        Swift.print("")
        lines += 1

        // 截断字符串到显示宽度上限（不计 ANSI 码）
        func clip(_ s: String, max: Int) -> String {
            var w = 0
            var result = ""
            for ch in s {
                let chW = Layout.displayWidth(String(ch))
                if w + chW > max { break }
                result.append(ch)
                w += chW
            }
            return result
        }

        for (i, item) in items.enumerated() {
            if let title = groupMap[i] {
                TerminalInput.clearLine()
                let lineLen = max(1, Layout.width - title.count - 4)
                Swift.print("\(m)\(ANSIColor.dim.wrap("── \(title) " + String(repeating: "─", count: lineLen)))")
                lines += 1
            }

            TerminalInput.clearLine()
            let num = String(format: "%2d", i + 1)
            let isSelected = (i == selected)

            if isSelected {
                let content = " ▶ \(num). \(item.label)  \(item.description) "
                Swift.print("\(m)\u{001B}[7m\(clip(content, max: maxW))\u{001B}[27m")
            } else {
                let content = "  \(num). \(item.label)  \(item.description)"
                Swift.print("\(m)  \(item.color.wrap("\(num)."))\(clip(" \(item.label)  ", max: maxW - 6))  \(ANSIColor.dim.wrap(clip(item.description, max: 30)))")
                _ = content  // suppress warning
            }
            lines += 1
        }

        TerminalInput.clearLine()
        Swift.print("")
        lines += 1

        TerminalInput.clearLine()
        let isExitSelected = (selected == items.count)
        if isExitSelected {
            Swift.print("\(m)\u{001B}[7m ▶  0. \(exitLabel) \u{001B}[27m")
        } else {
            Swift.print("\(m)  \(ANSIColor.red.wrap("0.")) \(exitLabel)")
        }
        lines += 1

        TerminalInput.clearLine()
        Swift.print("\(m)\(ANSIColor.dim.wrap("↑↓ 选择  Enter 确认  数字跳转  ESC/q 退出"))")
        lines += 1

        fflush(stdout)
        return lines
    }

    /// 非终端环境的 fallback 选择器，通过 readLine 读取数字选择
    /// - Parameters:
    ///   - items: 菜单项数组
    ///   - groups: 分组定义
    ///   - exitLabel: 退出选项文字
    /// - Returns: 选中项序号（1-based），0 表示退出
    private static func fallbackSelect(
        items: [MenuItem],
        groups: [(Int, String)],
        exitLabel: String
    ) -> Int {
        let groupMap = Dictionary(uniqueKeysWithValues: groups)
        for (i, item) in items.enumerated() {
            if let title = groupMap[i] {
                Layout.printSection(title)
            }
            let num = String(format: "%2d", i + 1)
            Layout.print("\(num). \(item.label)  \(item.description)")
        }
        Layout.print(" 0. \(exitLabel)")
        return readChoiceFallback(prompt: "\(Layout.margin)请选择 [0-\(items.count)]: ", max: items.count)
    }

    /// 通用数字选择 fallback，循环读取直到输入合法
    /// - Parameters:
    ///   - prompt: 提示文字
    ///   - max: 最大可选数字
    /// - Returns: 用户选择的数字
    static func readChoiceFallback(prompt: String, max: Int) -> Int {
        while true {
            Swift.print(prompt, terminator: "")
            guard let line = readLine(), let num = Int(line), num >= 0, num <= max else {
                Layout.print(ANSIColor.red.wrap("无效输入"))
                continue
            }
            return num
        }
    }

    /// 读取文件路径输入，支持默认值
    /// - Parameters:
    ///   - prompt: 提示文字
    ///   - defaultPath: 默认路径
    /// - Returns: 用户输入的路径或默认路径
    static func readPath(prompt: String, defaultPath: String) -> String {
        Layout.printNoNL("\(prompt) [\(defaultPath)]: ")
        guard let line = readLine(), !line.isEmpty else {
            return defaultPath
        }
        return line
    }

    /// 等待用户按 Enter / Space / ESC 后返回（终端环境使用 raw mode）
    static func waitForReturn() {
        Layout.printEmpty()
        Layout.printNoNL(ANSIColor.dim.wrap("按 Enter / Space / ESC 返回..."))
        fflush(stdout)
        if ANSIColor.isTerminal {
            TerminalInput.enableRawMode()
            while true {
                let key = TerminalInput.readKey()
                switch key {
                case .enter, .char(32), .escape:
                    TerminalInput.disableRawMode()
                    Layout.printEmpty()
                    return
                default:
                    continue
                }
            }
        } else {
            _ = readLine()
        }
    }
}
