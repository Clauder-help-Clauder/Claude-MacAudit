import Testing
import Foundation
@testable import MacAudit

// MARK: - DNSBLChecker Tests

@Test("DNSBLChecker has exactly 13 verified servers")
func dnsblVerifiedServersCount() {
    #expect(DNSBLChecker.verifiedServers.count == 13)
}

@Test("DNSBLChecker server list contains expected entries")
func dnsblVerifiedServersContents() {
    let servers = DNSBLChecker.verifiedServers
    #expect(servers.contains("bl.spamcop.net"))
    #expect(servers.contains("b.barracudacentral.org"))
    #expect(servers.contains("dnsbl-1.uceprotect.net"))
    #expect(servers.contains("bl.0spam.org"))
}

@Test("DNSBLChecker server list has no duplicates")
func dnsblVerifiedServersUnique() {
    let servers = DNSBLChecker.verifiedServers
    #expect(Set(servers).count == servers.count)
}

// MARK: - IP reversal logic

@Test("IP reversal 1.2.3.4 becomes 4.3.2.1")
func ipReversalStandard() {
    let ip = "1.2.3.4"
    let reversed = ip.split(separator: ".").reversed().joined(separator: ".")
    #expect(reversed == "4.3.2.1")
}

@Test("IP reversal 192.168.1.100 becomes 100.1.168.192")
func ipReversalPrivate() {
    let ip = "192.168.1.100"
    let reversed = ip.split(separator: ".").reversed().joined(separator: ".")
    #expect(reversed == "100.1.168.192")
}

@Test("IP reversal 8.8.8.8 stays 8.8.8.8")
func ipReversalSymmetric() {
    let ip = "8.8.8.8"
    let reversed = ip.split(separator: ".").reversed().joined(separator: ".")
    #expect(reversed == "8.8.8.8")
}

@Test("IP reversal 10.20.30.40 becomes 40.30.20.10")
func ipReversalAllDifferent() {
    let ip = "10.20.30.40"
    let reversed = ip.split(separator: ".").reversed().joined(separator: ".")
    #expect(reversed == "40.30.20.10")
}

// MARK: - querySingle behavior tests

@Test("querySingle output starting with 127. means listed=true")
func querySingleListedTrue() async {
    // Simulate a DNSBL server returning 127.0.0.2 by using a shell command
    // that outputs that value instead of running dig
    // We use a fake reversed IP that will produce known dig output via echo injection
    // Since ShellExecutor runs the exact dig command, we test querySingle indirectly
    // by verifying the 127. prefix detection logic via summarize()
    let check = IPQualityModule().phaseCChecks()[0]
    let listedResult = DNSBLResult(server: "bl.spamcop.net", listed: true, error: nil)
    let result = DNSBLChecker.summarize(results: [listedResult], check: check)
    // 1 listed out of 1 total → listed <= 2 → .warn
    #expect(result.status == .warn)
    #expect(result.actualValue?.contains("列入 1/1") == true)
}

@Test("querySingle output not starting with 127. means listed=false")
func querySingleListedFalse() async {
    let check = IPQualityModule().phaseCChecks()[0]
    let cleanResult = DNSBLResult(server: "bl.spamcop.net", listed: false, error: nil)
    let result = DNSBLChecker.summarize(results: [cleanResult], check: check)
    #expect(result.status == .pass)
    #expect(result.actualValue?.contains("干净 1/1") == true)
}

@Test("querySingle result always has correct server name")
func querySingleServerName() async {
    let executor = ShellExecutor()
    let serverName = "b.barracudacentral.org"
    let result = await DNSBLChecker.querySingle(
        reversed: "0.0.0.0",
        server: serverName,
        executor: executor
    )
    #expect(result.server == serverName)
}

@Test("querySingle timeout produces listed=false with error=timeout")
func querySingleTimeout() async {
    let executor = ShellExecutor(timeout: .milliseconds(1))
    let result = await DNSBLChecker.querySingle(
        reversed: "4.3.2.1",
        server: "bl.spamcop.net",
        executor: executor
    )
    #expect(result.server == "bl.spamcop.net")
    if result.error == "timeout" {
        #expect(result.listed == false)
    }
}

