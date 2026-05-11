//
//  GeoIPService.swift
//  MacAudit
//
//  免费 API 地理位置和风险检测模块。
//  并行请求 ip-api.com 和 ipapi.is 两个免费 API，获取 IP 的地理位置、
//  ISP、ASN、代理/VPN/Tor/数据中心检测等信息，合并后生成审计结果。
//

import Foundation

/// Phase B: 免费 API 地理位置和风险检测
struct GeoIPService: Sendable {

    /// ip-api.com 请求超时时间（秒）
    private static let ipAPITimeout: TimeInterval = 8
    /// ipapi.is 请求超时时间（秒）
    private static let ipapisTimeout: TimeInterval = 8

    /// 从 ip-api.com + ipapi.is 并行获取 IP 信息，合并为 AuditResult 数组
    /// - Parameters:
    ///   - ip: 待查询的公网 IP 地址
    /// - Returns: 包含地理位置、ISP、风险检测等信息的审计结果数组
    static func fetch(ip: String) async -> [AuditResult] {
        let checks = IPQualityModule().phaseBChecks()

        // 并行请求两个 API
        async let primary = fetchIPAPI(ip: ip)
        async let secondary = fetchIPAPIis(ip: ip)

        let ipapi = await primary
        let ipapisi = await secondary

        return mergeResults(checks: checks, ipapi: ipapi, ipapisi: ipapisi)
    }

    // MARK: - ip-api.com (第一梯队)

