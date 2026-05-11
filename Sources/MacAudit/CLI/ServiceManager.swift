// ServiceManager.swift
// 交互式服务管理 — 提供终端全屏界面管理 launchd 系统服务，
// 支持按分组浏览、Space 切换禁用/启用状态、Enter 批量执行。

import Foundation
import MacAuditCore

/// 交互式服务管理器，管理 launchd 系统服务的启用/禁用状态
struct ServiceManager: Sendable {

    // MARK: - 获取当前服务禁用状态

    /// 通过 launchctl print-disabled 获取当前用户域下的服务禁用状态
    /// - Parameter executor: Shell 执行器
    /// - Returns: 服务名到状态字符串的映射
    static func fetchStatus(executor: ShellExecutor) async -> [String: String] {
        let result = await executor.run("launchctl print-disabled gui/$(id -u) 2>/dev/null")
        var map: [String: String] = [:]
        for line in result.trimmedOutput.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("=>") else { continue }
            let parts = trimmed.components(separatedBy: "=>")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                let val = parts[1].trimmingCharacters(in: .whitespaces)
                map[key] = val
            }
        }
        return map
    }

    // MARK: - 主界面

    /// 运行服务管理主界面，提供分组选择和状态显示
    /// - Parameter executor: Shell 执行器
    static func run(executor: ShellExecutor) async {
        let module = ServicesModule()
        let version = MacOSVersion.detect() ?? .sequoia
        let allServices = module.servicesForManagement(version: version, arch: CPUArchitecture.detect())

        // MARK: - 按分组聚合

        var groupOrder: [String] = []
        var groupMap: [String: [ServicesModule.ServiceDef]] = [:]
        for svc in allServices {
            if groupMap[svc.group] == nil {
                groupOrder.append(svc.group)
                groupMap[svc.group] = []
            }
            groupMap[svc.group]!.append(svc)
        }

        var statusMap = await fetchStatus(executor: executor)

        while true {
            MenuUI.clearScreen()
            Layout.print(ANSIColor.bold.wrap("  ══════════════════════════════════════════════"))
            Layout.print(ANSIColor.bold.wrap("  服务管理"))
            Layout.print(ANSIColor.bold.wrap("  ══════════════════════════════════════════════\n"))
            Layout.print(ANSIColor.yellow.wrap("  ⚠ 禁用操作标记服务下次启动不再运行"))
            Layout.print(ANSIColor.dim.wrap("    当前已运行的服务需要重启电脑后才会完全停止"))
            Layout.printEmpty()

            let groupItems = groupOrder.map { grp -> MenuItem in
                let svcs = groupMap[grp] ?? []
                let disabled = svcs.filter { statusMap[$0.name] == "disabled" }.count
                let total = svcs.count
                let status = disabled == total
                    ? ANSIColor.green.wrap("全部已禁用")
                    : disabled == 0
                        ? ANSIColor.red.wrap("全部运行中")
                        : ANSIColor.yellow.wrap("\(disabled)/\(total) 已禁用")
                return MenuItem(grp, status, .green)
            }

            let choice = MenuUI.interactiveSelect(items: groupItems, exitLabel: "返回主菜单")
            guard choice > 0 else { return }

            let selectedGroup = groupOrder[choice - 1]
            let svcs = groupMap[selectedGroup] ?? []
            await toggleGroup(name: selectedGroup, services: svcs, statusMap: &statusMap, executor: executor)
        }
    }

    // MARK: - Toggle 分组界面

    /// 分组详情界面，支持 Space 切换单项、Enter 批量执行、ESC 取消
    /// - Parameters:
    ///   - name: 分组名称
    ///   - services: 该分组下的服务定义列表
    ///   - statusMap: 当前服务状态映射（inout，执行后更新）
    ///   - executor: Shell 执行器
    private static func toggleGroup(
        name: String,
        services: [ServicesModule.ServiceDef],
        statusMap: inout [String: String],
        executor: ShellExecutor
    ) async {
        var selected = 0
        var pending = Set<Int>()  // 记录待切换的索引

        /// 获取指定索引服务的当前状态
        func currentStatus(_ idx: Int) -> String {
            statusMap[services[idx].name] ?? "unmanaged"
        }

        /// 计算切换后的有效禁用状态（考虑 pending 集合的翻转效果）
        func effectiveDisabled(_ idx: Int) -> Bool {
            let isDisabled = currentStatus(idx) == "disabled"
            return pending.contains(idx) ? !isDisabled : isDisabled
        }

        /// 绘制当前分组的服务列表和操作提示
        /// - Returns: 绘制的行数
        func drawMenu() -> Int {
            var lines = 0
            let shortName = { (svc: ServicesModule.ServiceDef) in
                svc.name.replacingOccurrences(of: "com.apple.", with: "")
            }
            let maxW = Layout.terminalWidth - 1

            for (i, svc) in services.enumerated() {
                TerminalInput.clearLine()
                let isDisabled = effectiveDisabled(i)
                let isPending = pending.contains(i)
                let status = currentStatus(i)

                let badge: String
                if isPending {
                    // 待切换：用特殊颜色预览
                    badge = isDisabled
                        ? ANSIColor.green.wrap("[→禁用]")
                        : ANSIColor.orange.wrap("[→启用]")
                } else {
                    badge = status == "disabled"
                        ? ANSIColor.green.wrap("[已禁用]")
                        : status == "enabled"
                            ? ANSIColor.red.wrap("[运行中]")
                            : ANSIColor.yellow.wrap("[未管理]")
                }

                let hint = ANSIColor.dim.wrap(svc.hint)
                let svcName = shortName(svc)
                let isSelected = i == selected

                if isSelected {
                    let content = " ▶ \(badge) \(svcName)  \(svc.hint)"
                    let visible = content.prefix(maxW)
                    Swift.print("\u{001B}[7m\(visible)\u{001B}[27m")
                } else {
                    Swift.print("   \(badge) \(svcName)  \(hint)")
                }
                lines += 1
            }

            TerminalInput.clearLine()
            Swift.print("")
            lines += 1

            TerminalInput.clearLine()
            let pendingCount = pending.count
            let hint = pendingCount > 0
                ? ANSIColor.yellow.wrap("待操作 \(pendingCount) 项 | ")
                : ""
            Swift.print(ANSIColor.dim.wrap("\(hint)↑↓移动  Space切换  Enter保存  ESC取消"))
            lines += 1

            fflush(stdout)
            return lines
        }

        TerminalInput.enableRawMode()
        TerminalInput.hideCursor()

        // MARK: - 进入备用屏幕缓冲区

        // 独占全屏，光标定位稳定
        Swift.print("\u{001B}[?1049h\u{001B}[H\u{001B}[2J", terminator: "")
        fflush(stdout)

        defer {
            Swift.print("\u{001B}[?1049l", terminator: "")
            fflush(stdout)
            TerminalInput.showCursor()
            TerminalInput.disableRawMode()
        }

        Layout.print(ANSIColor.bold.wrap("  \(name)"))
        Layout.printLine()
        Layout.printEmpty()

        _ = drawMenu()

        while true {
            let key = TerminalInput.readKey()
            switch key {
            case .up:
                selected = (selected - 1 + services.count) % services.count
            case .down:
                selected = (selected + 1) % services.count
            case .char(32):  // Space — toggle
                if pending.contains(selected) {
                    pending.remove(selected)
                } else {
                    pending.insert(selected)
                }
            case .enter:
                // 执行待操作
                if !pending.isEmpty {
                    Layout.printEmpty()
                    for idx in pending.sorted() {
                        let svc = services[idx]
                        let shouldDisable = currentStatus(idx) != "disabled"
                        if shouldDisable {
                            let cmd = "launchctl bootout gui/$(id -u)/\(svc.name) 2>/dev/null; launchctl disable gui/$(id -u)/\(svc.name)"
                            _ = await executor.run(cmd)
                            Layout.print(ANSIColor.green.wrap("  ✓ 已禁用 \(svc.name.replacingOccurrences(of: "com.apple.", with: ""))"))
                        } else {
                            let cmd = "launchctl enable gui/$(id -u)/\(svc.name)"
                            _ = await executor.run(cmd)
                            Layout.print(ANSIColor.yellow.wrap("  ✓ 已启用 \(svc.name.replacingOccurrences(of: "com.apple.", with: ""))（重启后生效）"))
                        }
                    }
                    statusMap = await fetchStatus(executor: executor)
                    MenuUI.waitForReturn()
                }
                return
            case .escape:
                return  // ESC 取消，不执行任何操作
            default:
                continue
            }
            // 恢复光标位置 + 清除下方 — 干净重绘
            Swift.print("\u{001B}8\u{001B}[J", terminator: "")
            fflush(stdout)
            _ = drawMenu()
        }
    }
}
