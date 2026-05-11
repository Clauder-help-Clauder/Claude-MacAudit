import Testing
import Foundation
@testable import MacAudit

// MARK: - GeoIPService Tests

private func makeIPAPI(
    status: String = "success",
    country: String? = nil,
    countryCode: String? = nil,
    regionName: String? = nil,
    city: String? = nil,
    timezone: String? = nil,
    isp: String? = nil,
    org: String? = nil,
    asField: String? = nil,
    proxy: Bool? = nil,
    hosting: Bool? = nil,
    mobile: Bool? = nil
) throws -> IPAPIResponse {
    var dict: [String: Any] = ["status": status]
    if let v = country       { dict["country"] = v }
    if let v = countryCode   { dict["countryCode"] = v }
    if let v = regionName    { dict["regionName"] = v }
    if let v = city          { dict["city"] = v }
    if let v = timezone      { dict["timezone"] = v }
    if let v = isp           { dict["isp"] = v }
    if let v = org           { dict["org"] = v }
    if let v = asField       { dict["as"] = v }
    if let v = proxy         { dict["proxy"] = v }
    if let v = hosting       { dict["hosting"] = v }
    if let v = mobile        { dict["mobile"] = v }
    let data = try JSONSerialization.data(withJSONObject: dict)
    return try JSONDecoder().decode(IPAPIResponse.self, from: data)
}

private func makeIPAPIIs(
    isProxy: Bool? = nil,
    isVpn: Bool? = nil,
    isTor: Bool? = nil,
    isDatacenter: Bool? = nil,
    companyType: String? = nil,
    asnNumber: Int? = nil,
    locationCountry: String? = nil,
    locationCode: String? = nil,
    locationCity: String? = nil,
    locationState: String? = nil
) throws -> IPAPIIsResponse {
    var dict: [String: Any] = [:]
    if let v = isProxy       { dict["is_proxy"] = v }
    if let v = isVpn         { dict["is_vpn"] = v }
    if let v = isTor         { dict["is_tor"] = v }
    if let v = isDatacenter  { dict["is_datacenter"] = v }
    if let t = companyType   { dict["company"] = ["type": t] }
    if let n = asnNumber     { dict["asn"] = ["asn": n] }
    if locationCountry != nil || locationCode != nil || locationCity != nil || locationState != nil {
        var loc: [String: Any] = [:]
        if let v = locationCountry { loc["country"] = v }
        if let v = locationCode    { loc["country_code"] = v }
        if let v = locationCity    { loc["city"] = v }
        if let v = locationState   { loc["state"] = v }
        dict["location"] = loc
    }
    let data = try JSONSerialization.data(withJSONObject: dict)
    return try JSONDecoder().decode(IPAPIIsResponse.self, from: data)
}

private let phaseB = IPQualityModule().phaseBChecks()

// MARK: - Both nil

@Test("mergeResults both nil returns 11 error results")
func mergeResultsBothNilAllError() {
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: nil)
    #expect(results.count == 11)
    for r in results {
        #expect(r.status == .error)
    }
}

// MARK: - Only ipapi

@Test("mergeResults only ipapi fills geo fields")
func mergeResultsOnlyIPAPI() throws {
    let ipapi = try makeIPAPI(country: "China", countryCode: "CN",
                               regionName: "Beijing", city: "Beijing",
                               timezone: "Asia/Shanghai", isp: "Chinanet",
                               asField: "AS4134 Chinanet")
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    #expect(results.count == 11)

    let country = results.first { $0.checkId == "m13.geo_country" }
    #expect(country?.actualValue == "China (CN)")

    let city = results.first { $0.checkId == "m13.geo_city" }
    #expect(city?.actualValue == "Beijing, Beijing")

    let tz = results.first { $0.checkId == "m13.geo_timezone" }
    #expect(tz?.actualValue == "Asia/Shanghai")

    let isp = results.first { $0.checkId == "m13.isp" }
    #expect(isp?.actualValue == "Chinanet")
}

