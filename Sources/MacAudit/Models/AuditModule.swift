// AuditModule.swift — 审计模块协议及默认实现，提供检查项过滤、串行/并行检测执行逻辑

import Foundation
import MacAuditCore
import os

/// 线程安全的进度计数器，基于 OSAllocatedUnfairLock
final class ProgressCounter: @unchecked Sendable {
    private let _lock = OSAllocatedUnfairLock(initialState: 0)

    /// 原子递增并返回递增后的值
    func increment() -> Int {
        _lock.withLock { state in
            state += 1
            return state
        }
    }
}

/// 审计模块协议 — 每个模块实现此协议
protocol AuditModule: Sendable {
    /// 模块标识（如 "security"）
    var id: String { get }

    /// 模块显示名称（如 "安全机制"）
    var name: String { get }

    /// 模块描述
    var description: String { get }

    /// 返回此模块的所有检查项（按版本和设备类型过滤后）
    func checks(
        for version: MacOSVersion,
        device: DeviceType,
        arch: CPUArchitecture
    ) -> [AuditCheck]

    /// 执行所有检测
    func run(
        version: MacOSVersion,
        device: DeviceType,
        arch: CPUArchitecture,
        executor: ShellExecutor
    ) async -> [AuditResult]
}

extension AuditModule {
    /// 模块描述，默认为空字符串
    var description: String { "" }

    /// 延迟执行的检查项，默认为空
    var deferredChecks: [AuditCheck] { [] }

    /// 按优先级上限过滤检查项
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, maxPriority: CheckPriority) -> [AuditCheck] {
        checks(for: version, device: device, arch: arch).filter { $0.priority <= maxPriority }
    }

    /// 过滤后的检查项数量
    func checkCount(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> Int {
        checks(for: version, device: device, arch: arch).count
    }

    /// 通用检测执行逻辑：逐个执行检查项，比对期望值
    func runChecks(
        _ allChecks: [AuditCheck],
        executor: ShellExecutor,
        moduleName: String? = nil
    ) async -> [AuditResult] {
        var results: [AuditResult] = []
        let total = allChecks.count
        let showProgress = moduleName != nil

        for (i, check) in allChecks.enumerated() {
            if let name = moduleName {
                InteractiveUI.updateProgress(module: name, current: i, total: total)
            }
            let start = ContinuousClock.now
            let shellResult = await executor.run(check.detectionCommand)
            let elapsed = ContinuousClock.now - start
            let ms = Int(elapsed.components.seconds * 1000
                         + elapsed.components.attoseconds / 1_000_000_000_000_000)
            let actualRaw = shellResult.trimmedOutput
            let actual = DefaultsNormalizer.normalize(actualRaw, expected: check.expectedValue)

            if shellResult.timedOut {
                results.append(.error(check: check, error: "超时", duration: ms))
                continue
            }

            if actual == "pmset_not_found" {
                results.append(.info(check: check, actual: "硬件不支持（pmset 无此 key）", duration: ms))
                continue
            }

            if let expected = check.expectedValue {
                if actual.lowercased() == expected.lowercased() {
                    results.append(.pass(check: check, actual: actualRaw, duration: ms))
                } else {
                    results.append(.fail(check: check, actual: actualRaw, duration: ms))
                }
            } else {
                results.append(.info(check: check, actual: actual.isEmpty ? "N/A" : actual, duration: ms))
            }
        }
        if showProgress {
            if let name = moduleName {
                InteractiveUI.updateProgress(module: name, current: total, total: total)
                InteractiveUI.clearProgress()
            }
        }
        return results
    }

    /// 并行检测执行：所有检查项同时运行（适用于独立命令如 M11）
    func runChecksParallel(
        _ allChecks: [AuditCheck],
        executor: ShellExecutor,
        moduleName: String? = nil,
        perCheckTimeout: Duration? = nil
    ) async -> [AuditResult] {
        let total = allChecks.count
        let showProgress = moduleName != nil
        let counter = ProgressCounter()

        return await withTaskGroup(of: (Int, AuditResult).self) { group in
            for (index, check) in allChecks.enumerated() {
                group.addTask {
                    let start = ContinuousClock.now
                    let shellResult = await executor.run(check.detectionCommand, timeout: perCheckTimeout)
                    let elapsed = ContinuousClock.now - start
                    let ms = Int(elapsed.components.seconds * 1000
                                 + elapsed.components.attoseconds / 1_000_000_000_000_000)
                    let actualRaw = shellResult.trimmedOutput
                    let actual = DefaultsNormalizer.normalize(actualRaw, expected: check.expectedValue)

                    if showProgress {
                        let c = counter.increment()
                        if let name = moduleName {
                            InteractiveUI.updateProgress(module: name, current: c, total: total)
                        }
                    }

                    if shellResult.timedOut {
                        return (index, .error(check: check, error: "超时", duration: ms))
                    }
                    if actual == "pmset_not_found" {
                        return (index, .info(check: check, actual: "硬件不支持（pmset 无此 key）", duration: ms))
                    }
                    if let expected = check.expectedValue {
                        if actual.lowercased() == expected.lowercased() {
                            return (index, .pass(check: check, actual: actualRaw, duration: ms))
                        } else {
                            return (index, .fail(check: check, actual: actualRaw, duration: ms))
                        }
                    } else {
                        return (index, .info(check: check, actual: actualRaw.isEmpty ? "N/A" : actualRaw, duration: ms))
                    }
                }
            }
            var indexed: [(Int, AuditResult)] = []
            for await pair in group {
                indexed.append(pair)
            }
            if showProgress { InteractiveUI.clearProgress() }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
