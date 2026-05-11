import Foundation
import os

/// 线程安全的进度计数器
public final class ProgressCounter: @unchecked Sendable {
    private let _lock = OSAllocatedUnfairLock(initialState: 0)

    public func increment() -> Int {
        _lock.withLock { state in
            state += 1
            return state
        }
    }
}

/// 进度回调类型 — GUI 层注入，CLI 层忽略
public typealias ProgressHandler = @Sendable (String, Int, Int) -> Void

/// 审计模块协议 — 每个模块实现此协议
public protocol AuditModule: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck]
    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult]
}

public extension AuditModule {
    var description: String { "" }

    var deferredChecks: [AuditCheck] { [] }

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, maxPriority: CheckPriority) -> [AuditCheck] {
        checks(for: version, device: device, arch: arch).filter { $0.priority <= maxPriority }
    }

    func checkCount(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> Int {
        checks(for: version, device: device, arch: arch).count
    }

    /// 通用检测执行逻辑（顺序）
    func runChecks(
        _ allChecks: [AuditCheck],
        executor: ShellExecutor,
        moduleName: String? = nil,
        onProgress: ProgressHandler? = nil
    ) async -> [AuditResult] {
        var results: [AuditResult] = []
        let total = allChecks.count

        for (i, check) in allChecks.enumerated() {
            if let name = moduleName { onProgress?(name, i, total) }
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
        if let name = moduleName { onProgress?(name, total, total) }
        return results
    }

    /// 并行检测执行
    func runChecksParallel(
        _ allChecks: [AuditCheck],
        executor: ShellExecutor,
        moduleName: String? = nil,
        perCheckTimeout: Duration? = nil,
        onProgress: ProgressHandler? = nil
    ) async -> [AuditResult] {
        let total = allChecks.count
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

                    if let name = moduleName {
                        let c = counter.increment()
                        onProgress?(name, c, total)
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
            for await pair in group { indexed.append(pair) }
            if let name = moduleName { onProgress?(name, total, total) }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
