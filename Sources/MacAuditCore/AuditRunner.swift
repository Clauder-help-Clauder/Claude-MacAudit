import Foundation

/// MacAuditCore 版 AuditRunner — 纯数据執行，無終端 I/O
@MainActor
public final class AuditRunner {
    private let modules: [any AuditModule]
    private let version: MacOSVersion?
    private let device: DeviceType
    private let arch: CPUArchitecture
    let executor: ShellExecutor
    private let maxPriority: CheckPriority

    public var onProgress: (@MainActor @Sendable (String, Int, Int) -> Void)?
    public var onModuleComplete: (@MainActor @Sendable (String, [AuditResult]) -> Void)?

    public init(
        modules: [any AuditModule],
        version: MacOSVersion?,
        device: DeviceType,
        arch: CPUArchitecture = .detect(),
        executor: ShellExecutor = ShellExecutor(),
        maxPriority: CheckPriority = .a3
    ) {
        self.modules = modules
        self.version = version
        self.device = device
        self.arch = arch
        self.executor = executor
        self.maxPriority = maxPriority
    }

    public func runAll() async -> [AuditResult] {
        let v = version ?? .sequoia
        let applicableModules: [any AuditModule] = maxPriority < .a3
            ? modules.filter { $0.checks(for: v, device: device, arch: arch, maxPriority: maxPriority).count > 0 }
            : modules
        var all: [AuditResult] = []
        for module in applicableModules {
            guard !Task.isCancelled else { break }
            let results = await module.run(version: v, device: device, arch: arch, executor: executor)
            let filtered: [AuditResult]
            if maxPriority < .a3 {
                let allowedIds = Set(module.checks(for: v, device: device, arch: arch, maxPriority: maxPriority).map(\.id))
                filtered = results.filter { allowedIds.contains($0.checkId) }
            } else {
                filtered = results
            }
            all.append(contentsOf: filtered)
            if let callback = onModuleComplete {
                await MainActor.run { callback(module.name, filtered) }
            }
            if Task.isCancelled { break }
        }
        return all
    }

    public func runModule(_ id: String) async -> [AuditResult]? {
        guard let module = modules.first(where: { $0.id == id }) else { return nil }
        guard !Task.isCancelled else { return [] }
        let v = version ?? .sequoia
        return await module.run(version: v, device: device, arch: arch, executor: executor)
    }

    public func totalCheckCount() -> Int {
        let v = version ?? .sequoia
        return modules.reduce(0) { $0 + $1.checkCount(for: v, device: device, arch: arch) }
    }
}