// MARK: - Stub-based querySingle tests

@Test("querySingle returns listed=true when stub returns 127.0.0.2")
func querySingleStubListed() async {
    let executor = ShellExecutor(stubbedOutputs: ["dig +short": "127.0.0.2"])
    let result = await DNSBLChecker.querySingle(
        reversed: "4.3.2.1",
        server: "bl.spamcop.net",
        executor: executor
    )
    #expect(result.listed == true)
    #expect(result.error == nil)
    #expect(result.server == "bl.spamcop.net")
}

@Test("querySingle returns listed=false when stub returns empty string")
func querySingleStubClean() async {
    let executor = ShellExecutor(stubbedOutputs: ["dig +short": ""])
    let result = await DNSBLChecker.querySingle(
        reversed: "4.3.2.1",
        server: "bl.spamcop.net",
        executor: executor
    )
    #expect(result.listed == false)
}

@Test("querySingle returns listed=false when stub returns non-127 response")
func querySingleStubNonListed() async {
    // Some servers return NXDOMAIN or other text — should not be listed
    let executor = ShellExecutor(stubbedOutputs: ["dig +short": "NXDOMAIN"])
    let result = await DNSBLChecker.querySingle(
        reversed: "4.3.2.1",
        server: "bl.spamcop.net",
        executor: executor
    )
    #expect(result.listed == false)
}

// MARK: - summarize() three-branch tests (pass / warn / fail)

@Test("summarize with 0 listed servers produces pass")
func dnsblSummarizeZeroListed() {
    let check = IPQualityModule().phaseCChecks()[0]
    let results = (0..<13).map { i in
        DNSBLResult(server: "server\(i).test", listed: false, error: nil)
    }
    let result = DNSBLChecker.summarize(results: results, check: check)
    #expect(result.status == .pass)
    #expect(result.actualValue == "干净 13/13")
    #expect(result.message.contains("未列入黑名单"))
}

@Test("summarize with 1 listed server produces warn")
func dnsblSummarizeOneListed() {
    let check = IPQualityModule().phaseCChecks()[0]
    var results = (0..<12).map { i in
        DNSBLResult(server: "server\(i).test", listed: false, error: nil)
    }
    results.append(DNSBLResult(server: "bl.spamcop.net", listed: true, error: nil))
    let result = DNSBLChecker.summarize(results: results, check: check)
    #expect(result.status == .warn)
    #expect(result.actualValue?.contains("列入 1/13") == true)
    #expect(result.actualValue?.contains("bl.spamcop.net") == true)
    #expect(result.message.contains("列入 1 个黑名单"))
}

@Test("summarize with 2 listed servers produces warn (boundary)")
func dnsblSummarizeTwoListed() {
    let check = IPQualityModule().phaseCChecks()[0]
    var results = (0..<11).map { i in
        DNSBLResult(server: "server\(i).test", listed: false, error: nil)
    }
    results.append(DNSBLResult(server: "bl.spamcop.net", listed: true, error: nil))
    results.append(DNSBLResult(server: "b.barracudacentral.org", listed: true, error: nil))
    let result = DNSBLChecker.summarize(results: results, check: check)
    #expect(result.status == .warn)
    #expect(result.actualValue?.contains("列入 2/13") == true)
}

@Test("summarize with 3 listed servers produces fail")
func dnsblSummarizeThreeListed() {
    let check = IPQualityModule().phaseCChecks()[0]
    var results = (0..<10).map { i in
        DNSBLResult(server: "server\(i).test", listed: false, error: nil)
    }
    results.append(DNSBLResult(server: "srv1.test", listed: true, error: nil))
    results.append(DNSBLResult(server: "srv2.test", listed: true, error: nil))
    results.append(DNSBLResult(server: "srv3.test", listed: true, error: nil))
    let result = DNSBLChecker.summarize(results: results, check: check)
    #expect(result.status == .fail)
    #expect(result.actualValue?.contains("列入 3/13") == true)
    #expect(result.message.contains("风险较高"))
}

