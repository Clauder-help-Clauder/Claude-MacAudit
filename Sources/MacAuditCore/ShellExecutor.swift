import Foundation

/// Shell 命令执行结果
public struct ShellResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let timedOut: Bool

    public var hasOutput: Bool { !stdout.isEmpty }
    public var isSuccess: Bool { exitCode == 0 && !timedOut }
    public var trimmedOutput: String { stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// 线程安全的一次性标志
private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    func tryFire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else { return false }
        fired = true
        return true
    }
}

/// 线程安全的数据累加器（供 readabilityHandler 回调写入）
private final class PipeAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func getData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

/// Shell 命令执行器
public actor ShellExecutor {
    private let defaultTimeout: Duration
    private let stubbedOutputs: [String: String]

    public init(timeout: Duration = .seconds(10), stubbedOutputs: [String: String] = [:]) {
        self.defaultTimeout = timeout
        self.stubbedOutputs = stubbedOutputs
    }

    public func run(
        _ command: String,
        environment: [String: String]? = nil,
        timeout: Duration? = nil
    ) async -> ShellResult {
        if let output = stubbedOutputs[command] {
            return ShellResult(stdout: output + "\n", stderr: "", exitCode: 0, timedOut: false)
        }
        for (key, output) in stubbedOutputs where key.count >= 5 && command.contains(key) {
            return ShellResult(stdout: output + "\n", stderr: "", exitCode: 0, timedOut: false)
        }

        let effectiveTimeout = timeout ?? defaultTimeout
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        if let customEnv = environment {
            var currentEnv = ProcessInfo.processInfo.environment
            currentEnv.merge(customEnv) { _, new in new }
            process.environment = currentEnv
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutAcc = PipeAccumulator()
        let stderrAcc = PipeAccumulator()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let newData = handle.availableData
            if !newData.isEmpty { stdoutAcc.append(newData) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let newData = handle.availableData
            if !newData.isEmpty { stderrAcc.append(newData) }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            return ShellResult(stdout: "", stderr: "Launch failed: \(error)", exitCode: -1, timedOut: false)
        }

        let flag = OnceFlag()

        let didComplete: Bool = await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                if flag.tryFire() {
                    continuation.resume(returning: true)
                }
            }

            let timeoutNs = Int(effectiveTimeout.components.seconds) * 1_000_000_000
                + Int(effectiveTimeout.components.attoseconds / 1_000_000_000)
            DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(timeoutNs)) {
                if flag.tryFire() {
                    if process.isRunning {
                        process.terminate()
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                        }
                    }
                    continuation.resume(returning: false)
                }
            }
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        var stdoutData = stdoutAcc.getData()
        var stderrData = stderrAcc.getData()

        if didComplete {
            let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            if !remainingStdout.isEmpty { stdoutData.append(remainingStdout) }
            if !remainingStderr.isEmpty { stderrData.append(remainingStderr) }
        }

        if !didComplete {
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
            let combinedStderr = stderrStr.isEmpty ? "Timed out" : stderrStr
            return ShellResult(
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: combinedStderr,
                exitCode: -1,
                timedOut: true
            )
        }

        return ShellResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? String(data: stdoutData, encoding: .isoLatin1) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? String(data: stderrData, encoding: .isoLatin1) ?? "",
            exitCode: process.terminationStatus,
            timedOut: false
        )
    }

    private static let safeParamPattern = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_/"))

    private func isSafeParam(_ s: String) -> Bool {
        s.unicodeScalars.allSatisfy { Self.safeParamPattern.contains($0) }
    }

    public func readDefaults(domain: String, key: String) async -> String? {
        guard isSafeParam(domain), isSafeParam(key) else { return nil }
        let result = await run("defaults read \(domain) \(key) 2>/dev/null")
        guard result.isSuccess else { return nil }
        let value = result.trimmedOutput
        return value.isEmpty ? nil : value
    }

    public func readSysctl(_ name: String) async -> String? {
        guard isSafeParam(name) else { return nil }
        let result = await run("sysctl -n \(name) 2>/dev/null")
        guard result.isSuccess else { return nil }
        let value = result.trimmedOutput
        return value.isEmpty ? nil : value
    }

    public func commandExists(_ command: String) async -> Bool {
        guard isSafeParam(command) else { return false }
        let result = await run("which \(command) 2>/dev/null")
        return result.isSuccess && result.hasOutput
    }

    public func commandVersion(_ command: String, flag: String = "--version") async -> String? {
        guard isSafeParam(command), isSafeParam(flag) else { return nil }
        let result = await run("\(command) \(flag) 2>&1 | head -1")
        guard result.hasOutput else { return nil }
        return result.trimmedOutput
    }
}
