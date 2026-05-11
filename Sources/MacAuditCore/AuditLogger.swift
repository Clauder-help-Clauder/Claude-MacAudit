import Foundation

public enum AuditLogger {
    private static let logsDir: String = {
        let dir = NSString(string: "~/.macaudit/logs").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let maxLogFiles = 50

    private static func timestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        return fmt.string(from: Date())
    }

    private static func iso8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func sanitize(_ s: String) -> String {
        String(s.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "").prefix(80))
    }

    private static func write(_ content: String, prefix: String) {
        let filename = "\(prefix)_\(timestamp()).log"
        let path = "\(logsDir)/\(filename)"
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        pruneOldLogs()
    }

    private static func pruneOldLogs() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: logsDir) else { return }
        let logFiles = files.filter { $0.hasSuffix(".log") }.sorted()
        if logFiles.count > maxLogFiles {
            for file in logFiles.prefix(logFiles.count - maxLogFiles) {
                try? fm.removeItem(atPath: "\(logsDir)/\(file)")
            }
        }
    }

    // MARK: - Audit Log (typed — for MacAuditCore/GUI callers)

    public static func logAudit(
        results: [AuditResult],
        version: MacOSVersion?,
        device: DeviceType,
        arch: CPUArchitecture,
        duration: Duration,
        mode: String,
        appVersion: String = "unknown"
    ) {
        var entries: [(moduleId: String, checkId: String, status: String, actual: String?, expected: String?)] = []
        for r in results {
            entries.append((r.moduleId, r.checkId, r.status.rawValue, r.actualValue, r.expectedValue))
        }
        let total = results.count
        let pass = results.filter { $0.status == .pass }.count
        let fail = results.filter { $0.status == .fail }.count
        let warn = results.filter { $0.status == .warn }.count
        let info = results.filter { $0.status == .info }.count
        let skip = results.filter { $0.status == .skip }.count
        let errCount = results.filter { $0.status == .error }.count

        logAuditRaw(
            entries: entries,
            macOS: "\(version?.displayName ?? "unknown") (\(MacOSVersion.versionString))",
            device: "\(device.displayName) (\(arch.rawValue))",
            duration: duration,
            mode: mode,
            appVersion: appVersion,
            total: total, pass: pass, fail: fail, warn: warn, info: info, skip: skip, error: errCount
        )
    }

    // MARK: - Audit Log (raw — for CLI callers with different model types)

    public static func logAuditRaw(
        entries: [(moduleId: String, checkId: String, status: String, actual: String?, expected: String?)],
        macOS: String,
        device: String,
        duration: Duration,
        mode: String,
        appVersion: String = "unknown",
        total: Int, pass: Int, fail: Int, warn: Int, info: Int, skip: Int, error: Int
    ) {
        var lines: [String] = []
        lines.append("=== MacAudit Audit Log ===")
        lines.append("AppVersion: \(appVersion)")
        lines.append("Timestamp: \(iso8601())")
        lines.append("macOS: \(macOS)")
        lines.append("Device: \(device)")
        lines.append("Mode: \(mode)")
        lines.append("")

        let grouped = Dictionary(grouping: entries, by: { $0.moduleId })
        let sortedModules = grouped.keys.sorted()

        for moduleId in sortedModules {
            guard let moduleEntries = grouped[moduleId] else { continue }
            lines.append("--- [\(moduleId)] ---")

            for r in moduleEntries {
                var line = "  \(r.status.uppercased().padding(toLength: 5, withPad: " ", startingAt: 0)) \(r.checkId)"
                if let actual = r.actual {
                    line += "  actual=\"\(sanitize(actual))\""
                }
                if let expected = r.expected, r.status == "fail" {
                    line += "  expected=\"\(sanitize(expected))\""
                }
                lines.append(line)
            }
            lines.append("")
        }

        let durationSec = String(format: "%.1f", Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
        let score = total > 0 ? pass * 100 / max(1, total - info - skip) : 0

        lines.append("=== Summary ===")
        lines.append("Total: \(total) | Pass: \(pass) | Fail: \(fail) | Warn: \(warn) | Info: \(info) | Skip: \(skip) | Error: \(error)")
        lines.append("Duration: \(durationSec)s")
        lines.append("Score: \(score)%")

        write(lines.joined(separator: "\n"), prefix: "audit")
    }

    // MARK: - Fix Log

    public static func logFix(
        batchId: String,
        executedResults: [(checkId: String, command: String, success: Bool, error: String?)],
        type: String,
        appVersion: String = "unknown"
    ) {
        var lines: [String] = []
        lines.append("=== MacAudit Fix Log ===")
        lines.append("AppVersion: \(appVersion)")
        lines.append("Timestamp: \(iso8601())")
        lines.append("Batch: \(batchId)")
        lines.append("Type: \(type)")
        lines.append("")

        lines.append("--- Executed ---")
        for r in executedResults {
            let icon = r.success ? "✓" : "✗"
            var line = "  \(icon) \(r.checkId)  cmd=\"\(sanitize(r.command))\""
            if let err = r.error {
                line += "  error=\"\(err.prefix(80))\""
            }
            lines.append(line)
        }

        lines.append("")
        let success = executedResults.filter(\.success).count
        let failed = executedResults.count - success
        lines.append("=== Summary ===")
        lines.append("Executed: \(executedResults.count) | Success: \(success) | Failed: \(failed)")

        write(lines.joined(separator: "\n"), prefix: "fix")
    }

    // MARK: - Action Log (user interactions: fix clicks, service toggles, skips, refreshes)

    public static func logAction(
        action: String,
        detail: String,
        success: Bool,
        error: String?
    ) {
        let icon = success ? "✓" : "✗"
        var line = "[\(iso8601())] \(icon) \(action): \(detail)"
        if let err = error {
            line += "  error=\"\(err.prefix(120))\""
        }
        appendToActionLog(line)
    }

    private static let actionLogLock = NSLock()

    private static func appendToActionLog(_ line: String) {
        actionLogLock.lock()
        defer { actionLogLock.unlock() }
        let path = "\(logsDir)/actions.log"
        let entry = line + "\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try? entry.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