@Test("mergeResults only ipapi risk flags default to false (pass)")
func mergeResultsOnlyIPAPIRiskDefaults() throws {
    let ipapi = try makeIPAPI()
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)

    let isProxy = results.first { $0.checkId == "m13.is_proxy" }
    #expect(isProxy?.status == .pass)
    #expect(isProxy?.actualValue == "否")

    let isVpn = results.first { $0.checkId == "m13.is_vpn" }
    #expect(isVpn?.status == .pass)

    let isTor = results.first { $0.checkId == "m13.is_tor" }
    #expect(isTor?.status == .pass)
}

// MARK: - Only ipapisi

@Test("mergeResults only ipapisi fills geo from location")
func mergeResultsOnlyIPAPIis() throws {
    let ipapisi = try makeIPAPIIs(
        asnNumber: 7670,
        locationCountry: "Japan", locationCode: "JP",
        locationCity: "Tokyo", locationState: "Tokyo"
    )
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: ipapisi)
    #expect(results.count == 11)

    let country = results.first { $0.checkId == "m13.geo_country" }
    #expect(country?.actualValue == "Japan (JP)")

    let city = results.first { $0.checkId == "m13.geo_city" }
    #expect(city?.actualValue?.contains("Tokyo") == true)

    let asn = results.first { $0.checkId == "m13.asn" }
    #expect(asn?.actualValue?.contains("AS7670") == true)
}

// MARK: - Risk flags

@Test("riskResult flagged true produces warn with 是")
func riskResultFlaggedTrue() {
    let check = phaseB.first { $0.id == "m13.is_proxy" }!
    let result = GeoIPService.riskResult(check: check, flagged: true, label: "代理")
    #expect(result.status == .warn)
    #expect(result.actualValue == "是")
}

@Test("riskResult flagged false produces pass with 否")
func riskResultFlaggedFalse() {
    let check = phaseB.first { $0.id == "m13.is_proxy" }!
    let result = GeoIPService.riskResult(check: check, flagged: false, label: "代理")
    #expect(result.status == .pass)
    #expect(result.actualValue == "否")
}

