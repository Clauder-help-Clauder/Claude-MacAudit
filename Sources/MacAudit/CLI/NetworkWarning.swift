// NetworkWarning.swift
// 网络断开警告系统 — 在执行可能断开网络的修复操作前，
// 显示全屏警告、建议恢复方法，并要求输入 CONFIRM 确认。

import Foundation

/// 网络断开警告系统，用于高风险修复操作前的安全提示
struct NetworkWarning: Sendable {

    /// 可能导致网络断开的命令关键词列表
    private static let networkRiskPatterns = [
        "mDNSResponder",
        "networksetup",
        "ifconfig",
        "route",
        "pfctl",
        "socketfilterfw",
        "ipfw",
        "scutil",
        "dns",
        "setv6off",
        "setv6automatic",
        "flush",
        "killall -HUP mDNSResponder",
        "dscacheutil -flushcache",
    ]

    /// 检查命令是否包含网络风险关键词
    /// - Parameter command: 待检查的 shell 命令
    /// - Returns: 是否存在网络风险
    static func isNetworkRisk(_ command: String) -> Bool {
        let lower = command.lowercased()
        return networkRiskPatterns.contains { lower.contains($0.lowercased()) }
    }

    /// 显示网络断开全屏警告框，包含命令详情和恢复建议
    /// - Parameter action: 待执行的修复操作
    static func showWarning(for action: FixAction) {
        let width = 60
        let border = String(repeating: "█", count: width)
        let inner = String(repeating: " ", count: width - 4)

        Layout.printEmpty()
        Layout.print(ANSIColor.red.wrap(border))
        Layout.print(ANSIColor.red.wrap("██\(inner)██"))
        Layout.print(ANSIColor.red.wrap("██") + centerText("⚠  网 络 断 开 警 告  ⚠", width: width - 4) + ANSIColor.red.wrap("██"))
        Layout.print(ANSIColor.red.wrap("██\(inner)██"))
        Layout.print(ANSIColor.red.wrap(border))
        Layout.printEmpty()
        Layout.print(ANSIColor.red.wrap("  此操作可能导致您的网络连接中断！"))
        Layout.printEmpty()
        Layout.print("  命令: \(ANSIColor.bold.wrap(action.command))")
        Layout.print("  操作: \(action.name)")
        Layout.printEmpty()
        Layout.print(ANSIColor.red.wrap("  警告:"))
        Layout.print(ANSIColor.red.wrap("    - 执行后可能无法访问网络"))
        Layout.print(ANSIColor.red.wrap("    - 远程连接（SSH）可能断开"))
        Layout.print(ANSIColor.red.wrap("    - 建议先记录恢复命令"))
        Layout.printEmpty()

        // MARK: - 显示恢复建议

        let recovery = suggestRecovery(for: action.command)
        if !recovery.isEmpty {
            Layout.print(ANSIColor.yellow.wrap("  恢复命令:"))
            for cmd in recovery {
                Layout.print(ANSIColor.yellow.wrap("    \(cmd)"))
            }
            Layout.printEmpty()
        }

        Layout.print(ANSIColor.red.wrap(border))
        Layout.printEmpty()
    }

    /// 要求用户输入 CONFIRM（区分大小写）确认执行高风险操作
    /// - Returns: 是否确认
    static func requireConfirmation() -> Bool {
        Layout.printNoNL(ANSIColor.red.wrap("输入 CONFIRM 确认执行（区分大小写）: "))
        guard let input = readLine(), input == "CONFIRM" else {
            Layout.print(ANSIColor.yellow.wrap("  已取消"))
            return false
        }
        return true
    }

    /// 根据命令内容建议恢复方法（internal 供测试使用）
    /// - Parameter command: 修复命令
    /// - Returns: 恢复命令字符串数组
    static func suggestRecovery(for command: String) -> [String] {
        var recovery: [String] = []
        let lower = command.lowercased()

        if lower.contains("setv6off") {
            recovery.append("sudo networksetup -setv6automatic \"Wi-Fi\"")
        }
        if lower.contains("mdnsresponder") || lower.contains("flushcache") {
            recovery.append("# DNS 缓存会自动重建，通常无需操作")
        }
        if lower.contains("socketfilterfw") {
            recovery.append("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off")
        }
        if lower.contains("pfctl") {
            recovery.append("sudo pfctl -d  # 禁用 pf 防火墙")
        }
        if lower.contains("networksetup") && lower.contains("proxy") {
            recovery.append("sudo networksetup -setwebproxystate \"Wi-Fi\" off")
        }

        if recovery.isEmpty {
            recovery.append("# 如果网络断开，请重启网络接口或重启系统")
        }
        return recovery
    }

    /// 将文本在指定宽度内居中
    /// - Parameters:
    ///   - text: 原始文本
    ///   - width: 目标宽度
    /// - Returns: 居中后的文本
    private static func centerText(_ text: String, width: Int) -> String {
        let textLen = text.count
        guard textLen < width else { return text }
        let padding = (width - textLen) / 2
        return String(repeating: " ", count: padding) + text
            + String(repeating: " ", count: width - textLen - padding)
    }
}
