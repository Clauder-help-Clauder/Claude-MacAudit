// TerminalInput.swift — 终端原始模式输入处理，提供按键读取、raw mode 切换及 ANSI 光标控制

import Darwin
import Foundation

/// 按键类型
enum KeyPress: Equatable {
    /// 上方向键
    case up
    /// 下方向键
    case down
    /// 回车键
    case enter
    /// 数字键 0-9
    case digit(Int)
    /// ESC 键
    case escape
    /// 其他字符
    case char(UInt8)
}

/// 终端原始模式输入
struct TerminalInput {
    /// 原始终端属性，用于恢复
    nonisolated(unsafe) private static var originalTermios = termios()
    /// 是否处于 raw mode
    nonisolated(unsafe) private static var isRawMode = false

    /// 进入 raw mode
    static func enableRawMode() {
        guard !isRawMode else { return }
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        // 关闭 canonical mode 和 echo
        raw.c_lflag &= ~UInt(ICANON | ECHO)
        // 最少读 1 字节，超时 0（立即返回）
        raw.c_cc.16 = 1  // VMIN
        raw.c_cc.17 = 0  // VTIME
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRawMode = true
    }

    /// 恢复终端
    static func disableRawMode() {
        guard isRawMode else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawMode = false
    }

    /// 读取一个字节
    private static func readByte() -> UInt8? {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        return n == 1 ? byte : nil
    }

    /// 尝试非阻塞读取（用于 ESC 序列后续字节）
    private static func readByteNonBlocking() -> UInt8? {
        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)
        let savedMin = raw.c_cc.16
        let savedTime = raw.c_cc.17
        raw.c_cc.16 = 0   // VMIN = 0
        raw.c_cc.17 = 1   // VTIME = 0.1s
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)

        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)

        raw.c_cc.16 = savedMin
        raw.c_cc.17 = savedTime
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)

        return n == 1 ? byte : nil
    }

    /// 读取一个按键（阻塞）
    static func readKey() -> KeyPress {
        guard let byte = readByte() else { return .char(0) }

        switch byte {
        case 10, 13: // LF, CR
            return .enter
        case 27: // ESC
            // 检查是否是方向键序列 ESC [ A/B/C/D
            guard let bracket = readByteNonBlocking(), bracket == 91 else {
                return .escape
            }
            guard let arrow = readByteNonBlocking() else {
                return .escape
            }
            switch arrow {
            case 65: return .up
            case 66: return .down
            default: return .char(arrow)
            }
        case 48...57: // 0-9
            return .digit(Int(byte - 48))
        case 113: // 'q'
            return .escape
        default:
            return .char(byte)
        }
    }

    // MARK: - ANSI 光标控制

    /// 隐藏光标
    static func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
        fflush(stdout)
    }

    /// 显示光标
    static func showCursor() {
        print("\u{001B}[?25h", terminator: "")
        fflush(stdout)
    }

    /// 光标上移 n 行
    static func cursorUp(_ n: Int) {
        if n > 0 {
            print("\u{001B}[\(n)A", terminator: "")
            fflush(stdout)
        }
    }

    /// 清除当前行
    static func clearLine() {
        print("\u{001B}[2K\r", terminator: "")
        fflush(stdout)
    }
}
