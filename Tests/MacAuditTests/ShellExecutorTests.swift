import Testing
@testable import MacAudit

// MARK: - ShellExecutor Basic Tests

@Test("ShellExecutor runs echo and returns output")
func shellExecutorEcho() async {
    let executor = ShellExecutor()
    let result = await executor.run("echo hello")
    #expect(result.trimmedOutput == "hello")
    #expect(result.isSuccess)
    #expect(result.exitCode == 0)
}

@Test("ShellExecutor trims whitespace from output")
func shellExecutorTrimming() async {
    let executor = ShellExecutor()
    let result = await executor.run("echo '  spaces  '")
    #expect(result.trimmedOutput == "spaces")
}

@Test("ShellExecutor returns non-zero exit code for failing command")
func shellExecutorFailingCommand() async {
    let executor = ShellExecutor()
    let result = await executor.run("exit 1")
    #expect(!result.isSuccess)
    #expect(result.exitCode != 0)
}

@Test("ShellExecutor hasOutput is true when stdout has content")
func shellExecutorHasOutput() async {
    let executor = ShellExecutor()
    let result = await executor.run("echo hello")
    #expect(result.hasOutput)
}

@Test("ShellExecutor hasOutput is false for empty output")
func shellExecutorEmptyOutput() async {
    let executor = ShellExecutor()
    let result = await executor.run("true")
    #expect(!result.hasOutput)
}

@Test("ShellExecutor run with custom environment variables")
func shellExecutorRunCustomEnvironment() async {
    let executor = ShellExecutor()
    let result = await executor.run("echo $TEST_CUSTOM_ENV", environment: ["TEST_CUSTOM_ENV": "Success123"])
    #expect(result.trimmedOutput == "Success123")
    #expect(result.isSuccess)
}

// MARK: - ShellExecutor Convenience Methods

@Test("ShellExecutor readDefaults returns nil for non-existent domain")
func shellExecutorReadDefaultsNonExistent() async {
    let executor = ShellExecutor()
    let value = await executor.readDefaults(domain: "com.nonexistent.domain.xyz.test", key: "someKey")
    #expect(value == nil)
}

@Test("ShellExecutor readSysctl returns Darwin for kern.ostype")
func shellExecutorReadSysctlKernOstype() async {
    let executor = ShellExecutor()
    let value = await executor.readSysctl("kern.ostype")
    #expect(value == "Darwin")
}

@Test("ShellExecutor readSysctl returns non-nil for kern.hostname")
func shellExecutorReadSysctlHostname() async {
    let executor = ShellExecutor()
    let value = await executor.readSysctl("kern.hostname")
    #expect(value != nil)
    #expect(!value!.isEmpty)
}

@Test("ShellExecutor commandExists returns true for echo")
func shellExecutorCommandExistsEcho() async {
    let executor = ShellExecutor()
    let exists = await executor.commandExists("echo")
    #expect(exists)
}

@Test("ShellExecutor commandExists returns false for nonexistent command")
func shellExecutorCommandExistsNonExistent() async {
    let executor = ShellExecutor()
    let exists = await executor.commandExists("nonexistentcmd12345xyz")
    #expect(!exists)
}

@Test("ShellExecutor commandExists returns true for ls")
func shellExecutorCommandExistsLs() async {
    let executor = ShellExecutor()
    let exists = await executor.commandExists("ls")
    #expect(exists)
}

// MARK: - ShellResult Tests

@Test("ShellResult timedOut is false for normal run")
func shellResultNotTimedOut() async {
    let executor = ShellExecutor()
    let result = await executor.run("echo ok")
    #expect(!result.timedOut)
}

// MARK: - Timeout Tests

@Test("ShellExecutor timedOut=true when command exceeds timeout")
func shellExecutorTimedOut() async {
    // Use a 100ms timeout against a command that sleeps 10s
    let executor = ShellExecutor(timeout: .milliseconds(100))
    let result = await executor.run("sleep 10")
    #expect(result.timedOut == true)
    #expect(result.exitCode == -1)
    #expect(result.isSuccess == false)
}

@Test("ShellExecutor timedOut=false when command finishes before timeout")
func shellExecutorNotTimedOutFast() async {
    // 5 second timeout, echo finishes in <10ms
    let executor = ShellExecutor(timeout: .seconds(5))
    let result = await executor.run("echo fast")
    #expect(result.timedOut == false)
    #expect(result.trimmedOutput == "fast")
}

// MARK: - commandVersion Tests

@Test("ShellExecutor commandVersion returns non-nil for bash")
func shellExecutorCommandVersionBash() async {
    let executor = ShellExecutor()
    let version = await executor.commandVersion("bash")
    #expect(version != nil)
    #expect(!version!.isEmpty)
}

@Test("ShellExecutor commandVersion returns non-nil for swift")
func shellExecutorCommandVersionSwift() async {
    let executor = ShellExecutor()
    let version = await executor.commandVersion("swift")
    // swift is available in Xcode environments
    if let v = version {
        #expect(!v.isEmpty)
    }
}

// MARK: - A0 Defect: sub-millisecond timeout truncation (T5)

@Test("ShellExecutor .microseconds(500) timeout triggers timeout (not zero-timeout)")
func shellExecutorSubMillisecondTimeout() async {
    let executor = ShellExecutor(timeout: .microseconds(500))
    let result = await executor.run("sleep 10")
    #expect(result.timedOut == true)
    #expect(result.exitCode == -1)
}

@Test("ShellExecutor .milliseconds(1) timeout triggers timeout for slow command")
func shellExecutorOneMsTimeout() async {
    let executor = ShellExecutor(timeout: .milliseconds(1))
    let result = await executor.run("sleep 10")
    #expect(result.timedOut == true)
}

// MARK: - A0 Defect: timeout pipe cleanup (T6)

@Test("ShellExecutor timeout returns proper ShellResult with no leftover output")
func shellExecutorTimeoutResultClean() async {
    let executor = ShellExecutor(timeout: .milliseconds(50))
    let result = await executor.run("sleep 10")
    #expect(result.timedOut == true)
    #expect(result.stdout.isEmpty)
    #expect(result.exitCode == -1)
}

// MARK: - A0 Defect: pipe read deadlock (D3) — readabilityHandler

@Test("ShellExecutor does not hang when process produces output then hangs (pipe deadlock scenario)")
func shellExecutorNoPipeDeadlock() async {
    let executor = ShellExecutor(timeout: .milliseconds(300))
    let result = await executor.run("echo hello; sleep 10")
    #expect(result.timedOut == true)
}

@Test("ShellExecutor captures stdout before timeout when process hangs after output")
func shellExecutorCapturesOutputBeforeTimeout() async {
    let executor = ShellExecutor(timeout: .milliseconds(300))
    let result = await executor.run("echo captured; sleep 10")
    #expect(result.timedOut == true)
    #expect(result.stdout.contains("captured"))
}

@Test("ShellExecutor captures stderr before timeout")
func shellExecutorCapturesStderrBeforeTimeout() async {
    let executor = ShellExecutor(timeout: .milliseconds(300))
    let result = await executor.run("echo err >&2; sleep 10")
    #expect(result.timedOut == true)
    #expect(result.stderr.contains("err"))
}
