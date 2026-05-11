import Testing
import Foundation
@testable import MacAudit

// MARK: - IPFetcher Tests

// MARK: isValidIPv4

@Test("isValidIPv4 accepts standard IPs")
func isValidIPv4ValidAddresses() {
    #expect(IPFetcher.isValidIPv4("1.2.3.4"))
    #expect(IPFetcher.isValidIPv4("192.168.1.1"))
    #expect(IPFetcher.isValidIPv4("0.0.0.0"))
    #expect(IPFetcher.isValidIPv4("255.255.255.255"))
    #expect(IPFetcher.isValidIPv4("10.0.0.1"))
    #expect(IPFetcher.isValidIPv4("172.16.0.1"))
}

@Test("isValidIPv4 rejects out-of-range octet 256")
func isValidIPv4Octet256() {
    #expect(!IPFetcher.isValidIPv4("256.0.0.1"))
    #expect(!IPFetcher.isValidIPv4("1.2.3.256"))
}

@Test("isValidIPv4 rejects negative octet")
func isValidIPv4NegativeOctet() {
    #expect(!IPFetcher.isValidIPv4("-1.0.0.0"))
    #expect(!IPFetcher.isValidIPv4("1.2.-3.4"))
}

@Test("isValidIPv4 rejects too few octets")
func isValidIPv4TooFewOctets() {
    #expect(!IPFetcher.isValidIPv4("1.2.3"))
    #expect(!IPFetcher.isValidIPv4("1.2"))
    #expect(!IPFetcher.isValidIPv4("1"))
}

@Test("isValidIPv4 rejects too many octets")
func isValidIPv4TooManyOctets() {
    #expect(!IPFetcher.isValidIPv4("1.2.3.4.5"))
}

@Test("isValidIPv4 rejects empty string")
func isValidIPv4EmptyString() {
    #expect(!IPFetcher.isValidIPv4(""))
}

@Test("isValidIPv4 rejects non-numeric strings")
func isValidIPv4NonNumeric() {
    #expect(!IPFetcher.isValidIPv4("abc"))
    #expect(!IPFetcher.isValidIPv4("1.2.3.abc"))
    #expect(!IPFetcher.isValidIPv4("a.b.c.d"))
}

@Test("isValidIPv4 rejects IPv6 address")
func isValidIPv4RejectsIPv6() {
    #expect(!IPFetcher.isValidIPv4("2001:db8::1"))
    #expect(!IPFetcher.isValidIPv4("::1"))
}

// MARK: extractValue

@Test("extractValue extracts value after colon with spaces")
func extractValueWithSpaces() {
    let result = IPFetcher.extractValue("OrgName:  Example Inc")
    #expect(result == "Example Inc")
}

@Test("extractValue extracts value with single space after colon")
func extractValueSingleSpace() {
    let result = IPFetcher.extractValue("country: US")
    #expect(result == "US")
}

@Test("extractValue returns nil when no colon present")
func extractValueNoColon() {
    let result = IPFetcher.extractValue("no-colon-here")
    #expect(result == nil)
}

@Test("extractValue returns nil when value after colon is empty")
func extractValueEmptyAfterColon() {
    let result = IPFetcher.extractValue("empty:")
    #expect(result == nil)
}

@Test("extractValue returns nil when value after colon is only whitespace")
func extractValueOnlyWhitespace() {
    let result = IPFetcher.extractValue("key:  ")
    #expect(result == nil)
}

@Test("extractValue handles multiple colons, uses first")
func extractValueMultipleColons() {
    let result = IPFetcher.extractValue("descr: AS1234: Example Corp")
    #expect(result == "AS1234: Example Corp")
}

// MARK: reverseDNS invalid IP

@Test("reverseDNS returns nil for invalid IP")
func reverseDNSInvalidIP() async {
    let executor = ShellExecutor()
    let result = await IPFetcher.reverseDNS(ip: "not-an-ip", executor: executor)
    #expect(result == nil)
}

@Test("reverseDNS returns nil for empty string")
func reverseDNSEmptyIP() async {
    let executor = ShellExecutor()
    let result = await IPFetcher.reverseDNS(ip: "", executor: executor)
    #expect(result == nil)
}

