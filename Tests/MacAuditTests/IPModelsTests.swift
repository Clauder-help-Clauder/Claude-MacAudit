import Testing
import Foundation
@testable import MacAudit

// MARK: - IPModels Tests

private func decodeJSON<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
    let data = Data(json.utf8)
    return try JSONDecoder().decode(T.self, from: data)
}

// MARK: - IPAPIResponse

@Test("IPAPIResponse decodes full JSON with all fields")
func ipAPIResponseFullDecode() throws {
    let json = """
    {
        "status": "success",
        "country": "China",
        "countryCode": "CN",
        "region": "BJ",
        "regionName": "Beijing",
        "city": "Beijing",
        "zip": "100000",
        "lat": 39.9,
        "lon": 116.3,
        "timezone": "Asia/Shanghai",
        "isp": "China Telecom",
        "org": "China Telecom Beijing",
        "as": "AS4134 Chinanet",
        "query": "1.2.3.4",
        "mobile": false,
        "proxy": false,
        "hosting": false
    }
    """
    let response = try decodeJSON(json, as: IPAPIResponse.self)
    #expect(response.status == "success")
    #expect(response.country == "China")
    #expect(response.countryCode == "CN")
    #expect(response.region == "BJ")
    #expect(response.regionName == "Beijing")
    #expect(response.city == "Beijing")
    #expect(response.timezone == "Asia/Shanghai")
    #expect(response.isp == "China Telecom")
    #expect(response.asField == "AS4134 Chinanet")
    #expect(response.query == "1.2.3.4")
    #expect(response.mobile == false)
    #expect(response.proxy == false)
    #expect(response.hosting == false)
}

@Test("IPAPIResponse decodes minimal JSON with only status")
func ipAPIResponseMinimalDecode() throws {
    let json = """
    {"status": "fail"}
    """
    let response = try decodeJSON(json, as: IPAPIResponse.self)
    #expect(response.status == "fail")
    #expect(response.country == nil)
    #expect(response.countryCode == nil)
    #expect(response.city == nil)
    #expect(response.asField == nil)
    #expect(response.proxy == nil)
    #expect(response.hosting == nil)
    #expect(response.mobile == nil)
}

@Test("IPAPIResponse maps as JSON key to asField property")
func ipAPIResponseASFieldCodingKey() throws {
    let json = """
    {"status": "success", "as": "AS1234 Example Corp"}
    """
    let response = try decodeJSON(json, as: IPAPIResponse.self)
    #expect(response.asField == "AS1234 Example Corp")
}

@Test("IPAPIResponse proxy true decodes correctly")
func ipAPIResponseProxyTrue() throws {
    let json = """
    {"status": "success", "proxy": true, "hosting": true, "mobile": true}
    """
    let response = try decodeJSON(json, as: IPAPIResponse.self)
    #expect(response.proxy == true)
    #expect(response.hosting == true)
    #expect(response.mobile == true)
}

// MARK: - IPAPIIsResponse

@Test("IPAPIIsResponse decodes full JSON with all risk flags")
func ipAPIIsResponseFullDecode() throws {
    let json = """
    {
        "ip": "1.2.3.4",
        "rir": "APNIC",
        "is_datacenter": true,
        "is_tor": false,
        "is_proxy": true,
        "is_vpn": false,
        "is_abuser": false,
        "company": {"name": "Example Corp", "domain": "example.com", "type": "hosting"},
        "datacenter": {"name": "DC1", "domain": "dc1.com"},
        "asn": {"asn": 1234, "route": "1.2.3.0/24", "descr": "Example", "country": "US", "domain": "example.com", "org": "Example Org", "type": "isp"},
        "location": {"country": "United States", "country_code": "US", "state": "California", "city": "Los Angeles", "latitude": 34.05, "longitude": -118.24, "timezone": "America/Los_Angeles"}
    }
    """
    let response = try decodeJSON(json, as: IPAPIIsResponse.self)
    #expect(response.ip == "1.2.3.4")
    #expect(response.isDatacenter == true)
    #expect(response.isTor == false)
    #expect(response.isProxy == true)
    #expect(response.isVpn == false)
    #expect(response.isAbuser == false)
    #expect(response.company?.name == "Example Corp")
    #expect(response.company?.type == "hosting")
    #expect(response.datacenter?.name == "DC1")
    #expect(response.asn?.asn == 1234)
    #expect(response.asn?.org == "Example Org")
    #expect(response.location?.city == "Los Angeles")
    #expect(response.location?.countryCode == "US")
}

@Test("IPAPIIsResponse maps is_datacenter to isDatacenter")
func ipAPIIsResponseCodingKeys() throws {
    let json = """
    {"is_datacenter": true, "is_tor": true, "is_proxy": true, "is_vpn": true, "is_abuser": true}
    """
    let response = try decodeJSON(json, as: IPAPIIsResponse.self)
    #expect(response.isDatacenter == true)
    #expect(response.isTor == true)
    #expect(response.isProxy == true)
    #expect(response.isVpn == true)
    #expect(response.isAbuser == true)
}

@Test("IPAPIIsResponse decodes with nil nested objects")
func ipAPIIsResponseNilNested() throws {
    let json = """
    {"ip": "8.8.8.8"}
    """
    let response = try decodeJSON(json, as: IPAPIIsResponse.self)
    #expect(response.ip == "8.8.8.8")
    #expect(response.company == nil)
    #expect(response.datacenter == nil)
    #expect(response.asn == nil)
    #expect(response.location == nil)
    #expect(response.isDatacenter == nil)
    #expect(response.isTor == nil)
}

@Test("IPAPIIsLocation maps country_code to countryCode")
func ipAPIIsLocationCodingKey() throws {
    let json = """
    {"country": "Japan", "country_code": "JP", "city": "Tokyo"}
    """
    let location = try decodeJSON(json, as: IPAPIIsLocation.self)
    #expect(location.country == "Japan")
    #expect(location.countryCode == "JP")
    #expect(location.city == "Tokyo")
}

// MARK: - DNSBLResult

@Test("DNSBLResult constructs with all fields")
func dnsblResultConstruct() {
    let result = DNSBLResult(server: "bl.example.com", listed: true, error: nil)
    #expect(result.server == "bl.example.com")
    #expect(result.listed == true)
    #expect(result.error == nil)
}

@Test("DNSBLResult constructs with error string")
func dnsblResultWithError() {
    let result = DNSBLResult(server: "bl.example.com", listed: false, error: "timeout")
    #expect(result.server == "bl.example.com")
    #expect(result.listed == false)
    #expect(result.error == "timeout")
}
