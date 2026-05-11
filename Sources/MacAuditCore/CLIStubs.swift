/// Stubs for CLI-only types in MacAuditCore.
/// GUI layer uses @Observable callbacks instead of terminal I/O.

enum InteractiveUI {
    static func updateProgress(module: String, current: Int, total: Int) {}
    static func clearProgress() {}
    static func printOverallSummary(_ results: [AuditResult], duration: Duration) {}
    static func printFailureSummary(_ results: [AuditResult]) {}
    static func printModuleHeader(_ name: String) {}
    static func printResult(_ result: AuditResult) {}
    static func printModuleSummary(_ results: [AuditResult]) {}
}

enum MenuUI {
    static func clearScreen() {}
    static func waitForReturn() {}
}

enum TerminalInput {
    static func readVersion() -> MacOSVersion? { nil }
    static func readDevice() -> DeviceType { .laptop }
    static func selectModule(from modules: [any AuditModule]) -> (any AuditModule)? { nil }
    static func enableRawMode() {}
    static func disableRawMode() {}
    static func readKey() -> String? { nil }
}