// MARK: - Stub-based tests for IPFetcher core logic

@Test("publicIPv4 returns first valid IP from sources")
func publicIPv4ReturnsFirstValid() async {
    // Stub: first source returns a valid IP
    let executor = ShellExecutor(stubbedOutputs: ["ifconfig.me": "1.2.3.4"])
    let ip = await IPFetcher.publicIPv4(executor: executor)
    #expect(ip == "1.2.3.4")
}

@Test("publicIPv4 returns nil when all sources return invalid IP text")
func publicIPv4AllSourcesInvalid() async {
    // Stub all curl commands to return invalid text
    // publicIPv4 iterates 3 sources, all filtered by isValidIPv4
    let executor = ShellExecutor(stubbedOutputs: ["curl ": "not-an-ip"])
    let ip = await IPFetcher.publicIPv4(executor: executor)
    // All 3 sources return "not-an-ip" which fails isValidIPv4 → nil
    #expect(ip == nil)
}

@Test("publicIPv4 returns nil when all sources fail")
func publicIPv4AllFail() async {
    // No stubs → all real sources will fail in test env (or timeout)
    // Use a stub that returns invalid text for all curl commands
    let executor = ShellExecutor(stubbedOutputs: ["curl ": "not-an-ip"])
    let ip = await IPFetcher.publicIPv4(executor: executor)
    #expect(ip == nil)
}

@Test("publicIPv6 returns IPv6 address containing colon")
func publicIPv6Valid() async {
    let executor = ShellExecutor(stubbedOutputs: ["api64.ipify.org": "2001:db8::1"])
    let ip = await IPFetcher.publicIPv6(executor: executor)
    #expect(ip == "2001:db8::1")
}

@Test("publicIPv6 returns nil when output lacks colon")
func publicIPv6Invalid() async {
    // Stub returns IPv4-looking text — should be rejected by : check
    let executor = ShellExecutor(stubbedOutputs: ["curl": "192.168.1.1"])
    let ip = await IPFetcher.publicIPv6(executor: executor)
    #expect(ip == nil)
}

@Test("whoisInfo parses orgname: prefix correctly")
func whoisInfoOrgname() async {
    let fakeWhois = """
    % Info
    OrgName: Example Corp
    Country: US
    """
    let executor = ShellExecutor(stubbedOutputs: ["whois": fakeWhois])
    let info = await IPFetcher.whoisInfo(ip: "1.2.3.4", executor: executor)
    #expect(info.org == "Example Corp")
    #expect(info.country == "US")
}

@Test("whoisInfo parses org-name: prefix correctly")
func whoisInfoOrgNameHyphen() async {
    let fakeWhois = """
    org-name: Another Org
    country: DE
    """
    let executor = ShellExecutor(stubbedOutputs: ["whois": fakeWhois])
    let info = await IPFetcher.whoisInfo(ip: "1.2.3.4", executor: executor)
    #expect(info.org == "Another Org")
    #expect(info.country == "DE")
}

@Test("whoisInfo parses descr: prefix as org fallback")
func whoisInfoDescr() async {
    let fakeWhois = """
    descr: Fallback ISP Name
    country: JP
    """
    let executor = ShellExecutor(stubbedOutputs: ["whois": fakeWhois])
    let info = await IPFetcher.whoisInfo(ip: "1.2.3.4", executor: executor)
    #expect(info.org == "Fallback ISP Name")
    #expect(info.country == "JP")
}

@Test("whoisInfo returns nil org and country for invalid IP")
func whoisInfoInvalidIP() async {
    let executor = ShellExecutor()
    let info = await IPFetcher.whoisInfo(ip: "not-an-ip", executor: executor)
    #expect(info.org == nil)
    #expect(info.country == nil)
}

@Test("reverseDNS returns nil when dig output is empty")
func reverseDNSEmptyOutput() async {
    // Stub dig to return empty string for reverse DNS
    let executor = ShellExecutor(stubbedOutputs: ["dig +short -x": ""])
    let result = await IPFetcher.reverseDNS(ip: "1.2.3.4", executor: executor)
    // Empty output → nil
    #expect(result == nil)
}

