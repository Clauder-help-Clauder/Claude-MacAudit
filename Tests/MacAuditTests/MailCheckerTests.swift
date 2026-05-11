import Testing
import Foundation
@testable import MacAudit

// MARK: - MailChecker Tests

@Test("M13 phaseD has 2 checks")
func mailCheckerPhaseDCount() {
    let checks = IPQualityModule().phaseDChecks()
    #expect(checks.count == 2)
}

@Test("M13 phaseD check[0] id is m13.smtp_port25")
func mailCheckerPhaseDFirstID() {
    let checks = IPQualityModule().phaseDChecks()
    #expect(checks[0].id == "m13.smtp_port25")
}

@Test("M13 phaseD check[1] id is m13.smtp_port587")
func mailCheckerPhaseDSecondID() {
    let checks = IPQualityModule().phaseDChecks()
    #expect(checks[1].id == "m13.smtp_port587")
}

// MARK: portResult open=true

@Test("portResult open=true produces pass with 开放")
func portResultOpenTrue() {
    let checks = IPQualityModule().phaseDChecks()
    let result = MailChecker.portResult(check: checks[0], open: true, port: 25)
    #expect(result.status == .pass)
    #expect(result.actualValue == "开放")
}

@Test("portResult open=true message contains port number")
func portResultOpenTrueMessage() {
    let checks = IPQualityModule().phaseDChecks()
    let result = MailChecker.portResult(check: checks[0], open: true, port: 25)
    #expect(result.message.contains("25"))
}

// MARK: portResult open=false

@Test("portResult open=false produces warn with 关闭")
func portResultOpenFalse() {
    let checks = IPQualityModule().phaseDChecks()
    let result = MailChecker.portResult(check: checks[0], open: false, port: 25)
    #expect(result.status == .warn)
    #expect(result.actualValue == "关闭")
}

@Test("portResult open=false message contains port number")
func portResultOpenFalseMessage() {
    let checks = IPQualityModule().phaseDChecks()
    let result = MailChecker.portResult(check: checks[0], open: false, port: 25)
    #expect(result.message.contains("25"))
}

// MARK: portResult for port 587

@Test("portResult for port 587 open=true produces pass")
func portResult587OpenTrue() {
    let checks = IPQualityModule().phaseDChecks()
    let result = MailChecker.portResult(check: checks[1], open: true, port: 587)
    #expect(result.status == .pass)
    #expect(result.actualValue == "开放")
    #expect(result.message.contains("587"))
}

@Test("portResult for port 587 open=false produces warn")
func portResult587OpenFalse() {
    let checks = IPQualityModule().phaseDChecks()
    let result = MailChecker.portResult(check: checks[1], open: false, port: 587)
    #expect(result.status == .warn)
    #expect(result.actualValue == "关闭")
    #expect(result.message.contains("587"))
}

// MARK: portResult check IDs in results

@Test("portResult preserves check id in result")
func portResultPreservesCheckID() {
    let checks = IPQualityModule().phaseDChecks()
    let r25 = MailChecker.portResult(check: checks[0], open: true, port: 25)
    let r587 = MailChecker.portResult(check: checks[1], open: false, port: 587)
    #expect(r25.checkId == "m13.smtp_port25")
    #expect(r587.checkId == "m13.smtp_port587")
}

// MARK: checkPort smoke test

@Test("checkPort returns Bool without crashing")
func checkPortSmoke() async {
    let executor = ShellExecutor()
    let result = await MailChecker.checkPort(port: 25, executor: executor)
    #expect(result == true || result == false)
}

// MARK: - Stub-based checkPort tests

@Test("checkPort returns true when executor outputs OPEN")
func checkPortOpenTrue() async {
    let executor = ShellExecutor(stubbedOutputs: ["smtp.gmail.com": "OPEN"])
    let result = await MailChecker.checkPort(port: 25, executor: executor)
    #expect(result == true)
}

@Test("checkPort returns false when executor outputs CLOSED")
func checkPortOpenFalse() async {
    let executor = ShellExecutor(stubbedOutputs: ["smtp.gmail.com": "CLOSED"])
    let result = await MailChecker.checkPort(port: 25, executor: executor)
    #expect(result == false)
}

// MARK: - check() main function tests

@Test("MailChecker.check returns 2 results in correct order")
func mailCheckerCheckReturnsTwo() async {
    // Both ports stubbed as OPEN
    let executor = ShellExecutor(stubbedOutputs: ["smtp.gmail.com": "OPEN"])
    let results = await MailChecker.check(executor: executor)
    #expect(results.count == 2)
    #expect(results[0].checkId == "m13.smtp_port25")
    #expect(results[1].checkId == "m13.smtp_port587")
}

@Test("MailChecker.check port25 open produces pass result")
func mailCheckerCheckPort25Open() async {
    let executor = ShellExecutor(stubbedOutputs: ["smtp.gmail.com": "OPEN"])
    let results = await MailChecker.check(executor: executor)
    #expect(results[0].status == .pass)
    #expect(results[0].actualValue == "开放")
}

@Test("MailChecker.check port587 closed produces warn result")
func mailCheckerCheckPort587Closed() async {
    let executor = ShellExecutor(stubbedOutputs: ["smtp.gmail.com": "CLOSED"])
    let results = await MailChecker.check(executor: executor)
    #expect(results[1].status == .warn)
    #expect(results[1].actualValue == "关闭")
}
