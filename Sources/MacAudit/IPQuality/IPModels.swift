//
//  IPModels.swift
//  MacAudit
//
//  IP 质量检测相关的数据模型定义。
//  包含 ip-api.com 和 ipapi.is 两个 API 的响应模型、
//  DNSBL 查询结果模型。所有模型均为 Decodable + Sendable。
//

import Foundation

// MARK: - ip-api.com response

/// ip-api.com JSON 响应模型
struct IPAPIResponse: Decodable, Sendable {
    /// 请求状态，"success" 或 "fail"
    let status: String
    /// 国家名称
    let country: String?
    /// 国家代码（如 "US"、"CN"）
    let countryCode: String?
    /// 地区代码
    let region: String?
    /// 地区名称
    let regionName: String?
    /// 城市名称
    let city: String?
    /// 邮政编码
    let zip: String?
    /// 纬度
    let lat: Double?
    /// 经度
    let lon: Double?
    /// 时区（如 "America/New_York"）
    let timezone: String?
    /// ISP 名称
    let isp: String?
    /// 组织名称
    let org: String?
    /// AS 编号及描述（如 "AS15169 Google LLC"），JSON key 为 "as"
    let asField: String?
    /// 查询的 IP 地址
    let query: String?
    /// 是否为移动网络 IP
    let mobile: Bool?
    /// 是否为代理 IP
    let proxy: Bool?
    /// 是否为托管/数据中心 IP
    let hosting: Bool?

    enum CodingKeys: String, CodingKey {
        case status, country, countryCode, region, regionName
        case city, zip, lat, lon, timezone, isp, org
        case asField = "as"
        case query, mobile, proxy, hosting
    }
}

// MARK: - ipapi.is response

/// ipapi.is JSON 响应模型
struct IPAPIIsResponse: Decodable, Sendable {
    /// 查询的 IP 地址
    let ip: String?
    /// 区域互联网注册机构（如 "ARIN"、"APNIC"）
    let rir: String?
    /// 是否为数据中心 IP
    let isDatacenter: Bool?
    /// 是否为 Tor 出口节点
    let isTor: Bool?
    /// 是否为代理 IP
    let isProxy: Bool?
    /// 是否为 VPN 出口 IP
    let isVpn: Bool?
    /// 是否为滥用 IP
    let isAbuser: Bool?
    /// IP 所属公司信息
    let company: IPAPIIsCompany?
    /// 数据中心详细信息
    let datacenter: IPAPIIsDatacenter?
    /// ASN 信息
    let asn: IPAPIIsASN?
    /// 地理位置信息
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

/// ipapi.is 公司信息
struct IPAPIIsCompany: Decodable, Sendable {
    /// 公司名称
    let name: String?
    /// 公司域名
    let domain: String?
    /// 网络类型（如 "isp"、"hosting"、"business"）
    let type: String?
}

/// ipapi.is 数据中心信息
struct IPAPIIsDatacenter: Decodable, Sendable {
    /// 数据中心名称
    let name: String?
    /// 数据中心域名
    let domain: String?
}

/// ipapi.is ASN 信息
struct IPAPIIsASN: Decodable, Sendable {
    /// ASN 编号
    let asn: Int?
    /// 路由前缀（如 "8.8.8.0/24"）
    let route: String?
    /// ASN 描述
    let descr: String?
    /// ASN 所属国家
    let country: String?
    /// ASN 域名
    let domain: String?
    /// ASN 组织名
    let org: String?
    /// 网络类型（如 "isp"、"hosting"）
    let type: String?
}

/// ipapi.is 地理位置信息
struct IPAPIIsLocation: Decodable, Sendable {
    /// 国家名称
    let country: String?
    /// 国家代码
    let countryCode: String?
    /// 州/省
    let state: String?
    /// 城市名称
    let city: String?
    /// 纬度
    let latitude: Double?
    /// 经度
    let longitude: Double?
    /// 时区
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case country
        case countryCode = "country_code"
        case state, city, latitude, longitude, timezone
    }
}

// MARK: - DNSBL result

/// 单个 DNSBL 服务器的查询结果
struct DNSBLResult: Sendable {
    /// DNSBL 服务器域名
    let server: String
    /// 该 IP 是否被列入黑名单
    let listed: Bool
    /// 查询错误信息（超时或查询失败），无错误时为 nil
    let error: String?
}
