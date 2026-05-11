import Darwin
import Foundation

/// ANSI 终端颜色
enum ANSIColor: Sendable {
    case red, green, yellow, blue, orange, dim, bold, reset

    var code: String {
        switch self {
        case .red:    "\u{001B}[31m"
        case .green:  "\u{001B}[32m"
        case .yellow: "\u{001B}[33m"
        case .blue:   "\u{001B}[34m"
        case .orange: "\u{001B}[38;5;208m"
        case .dim:    "\u{001B}[2m"
        case .bold:   "\u{001B}[1m"
        case .reset:  "\u{001B}[0m"
        }
    }

    /// 是否在终端环境中（支持颜色）
    static let isTerminal: Bool = {
        isatty(STDOUT_FILENO) != 0
    }()

    /// 用颜色包裹文本（非终端环境返回原文）
    func wrap(_ text: String) -> String {
        guard ANSIColor.isTerminal else { return text }
        return "\(code)\(text)\(ANSIColor.reset.code)"
    }
}

/// 统一布局工具 — 左对齐
enum Layout {
    /// 终端实际宽度
    static let terminalWidth: Int = {
        var w = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0, w.ws_col > 0 {
            return Int(w.ws_col)
        }
        return 80
    }()

    /// 内容区宽度 — 最大 100，不超过终端宽度，保证菜单不自动换行
    static let width: Int = min(terminalWidth, 100)

    /// 左边距 — 左对齐，固定为空
    static let margin = ""

    /// 打印一行（带缩进）
    static func print(_ text: String) {
        Swift.print("\(margin)\(text)")
    }

    /// 打印不换行（带缩进）
    static func printNoNL(_ text: String) {
        Swift.print("\(margin)\(text)", terminator: "")
        fflush(stdout)
    }

    /// 空行
    static func printEmpty() {
        Swift.print("")
    }

    /// 水平线
    static func printLine(_ char: Character = "─") {
        print(ANSIColor.dim.wrap(String(repeating: char, count: width)))
    }

    /// 粗水平线
    static func printDoubleLine() {
        print(ANSIColor.bold.wrap(String(repeating: "═", count: width)))
    }

    /// 分组标题线
    static func printSection(_ title: String) {
        let lineLen = max(1, width - displayWidth(title) - 4)
        print(ANSIColor.dim.wrap("── \(title) \(String(repeating: "─", count: lineLen))"))
    }

    /// 框线标题
    static func printBox(_ lines: [String]) {
        let inner = width - 4
        let top = "╔" + String(repeating: "═", count: width - 2) + "╗"
        let bot = "╚" + String(repeating: "═", count: width - 2) + "╝"
        print(ANSIColor.bold.wrap(top))
        for line in lines {
            let dw = displayWidth(line)
            let pad = max(0, inner - dw)
            let left = pad / 2
            let right = pad - left
            let padded = String(repeating: " ", count: left) + line + String(repeating: " ", count: right)
            print(ANSIColor.bold.wrap("║ \(padded) ║"))
        }
        print(ANSIColor.bold.wrap(bot))
    }

    /// 信息框（细线）
    static func printInfoBox(_ lines: [String]) {
        let inner = width - 4
        let top = "┌" + String(repeating: "─", count: width - 2) + "┐"
        let bot = "└" + String(repeating: "─", count: width - 2) + "┘"
        print(ANSIColor.dim.wrap(top))
        for line in lines {
            let dw = displayWidth(line)
            let pad = max(0, inner - dw)
            print("│ \(line)\(String(repeating: " ", count: pad)) │")
        }
        print(ANSIColor.dim.wrap(bot))
    }

    /// 计算字符串显示宽度（中文/全角=2，ASCII=1）
    static func displayWidth(_ str: String) -> Int {
        var w = 0
        for scalar in str.unicodeScalars {
            let v = scalar.value
            if (v >= 0x1100 && v <= 0x115F) ||
               (v >= 0x2E80 && v <= 0xA4CF && v != 0x303F) ||
               (v >= 0xAC00 && v <= 0xD7A3) ||
               (v >= 0xF900 && v <= 0xFAFF) ||
               (v >= 0xFE10 && v <= 0xFE6F) ||
               (v >= 0xFF01 && v <= 0xFF60) ||
               (v >= 0xFFE0 && v <= 0xFFE6) ||
               (v >= 0x20000 && v <= 0x2FA1F) ||
               // macOS 终端中渲染为2宽的符号字符（✗ ✓ ✘ ✔ 等杂项符号）
               (v >= 0x2600 && v <= 0x27FF) {
                w += 2
            } else {
                w += 1
            }
        }
        return w
    }
}
