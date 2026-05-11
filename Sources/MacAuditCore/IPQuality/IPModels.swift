import Foundation

// MARK: - ip-api.com response

struct IPAPIResponse: Decodable, Sendable {
    let status: String          // "success" or "fail"
    let country: String?
    let countryCode: String?
    let region: String?
    let regionName: String?
    let city: String?
    let zip: String?
    let lat: Double?
    let lon: Double?
    let timezone: String?
    let isp: String?
    let org: String?
    let asField: String?        // "AS" in JSON
    let query: String?          // the IP queried
    let mobile: Bool?
    let proxy: Bool?
    let hosting: Bool?

    enum CodingKeys: String, CodingKey {
        case status, country, countryCode, region, regionName
        case city, zip, lat, lon, timezone, isp, org
        case asField = "as"
        case query, mobile, proxy, hosting
    }
}

// MARK: - ipapi.is response

struct IPAPIIsResponse: Decodable, Sendable {
    let ip: String?
    let rir: String?
    let isDatacenter: Bool?
    let isTor: Bool?
    let isProxy: Bool?
    let isVpn: Bool?
    let isAbuser: Bool?
    let company: IPAPIIsCompany?
    let datacenter: IPAPIIsDatacenter?
    let asn: IPAPIIsASN?
    let location: IPAPIIsLocation?

    enum CodingKeys: String, CodingKey {
        case ip, rir
        case isDatacenter = "is_datacenter"
        case isTor = "is_tor"
        case isProxy = "is_proxy"
        case isVpn = "is_vpn"
        case isAbuser = "is_abuser"
        case company, datacenter, asn, location
    }
}

struct IPAPIIsCompany: Decodable, Sendable {
    let name: String?
    let domain: String?
    let type: String?
}

struct IPAPIIsDatacenter: Decodable, Sendable {
    let name: String?
    let domain: String?
}

struct IPAPIIsASN: Decodable, Sendable {
    let asn: Int?
    let route: String?
    let descr: String?
    let country: String?
    let domain: String?
    let org: String?
    let type: String?
}

struct IPAPIIsLocation: Decodable, Sendable {
    let country: String?
    let countryCode: String?
    let state: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case country
        case countryCode = "country_code"
        case state, city, latitude, longitude, timezone
    }
}

// MARK: - DNSBL result

struct DNSBLResult: Sendable {
    let server: String
    let listed: Bool
    let error: String?
}