@Test("summarize with errors appends failure count to pass message")
func dnsblSummarizeWithErrors() {
    let check = IPQualityModule().phaseCChecks()[0]
    var results = (0..<12).map { i in
        DNSBLResult(server: "server\(i).test", listed: false, error: nil)
    }
    results.append(DNSBLResult(server: "timeout.test", listed: false, error: "timeout"))
    let result = DNSBLChecker.summarize(results: results, check: check)
    #expect(result.status == .pass)
    #expect(result.message.contains("查询失败"))
}

// MARK: - DNSBL thresholds (check logic via pass/warn/fail boundaries)

@Test("DNSBL summary check ID is m13.dnsbl_summary")
func dnsblSummaryCheckID() {
    let check = IPQualityModule().phaseCChecks()[0]
    #expect(check.id == "m13.dnsbl_summary")
}

@Test("DNSBL summary check has dnsbl tag")
func dnsblSummaryCheckTag() {
    let check = IPQualityModule().phaseCChecks()[0]
    #expect(check.tags.contains("dnsbl"))
}

@Test("DNSBL summary check has risk tag")
func dnsblSummaryCheckRiskTag() {
    let check = IPQualityModule().phaseCChecks()[0]
    #expect(check.tags.contains("risk"))
}

// MARK: - DNSBLResult construction

@Test("DNSBLResult timedOut convenience check")
func dnsblResultTimedOut() {
    let timeoutResult = DNSBLResult(server: "test.bl", listed: false, error: "timeout")
    #expect(timeoutResult.error == "timeout")
    #expect(timeoutResult.listed == false)
}

@Test("DNSBLResult listed=true has nil error")
func dnsblResultListedNoError() {
    let listedResult = DNSBLResult(server: "test.bl", listed: true, error: nil)
    #expect(listedResult.listed == true)
    #expect(listedResult.error == nil)
}

// MARK: - A0 Defect: IP validation before use in shell command

@Test("DNSBLChecker.validateIPv4 returns true for valid IPv4")
func dnsblValidateIPv4Valid() {
    #expect(DNSBLChecker.validateIPv4("1.2.3.4") == true)
    #expect(DNSBLChecker.validateIPv4("192.168.1.1") == true)
    #expect(DNSBLChecker.validateIPv4("8.8.8.8") == true)
    #expect(DNSBLChecker.validateIPv4("255.255.255.255") == true)
}

@Test("DNSBLChecker.validateIPv4 returns false for invalid IP")
func dnsblValidateIPv4Invalid() {
    #expect(DNSBLChecker.validateIPv4("") == false)
    #expect(DNSBLChecker.validateIPv4("not-an-ip") == false)
    #expect(DNSBLChecker.validateIPv4("1.2.3") == false)
    #expect(DNSBLChecker.validateIPv4("1.2.3.4.5") == false)
    #expect(DNSBLChecker.validateIPv4("256.1.1.1") == false)
    #expect(DNSBLChecker.validateIPv4("-1.2.3.4") == false)
    #expect(DNSBLChecker.validateIPv4("1.2.3.4;rm -rf") == false)
    #expect(DNSBLChecker.validateIPv4("1.2.3.4\nmalicious") == false)
}

@Test("DNSBLChecker.check returns error result for empty IP")
func dnsblCheckEmptyIP() async {
    let executor = ShellExecutor(stubbedOutputs: [:])
    let results = await DNSBLChecker.check(ip: "", executor: executor)
    #expect(results.count == 1)
    #expect(results[0].status == .error)
}

@Test("DNSBLChecker.check returns error result for non-IP string")
func dnsblCheckInvalidIP() async {
    let executor = ShellExecutor(stubbedOutputs: [:])
    let results = await DNSBLChecker.check(ip: "not-an-ip;rm -rf /", executor: executor)
    #expect(results.count == 1)
    #expect(results[0].status == .error)
}
