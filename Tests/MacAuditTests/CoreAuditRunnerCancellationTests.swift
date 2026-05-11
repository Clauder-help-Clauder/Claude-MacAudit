import Foundation
import Testing
@testable import MacAuditCore

private actor RunTracker {
    private(set) var secondModuleDidRun = false

    func markSecondModuleRan() {
        secondModuleDidRun = true
    }
}

@MainActor
private final class CallbackTracker {
    var completionCount = 0
}

private struct CancellingModule: AuditModule {
    let id = "cancel_first"
    let name = "Cancel First"
    let description = ""

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            AuditCheck(id: "cancel.first", name: "Cancel First", module: id, command: "echo ok", expected: "ok")
        ]
    }

    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        let check = checks(for: version, device: device, arch: arch)[0]
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return [.pass(check: check, actual: "ok", duration: 0)]
    }
}

private struct TrackingModule: AuditModule {
    let id = "cancel_second"
    let name = "Cancel Second"
    let description = ""
    let tracker: RunTracker

    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            AuditCheck(id: "cancel.second", name: "Cancel Second", module: id, command: "echo ok", expected: "ok")
        ]
    }

    func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await tracker.markSecondModuleRan()
        let check = checks(for: version, device: device, arch: arch)[0]
        return [.pass(check: check, actual: "ok", duration: 0)]
    }
}

@Test("AuditRunner runAll preserves current module results and stops future modules after cancellation")
@MainActor
func auditRunnerPreservesCurrentModuleResultsAfterCancellation() async {
    let runTracker = RunTracker()
    let callbackTracker = CallbackTracker()
    let runner = AuditRunner(
        modules: [CancellingModule(), TrackingModule(tracker: runTracker)],
        version: .sequoia,
        device: .laptop
    )

    runner.onModuleComplete = { _, _ in
        callbackTracker.completionCount += 1
    }

    let results = await runner.runAll()

    #expect(results.count == 1)
    #expect(results.first?.checkId == "cancel.first")
    #expect(await runTracker.secondModuleDidRun == false)
    #expect(callbackTracker.completionCount == 1)
}

@Test("AuditRunner runModule preserves finished module results even if task is cancelled")
func coreAuditRunnerRunModulePreservesFinishedResultsAfterCancellation() async {
    let runner = await MainActor.run {
        AuditRunner(
            modules: [CancellingModule()],
            version: .sequoia,
            device: .laptop
        )
    }

    let results = await runner.runModule("cancel_first")

    #expect(results?.count == 1)
    #expect(results?.first?.checkId == "cancel.first")
}

@Test("AuditRunner runModule returns empty results instead of nil when caller is already cancelled")
func coreAuditRunnerRunModulePreCancelledReturnsEmptyResults() async {
    let runner = await MainActor.run {
        AuditRunner(
            modules: [CancellingModule()],
            version: .sequoia,
            device: .laptop
        )
    }

    let results = await Task {
        withUnsafeCurrentTask { task in
            task?.cancel()
        }
        return await runner.runModule("cancel_first")
    }.value

    #expect(results != nil)
    #expect(results?.isEmpty == true)
}