@Test("mergeResults is_proxy true from ipapi produces warn")
func mergeResultsIsProxyFromIPAPI() throws {
    let ipapi = try makeIPAPI(proxy: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.is_proxy" }
    #expect(r?.status == .warn)
    #expect(r?.actualValue == "是")
}

@Test("mergeResults is_vpn true from ipapisi produces warn")
func mergeResultsIsVpnFromIPAPIis() throws {
    let ipapisi = try makeIPAPIIs(isVpn: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.is_vpn" }
    #expect(r?.status == .warn)
    #expect(r?.actualValue == "是")
}

@Test("mergeResults is_tor true produces warn")
func mergeResultsIsTorTrue() throws {
    let ipapisi = try makeIPAPIIs(isTor: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.is_tor" }
    #expect(r?.status == .warn)
}

@Test("mergeResults is_datacenter true produces warn")
func mergeResultsIsDatacenterTrue() throws {
    let ipapisi = try makeIPAPIIs(isDatacenter: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.is_datacenter" }
    #expect(r?.status == .warn)
}

// MARK: - IP type priority

@Test("mergeResults ip_type uses company.type first")
func mergeResultsIPTypeCompanyFirst() throws {
    let ipapisi = try makeIPAPIIs(isDatacenter: true, companyType: "isp")
    let ipapi = try makeIPAPI(hosting: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.ip_type" }
    #expect(r?.actualValue == "isp")
}

@Test("mergeResults ip_type falls back to datacenter when no company type")
func mergeResultsIPTypeDatacenterFallback() throws {
    let ipapisi = try makeIPAPIIs(isDatacenter: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.ip_type" }
    #expect(r?.actualValue == "datacenter")
}

@Test("mergeResults ip_type defaults to residential")
func mergeResultsIPTypeResidentialDefault() throws {
    let ipapi = try makeIPAPI()
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.ip_type" }
    #expect(r?.actualValue == "residential")
}

// MARK: - Country display format

@Test("mergeResults country displays as Name (Code) format")
func mergeResultsCountryDisplayFormat() throws {
    let ipapi = try makeIPAPI(country: "Germany", countryCode: "DE")
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.geo_country" }
    #expect(r?.actualValue == "Germany (DE)")
}

// MARK: - ip_type additional branches

@Test("mergeResults ip_type falls back to hosting when ipapi.hosting=true")
func mergeResultsIPTypeHostingFallback() throws {
    // No company.type, no isDatacenter, but ipapi.hosting=true → "hosting"
    let ipapi = try makeIPAPI(hosting: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.ip_type" }
    #expect(r?.actualValue == "hosting")
}

@Test("mergeResults ip_type falls back to mobile when ipapi.mobile=true")
func mergeResultsIPTypeMobileFallback() throws {
    // No company.type, no isDatacenter, no hosting, but ipapi.mobile=true → "mobile"
    let ipapi = try makeIPAPI(mobile: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.ip_type" }
    #expect(r?.actualValue == "mobile")
}

// MARK: - risk_hosting (checks[10])

@Test("mergeResults risk_hosting warn when ipapi.hosting=true")
func mergeResultsRiskHostingFromIPAPI() throws {
    let ipapi = try makeIPAPI(hosting: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.risk_hosting" }
    #expect(r?.status == .warn)
    #expect(r?.actualValue == "是")
}

@Test("mergeResults risk_hosting warn when ipapisi.isDatacenter=true and ipapi.hosting=nil")
func mergeResultsRiskHostingFromIPAPIIs() throws {
    // ipapi.hosting is nil → falls back to ipapisi.isDatacenter
    let ipapisi = try makeIPAPIIs(isDatacenter: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: nil, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.risk_hosting" }
    #expect(r?.status == .warn)
}

@Test("mergeResults risk_hosting pass when both hosting signals are false")
func mergeResultsRiskHostingClean() throws {
    let ipapi = try makeIPAPI(hosting: false)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.risk_hosting" }
    #expect(r?.status == .pass)
    #expect(r?.actualValue == "否")
}

// MARK: - ASN display format

@Test("mergeResults asn displays as AS1234 (Org) when org is available")
func mergeResultsASNWithOrg() throws {
    let ipapisi = try makeIPAPIIs(asnNumber: 4134)
    // ipapi.org provides the org name
    let ipapi = try makeIPAPI(org: "Chinanet", asField: "AS4134 Chinanet")
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.asn" }
    // asnOrg = ipapisi.asn.org (nil here) ?? ipapi.org ("Chinanet")
    #expect(r?.actualValue?.contains("Chinanet") == true)
}

// MARK: - Country without code

@Test("mergeResults country displays name only when countryCode is empty")
func mergeResultsCountryNoCode() throws {
    let ipapi = try makeIPAPI(country: "Unknown Region")
    // No countryCode → display name only
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: nil)
    let r = results.first { $0.checkId == "m13.geo_country" }
    #expect(r?.actualValue == "Unknown Region")
}

// MARK: - ipapi proxy priority over ipapisi

@Test("mergeResults is_proxy uses ipapi.proxy when both present (ipapi wins)")
func mergeResultsIsProxyPriority() throws {
    // ipapi.proxy=false should win over ipapisi.isProxy=true
    let ipapi = try makeIPAPI(proxy: false)
    let ipapisi = try makeIPAPIIs(isProxy: true)
    let results = GeoIPService.mergeResults(checks: phaseB, ipapi: ipapi, ipapisi: ipapisi)
    let r = results.first { $0.checkId == "m13.is_proxy" }
    // ipapi?.proxy = false → isProxy = false ?? ... = false
    #expect(r?.status == .pass)
}