    /// 请求 ip-api.com 获取 IP 地理位置信息
    /// - Parameter ip: 待查询的 IP 地址
    /// - Returns: 解析成功返回 IPAPIResponse，失败返回 nil
    private static func fetchIPAPI(ip: String) async -> IPAPIResponse? {
        // fields=66846719 returns all fields including proxy/hosting/mobile
        guard let url = URL(string: "https://ip-api.com/json/\(ip)?fields=66846719") else {
            return nil
        }

        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = ipAPITimeout
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse else { return nil }

            // 速率限制
            if http.statusCode == 429 { return nil }
            guard http.statusCode == 200 else { return nil }

            return try JSONDecoder().decode(IPAPIResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - ipapi.is (第一梯队)

    /// 请求 ipapi.is 获取 IP 风险检测信息
    /// - Parameter ip: 待查询的 IP 地址
    /// - Returns: 解析成功返回 IPAPIIsResponse，失败返回 nil
    private static func fetchIPAPIis(ip: String) async -> IPAPIIsResponse? {
        guard let url = URL(string: "https://api.ipapi.is/?q=\(ip)") else {
            return nil
        }

        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = ipapisTimeout
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse else { return nil }
            if http.statusCode == 429 { return nil }
            guard http.statusCode == 200 else { return nil }

            return try JSONDecoder().decode(IPAPIIsResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - 合并结果

    /// 优先使用 ip-api.com 数据，ipapi.is 作为补充和风险增强
    /// - Parameters:
    ///   - checks: 审计检查项数组（需按固定顺序提供 11 项）
    ///   - ipapi: ip-api.com 的响应数据
    ///   - ipapisi: ipapi.is 的响应数据
    /// - Returns: 按检查项顺序生成的审计结果数组
    static func mergeResults(
        checks: [AuditCheck],
        ipapi: IPAPIResponse?,
        ipapisi: IPAPIIsResponse?
    ) -> [AuditResult] {
        // 如果两个 API 都失败
        if ipapi == nil && ipapisi == nil {
            return checks.map { .error(check: $0, error: "API 请求失败") }
        }

        var results: [AuditResult] = []

        // m13.geo_country
        let country = ipapi?.country ?? ipapisi?.location?.country ?? "N/A"
        let countryCode = ipapi?.countryCode ?? ipapisi?.location?.countryCode ?? ""
        let countryDisplay = countryCode.isEmpty ? country : "\(country) (\(countryCode))"
        results.append(.info(check: checks[0], actual: countryDisplay))

        // m13.geo_city
        let city = ipapi?.city ?? ipapisi?.location?.city ?? "N/A"
        let region = ipapi?.regionName ?? ipapisi?.location?.state ?? ""
        let cityDisplay = region.isEmpty ? city : "\(city), \(region)"
        results.append(.info(check: checks[1], actual: cityDisplay))

        // m13.geo_timezone
        let tz = ipapi?.timezone ?? ipapisi?.location?.timezone ?? "N/A"
        results.append(.info(check: checks[2], actual: tz))

        // m13.asn
        let asn = ipapi?.asField ?? {
            if let n = ipapisi?.asn?.asn { return "AS\(n)" }
            return nil
        }() ?? "N/A"
        let asnOrg = ipapisi?.asn?.org ?? ipapi?.org ?? ""
        let asnDisplay = asnOrg.isEmpty ? asn : "\(asn) (\(asnOrg))"
        results.append(.info(check: checks[3], actual: asnDisplay))

        // m13.isp
        let isp = ipapi?.isp ?? ipapisi?.company?.name ?? "N/A"
        results.append(.info(check: checks[4], actual: isp))

        // m13.is_proxy — risk check
        let isProxy = ipapi?.proxy ?? ipapisi?.isProxy ?? false
        results.append(riskResult(check: checks[5], flagged: isProxy, label: "代理"))

        // m13.is_vpn
        let isVpn = ipapisi?.isVpn ?? false
        results.append(riskResult(check: checks[6], flagged: isVpn, label: "VPN"))

        // m13.is_tor
        let isTor = ipapisi?.isTor ?? false
        results.append(riskResult(check: checks[7], flagged: isTor, label: "Tor"))

        // m13.is_datacenter — 两个 API 互补：ipapi.is(isDatacenter) + ip-api.com(hosting) 任一为 true 即标记
        // hosting 是比 datacenter 更宽的分类（含 VPN 出口/机房托管），两者都属于非住宅 IP
        let isDC = (ipapisi?.isDatacenter ?? false) || (ipapi?.hosting ?? false)
        results.append(riskResult(check: checks[8], flagged: isDC, label: "数据中心/托管"))

        // m13.ip_type
        let ipType: String
        if let compType = ipapisi?.company?.type, !compType.isEmpty {
            ipType = compType
        } else if ipapisi?.isDatacenter == true {
            ipType = "datacenter"
        } else if ipapi?.hosting == true {
            ipType = "hosting"
        } else if ipapi?.mobile == true {
            ipType = "mobile"
        } else {
            ipType = "residential"
        }
        // hosting/datacenter IP 类型属于注意项（可能被识别为代理出口）
        if ipType == "hosting" || ipType == "datacenter" || ipType == "business" {
            results.append(.warn(check: checks[9], actual: ipType,
                message: "IP 类型为 \(ipType)，可能被风控系统识别为代理/机房出口"))
        } else {
            results.append(.info(check: checks[9], actual: ipType))
        }

        // m13.risk_hosting
        let isHosting = ipapi?.hosting ?? ipapisi?.isDatacenter ?? false
        results.append(riskResult(check: checks[10], flagged: isHosting, label: "托管"))

        return results
    }

    /// 风险项：flagged=true → warn, false → pass
    /// - Parameters:
    ///   - check: 对应的审计检查项
    ///   - flagged: 是否检测到风险标记
    ///   - label: 风险类型标签（如 "代理"、"VPN"、"Tor"）
    /// - Returns: flagged 为 true 时返回 warn，否则返回 pass
    static func riskResult(check: AuditCheck, flagged: Bool, label: String) -> AuditResult {
        if flagged {
            return .warn(check: check, actual: "是", message: "\(check.name): 检测到\(label)")
        } else {
            return .pass(check: check, actual: "否")
        }
    }
}
