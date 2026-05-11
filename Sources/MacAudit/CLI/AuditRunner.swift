// AuditRunner.swift
// 审计执行协调器 — 负责按顺序运行所有 AuditModule，收集并过滤结果，
// 并在交互模式下提供逐模块暂停/跳转功能。

import Foundation
import MacAuditCore

/// 审计执行协调器，串联多个 AuditModule 完成完整的系统审查流程
struct AuditRunner: Sendable {
    /// 待运行的审计模块列表
    let modules: [any AuditModule]
    /// 目标 macOS 版本，nil 时自动检测
    let version: MacOSVersion?
    /// 设备类型（MacBook / iMac 等）
    let device: DeviceType
    /// CPU 架构（arm64 / x86_64）
    let arch: CPUArchitecture
    /// Shell 命令执行器
    let executor: ShellExecutor
    /// 静默模式，不输出进度信息
    let quiet: Bool
    /// 交互模式，每个模块运行后暂停等待用户操作
    let interactive: Bool
    /// 优先级上限，仅运行此优先级及以上的检测项
    let maxPriority: CheckPriority

    /// 初始化审计运行器
    /// - Parameters:
    ///   - modules: 审计模块数组
    ///   - version: macOS 版本，默认自动检测
    ///   - device: 设备类型，默认自动检测
    ///   - arch: CPU 架构，默认自动检测
    ///   - executor: Shell 执行器，默认创建新实例
    ///   - quiet: 是否静默运行
    ///   - interactive: 是否交互模式
    ///   - maxPriority: 优先级上限，默认 .a3（全部）
    init(
        modules: [any AuditModule],
        version: MacOSVersion? = MacOSVersion.detect(),
        device: DeviceType = DeviceType.detect(),
        arch: CPUArchitecture = .detect(),
        executor: ShellExecutor = ShellExecutor(),
        quiet: Bool = false,
        interactive: Bool = false,
        maxPriority: CheckPriority = .a3
    ) {
        self.modules = modules
        self.version = version
        self.device = device
        self.arch = arch
        self.executor = executor
        self.quiet = quiet
        self.interactive = interactive
        self.maxPriority = maxPriority
    }

    /// 按顺序运行所有适用的审计模块，返回全部检测结果
    /// - 交互模式下每个模块运行完毕后会暂停，支持 q/ESC 跳到汇总
    /// - 支持通过 Task.isCancelled 中断执行
    func runAll() async -> [AuditResult] {
        let effectiveVersion = version ?? MacOSVersion.detect() ?? .sequoia
        var allResults: [AuditResult] = []
        var runIndex = 0

        // MARK: - 模块过滤

        let applicableModules: [any AuditModule] = maxPriority < .a3
            ? modules.filter { (m: any AuditModule) in m.checks(for: effectiveVersion, device: device, arch: arch, maxPriority: maxPriority).count > 0 }
            : modules

        // MARK: - 未知版本警告

        if !quiet && version == nil {
            Layout.print(ANSIColor.yellow.wrap(
                "⚠ 未知 macOS 版本 (\(MacOSVersion.versionString))，以 best-effort 模式运行"
            ))
        }

        // MARK: - 优先级过滤提示

        if !quiet && maxPriority < .a3 {
            let skipped = modules.count - applicableModules.count
            if skipped > 0 {
                Layout.print(ANSIColor.dim.wrap("优先级 \(maxPriority.rawValue)+: \(applicableModules.count) 模块，跳过 \(skipped) 模块"))
            }
        }

        // MARK: - 逐模块执行

        for module in applicableModules {
            guard !Task.isCancelled else { break }
            let applicableChecks = module.checks(for: effectiveVersion, device: device, arch: arch, maxPriority: maxPriority)
            let checkCount = applicableChecks.count
            runIndex += 1

            if !quiet {
                if interactive { MenuUI.clearScreen() }
                Layout.print(ANSIColor.bold.wrap("[\(runIndex)/\(applicableModules.count)] \(module.name)"))
                InteractiveUI.printModuleHeader(module, checkCount: checkCount)
            }

            var results = await module.run(
                version: effectiveVersion,
                device: device,
                arch: arch,
                executor: executor
            )

            // MARK: - 结果过滤（按优先级）

            if maxPriority < .a3 {
                let allowedIds = Set(applicableChecks.map { $0.id })
                results = results.filter { allowedIds.contains($0.checkId) }
            }

            // MARK: - 结果输出与交互控制

            if !quiet {
                InteractiveUI.printResultsPaged(results, interactive: interactive)
                InteractiveUI.printModuleSummary(results)

                if interactive {
                    let isLast = runIndex == applicableModules.count
                    Layout.printEmpty()
                    let hint = isLast
                        ? "按 Enter 查看审查汇总..."
                        : "按 Enter 继续下一模块，按 q / ESC 跳到汇总..."
                    Layout.printNoNL(ANSIColor.dim.wrap(hint))
                    if ANSIColor.isTerminal {
                        TerminalInput.enableRawMode()
                        let key = TerminalInput.readKey()
                        TerminalInput.disableRawMode()
                        Layout.printEmpty()
                        if !isLast {
                            if key == .escape || key == .digit(0) {
                                allResults.append(contentsOf: results)
                                break
                            }
                            if case .char(113) = key {
                                allResults.append(contentsOf: results)
                                break
                            }
                        }
                    } else {
                        if !isLast {
                            if let input = readLine(), input.lowercased() == "q" {
                                allResults.append(contentsOf: results)
                                break
                            }
                        } else {
                            _ = readLine()
                        }
                    }
                }
            }
            allResults.append(contentsOf: results)
            if Task.isCancelled { break }
        }

        return allResults
    }

    /// 运行指定 ID 的单个审计模块，返回该模块的检测结果
    /// - Parameter moduleId: 目标模块 ID
    /// - Returns: 检测结果数组，模块不存在时返回 nil
    func runModule(_ moduleId: String) async -> [AuditResult]? {
        let effectiveVersion = version ?? .sequoia
        guard let module = modules.first(where: { $0.id == moduleId }) else {
            return nil
        }
        guard !Task.isCancelled else { return [] }

        let checkCount = module.checks(for: effectiveVersion, device: device, arch: arch, maxPriority: maxPriority).count
        if !quiet { InteractiveUI.printModuleHeader(module, checkCount: checkCount) }

        var results = await module.run(
            version: effectiveVersion,
            device: device,
            arch: arch,
            executor: executor
        )

        if maxPriority < .a3 {
            let allowedIds = Set(module.checks(for: effectiveVersion, device: device, arch: arch, maxPriority: maxPriority).map { $0.id })
            results = results.filter { allowedIds.contains($0.checkId) }
        }

        if !quiet {
            InteractiveUI.printResultsPaged(results, interactive: true)
            InteractiveUI.printModuleSummary(results)
        }
        return results
    }

    /// 统计结果中跨引用的检测项数量（用于摘要展示）
    /// - Parameters:
    ///   - results: 审计结果数组
    ///   - modules: 模块列表
    ///   - version: macOS 版本
    ///   - device: 设备类型
    ///   - arch: CPU 架构
    /// - Returns: 含有 crossRef 的检测项数量
    static func crossRefCount(in results: [AuditResult], modules: [any AuditModule], version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> Int {
        let allChecks = modules.flatMap { $0.checks(for: version, device: device, arch: arch) }
        return allChecks.filter { $0.crossRef != nil }.count
    }
}