@Test("reverseDNS returns hostname when dig output is non-empty")
func reverseDNSValid() async {
    let executor = ShellExecutor(stubbedOutputs: ["dig +short -x": "host.example.com."])
    let result = await IPFetcher.reverseDNS(ip: "1.2.3.4", executor: executor)
    #expect(result == "host.example.com.")
}

// MARK: - isValidIPv4 edge cases

@Test("isValidIPv4 rejects IP with leading-zero octets (octal ambiguity, security fix)")
func isValidIPv4RejectsLeadingZero() {
    #expect(!IPFetcher.isValidIPv4("01.02.03.04"))
}

@Test("isValidIPv4 rejects IP with trailing whitespace")
func isValidIPv4TrailingSpace() {
    // "1.2.3.4 " — split(separator:".") gives last part "4 ", Int("4 ") = nil → reject
    #expect(!IPFetcher.isValidIPv4("1.2.3.4 "))
}

// MARK: - whoisInfo partial results

@Test("whoisInfo returns org only when country is absent")
func whoisInfoOrgOnlyNoCountry() async {
    let fakeWhois = """
    OrgName: Example Corp
    NetRange: 1.2.3.0 - 1.2.3.255
    """
    let executor = ShellExecutor(stubbedOutputs: ["whois": fakeWhois])
    let info = await IPFetcher.whoisInfo(ip: "1.2.3.4", executor: executor)
    #expect(info.org == "Example Corp")
    #expect(info.country == nil)
}

@Test("whoisInfo returns country only when org is absent")
func whoisInfoCountryOnlyNoOrg() async {
    let fakeWhois = """
    NetRange: 1.2.3.0
    country: JP
    """
    let executor = ShellExecutor(stubbedOutputs: ["whois": fakeWhois])
    let info = await IPFetcher.whoisInfo(ip: "1.2.3.4", executor: executor)
    #expect(info.org == nil)
    #expect(info.country == "JP")
}

@Test("whoisInfo stops reading after finding both org and country")
func whoisInfoEarlyBreak() async {
    // country appears before a second orgname — should not overwrite org
    let fakeWhois = """
    OrgName: First Corp
    country: US
    OrgName: Second Corp
    """
    let executor = ShellExecutor(stubbedOutputs: ["whois": fakeWhois])
    let info = await IPFetcher.whoisInfo(ip: "1.2.3.4", executor: executor)
    // Should stop after finding both — first org wins
    #expect(info.org == "First Corp")
    #expect(info.country == "US")
}

// MARK: - stub-based proxyConfig

@Test("proxyConfig returns 无代理 when executor output is empty")
func proxyConfigNoProxy() async {
    // Stub returns empty output → isSuccess=true but trimmedOutput is empty → "无代理"
    let executor = ShellExecutor(stubbedOutputs: ["scutil --proxy": ""])
    let result = await IPFetcher.proxyConfig(executor: executor)
    #expect(result == "无代理")
}

@Test("dnsServers returns non-crashing result")
func dnsServersSmoke() async {
    let executor = ShellExecutor()
    let result = await IPFetcher.dnsServers(executor: executor)
    // Returns either real DNS servers or "N/A" — both are valid
    #expect(!result.isEmpty)
}

@Test("proxyConfig returns non-crashing result")
func proxyConfigSmoke() async {
    let executor = ShellExecutor()
    let result = await IPFetcher.proxyConfig(executor: executor)
    #expect(!result.isEmpty)
}

@Test("defaultGateway returns without crashing on any network configuration")
func defaultGatewaySmoke() async {
    let executor = ShellExecutor()
    // Call must not crash or hang; result may be IP, "N/A", or "" depending on host network
    let result = await IPFetcher.defaultGateway(executor: executor)
    // Verify it returns one of the three documented values:
    // - a valid IP string (non-empty, no "N/A")
    // - "N/A" (command failed)
    // - "" (command succeeded with no gateway line)
    let isValidReturn = result == "N/A" || IPFetcher.isValidIPv4(result) || result.isEmpty
    #expect(isValidReturn)
}

@Test("localInterfaces returns non-crashing result")
func localInterfacesSmoke() async {
    let executor = ShellExecutor()
    let result = await IPFetcher.localInterfaces(executor: executor)
    #expect(!result.isEmpty)
}
