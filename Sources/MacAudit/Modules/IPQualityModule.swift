//
//  IPQualityModule.swift
//  MacAudit
//
//  M13: IP 质量检测模块
//  分四阶段检测 IP 质量：Phase A 本地 IP 信息、Phase B API 地理位置和风险评估、
//  Phase C DNSBL 黑名单、Phase D 邮件端口连通性。
//  网络不可用时自动降级为仅本地检测模式。
//

import Foundation
import MacAuditCore

/// M13: IP 质量检测模块
struct IPQualityModule: AuditModule {
    /// 模块唯一标识
    let id = "ip_quality"
    /// 模块显示名称
    let name = "IP 质量检测"
    /// 模块功能描述
    let description = "IP 地址质量和风险评估"

    /// 汇总所有阶段的检查项定义
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        var items: [AuditCheck] = []

        // Phase A: 本地检测
        items.append(contentsOf: phaseAChecks())

        // Phase B: API 地理位置和风险
        items.append(contentsOf: phaseBChecks())

        // Phase C: DNSBL
        items.append(contentsOf: phaseCChecks())

        // Phase D: 邮件端口
        items.append(contentsOf: phaseDChecks())

        return items
    }

    /// 执行 IP 质量检测：网络预检后分阶段执行本地检测、API 地理查询、DNSBL 检查、邮件端口检测
    func run(
        version: MacOSVersion,
        device: DeviceType,
        arch: CPUArchitecture,
        executor: ShellExecutor
    ) async -> [AuditResult] {
        var results: [AuditResult] = []
        let total = checks(for: version, device: device, arch: arch).count

        // === 网络预检 ===
        InteractiveUI.updateProgress(module: name, current: 0, total: total)
        let netCheck = await executor.run("curl -s --max-time 6 https://ifconfig.me 2>/dev/null")
        let networkAvailable = netCheck.isSuccess && netCheck.hasOutput

        if !networkAvailable {
            // 仅运行本地检测
            results.append(contentsOf: await runPhaseAOffline(executor: executor))
            InteractiveUI.clearProgress()
            return results
        }

        // === Phase A: 本地 IP 信息 ===
        let phaseAResults = await runPhaseA(executor: executor)
        results.append(contentsOf: phaseAResults)

        // 提取公网 IP 供后续阶段使用
        let publicIP = phaseAResults
            .first { $0.checkId == "m13.public_ipv4" && $0.status != .error }?
            .actualValue ?? ""

        var progress = results.count

        if !publicIP.isEmpty {
            // === Phase B: API 地理位置和风险（并行） ===
            let phaseBResults = await GeoIPService.fetch(ip: publicIP)
            results.append(contentsOf: phaseBResults)
            progress = results.count
            InteractiveUI.updateProgress(module: name, current: progress, total: total)

            // === Phase C & D 并行 ===
            async let phaseCResults = DNSBLChecker.check(ip: publicIP, executor: executor)
            async let phaseDResults = MailChecker.check(executor: executor)

            let cResults = await phaseCResults
            let dResults = await phaseDResults
            results.append(contentsOf: cResults)
            results.append(contentsOf: dResults)
        } else {
            // 无公网 IP，跳过 Phase B/C/D
            let skipChecks = phaseBChecks() + phaseCChecks() + phaseDChecks()
            for check in skipChecks {
                results.append(.skip(check: check, reason: "无法获取公网 IP"))
            }
        }

        InteractiveUI.updateProgress(module: name, current: total, total: total)
        InteractiveUI.clearProgress()
        return results
    }

    // MARK: - Phase A: 本地 IP 信息并行获取与结果组装

    /// Phase A 执行：并行获取公网 IPv4/IPv6、本地接口、DNS、代理、网关，然后获取反向 DNS 和 whois
    private func runPhaseA(executor: ShellExecutor) async -> [AuditResult] {
        var results: [AuditResult] = []
        let checks = phaseAChecks()
        let checksById = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
        let total = self.checks(for: .sequoia, device: .laptop, arch: .arm64).count

        // 并行获取所有本地信息
        async let ipv4 = IPFetcher.publicIPv4(executor: executor)
        async let ipv6 = IPFetcher.publicIPv6(executor: executor)
        async let localIFs = IPFetcher.localInterfaces(executor: executor)
        async let dns = IPFetcher.dnsServers(executor: executor)
        async let proxy = IPFetcher.proxyConfig(executor: executor)
        async let gateway = IPFetcher.defaultGateway(executor: executor)

        let v4 = await ipv4
        let v6 = await ipv6
        let ifs = await localIFs
        let dnsResult = await dns
        let proxyResult = await proxy
        let gw = await gateway

        // IPv4
        if let check = checksById["m13.public_ipv4"] {
            if let v4 {
                results.append(.info(check: check, actual: v4))
            } else {
                results.append(.error(check: check, error: "无法获取公网 IPv4"))
            }
        }

        // IPv6
        if let check = checksById["m13.public_ipv6"] {
            results.append(.info(check: check, actual: v6 ?? "不可用"))
        }

        // 本地接口
        if let check = checksById["m13.local_interfaces"] {
            results.append(.info(check: check, actual: ifs.isEmpty ? "N/A" : ifs))
        }

        // DNS
        if let check = checksById["m13.dns_servers"] {
            results.append(.info(check: check, actual: dnsResult.isEmpty ? "N/A" : dnsResult))
        }

        // 代理
        if let check = checksById["m13.proxy_config"] {
            results.append(.info(check: check, actual: proxyResult))
        }

        // 网关
        if let check = checksById["m13.default_gateway"] {
            results.append(.info(check: check, actual: gw.isEmpty ? "N/A" : gw))
        }

        InteractiveUI.updateProgress(module: name, current: 6, total: total)

        // 反向 DNS 和 whois（依赖 IPv4）
        if let v4 {
            async let rdns = IPFetcher.reverseDNS(ip: v4, executor: executor)
            async let whois = IPFetcher.whoisInfo(ip: v4, executor: executor)

            let rdnsResult = await rdns
            let whoisResult = await whois

            if let check = checksById["m13.reverse_dns"] {
                results.append(.info(check: check, actual: rdnsResult ?? "无记录"))
            }
            if let check = checksById["m13.whois_org"] {
                results.append(.info(check: check, actual: whoisResult.org ?? "N/A"))
            }
            if let check = checksById["m13.whois_country"] {
                results.append(.info(check: check, actual: whoisResult.country ?? "N/A"))
            }
        } else {
            if let check = checksById["m13.reverse_dns"] {
                results.append(.skip(check: check, reason: "无公网 IP"))
            }
            if let check = checksById["m13.whois_org"] {
                results.append(.skip(check: check, reason: "无公网 IP"))
            }
            if let check = checksById["m13.whois_country"] {
                results.append(.skip(check: check, reason: "无公网 IP"))
            }
        }

        InteractiveUI.updateProgress(module: name, current: 9, total: total)
        return results
    }

    /// 离线模式：仅本地数据（网络不可用时降级执行）
    private func runPhaseAOffline(executor: ShellExecutor) async -> [AuditResult] {
        let checks = phaseAChecks()
        let checksById = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
        var results: [AuditResult] = []

        if let check = checksById["m13.public_ipv4"] {
            results.append(.error(check: check, error: "网络不可用"))
        }
        if let check = checksById["m13.public_ipv6"] {
            results.append(.error(check: check, error: "网络不可用"))
        }

        let ifs = await IPFetcher.localInterfaces(executor: executor)
        if let check = checksById["m13.local_interfaces"] {
            results.append(.info(check: check, actual: ifs.isEmpty ? "N/A" : ifs))
        }

        let dns = await IPFetcher.dnsServers(executor: executor)
        if let check = checksById["m13.dns_servers"] {
            results.append(.info(check: check, actual: dns.isEmpty ? "N/A" : dns))
        }

        let proxy = await IPFetcher.proxyConfig(executor: executor)
        if let check = checksById["m13.proxy_config"] {
            results.append(.info(check: check, actual: proxy))
        }

        let gw = await IPFetcher.defaultGateway(executor: executor)
        if let check = checksById["m13.default_gateway"] {
            results.append(.info(check: check, actual: gw.isEmpty ? "N/A" : gw))
        }

        // 无网络，跳过 rdns/whois
        for id in ["m13.reverse_dns", "m13.whois_org", "m13.whois_country"] {
            if let check = checksById[id] {
                results.append(.skip(check: check, reason: "网络不可用"))
            }
        }

        // 跳过 Phase B/C/D
        let skipChecks = phaseBChecks() + phaseCChecks() + phaseDChecks()
        for check in skipChecks {
            results.append(.skip(check: check, reason: "网络不可用"))
        }

        return results
    }

    // MARK: - 各阶段检查项定义

    /// Phase A: 本地 IP 信息检查项（IPv4/IPv6、接口、DNS、代理、网关、反向 DNS、whois）
    func phaseAChecks() -> [AuditCheck] {
        [
            AuditCheck(id: "m13.public_ipv4", name: "公网 IPv4", module: id,
                       description: "获取公网 IPv4 地址", command: "[Local] curl ifconfig.me",
                       tags: ["ip", "network"],
                       priority: .a0),
            AuditCheck(id: "m13.public_ipv6", name: "公网 IPv6", module: id,
                       description: "获取公网 IPv6 地址", command: "[Local] curl ipv6.icanhazip.com",
                       tags: ["ip", "network"],
                       priority: .a0),
            AuditCheck(id: "m13.local_interfaces", name: "本地网络接口", module: id,
                       description: "本机 IP 地址", command: "[Local] ifconfig",
                       tags: ["ip", "network"],
                       priority: .a0),
            AuditCheck(id: "m13.dns_servers", name: "DNS 服务器", module: id,
                       description: "系统 DNS 配置", command: "[Local] scutil --dns",
                       tags: ["dns", "network"],
                       priority: .a0),
            AuditCheck(id: "m13.proxy_config", name: "代理配置", module: id,
                       description: "系统代理设置", command: "[Local] scutil --proxy",
                       tags: ["proxy", "network"],
                       priority: .a0),
            AuditCheck(id: "m13.default_gateway", name: "默认网关", module: id,
                       description: "默认路由网关", command: "[Local] route -n get default",
                       tags: ["network"],
                       priority: .a0),
            AuditCheck(id: "m13.reverse_dns", name: "反向 DNS", module: id,
                       description: "公网 IP 反向解析", command: "[Local] dig +short -x",
                       tags: ["dns", "ip"],
                       priority: .a0),
            AuditCheck(id: "m13.whois_org", name: "Whois 组织", module: id,
                       description: "IP 归属组织", command: "[Local] whois",
                       tags: ["ip"],
                       priority: .a0),
            AuditCheck(id: "m13.whois_country", name: "Whois 国家", module: id,
                       description: "IP 归属国家", command: "[Local] whois",
                       tags: ["ip"],
                       priority: .a0),
        ]
    }

    /// Phase B: API 地理位置和风险评估检查项（国家、城市、时区、ASN、ISP、代理/VPN/Tor/数据中心检测）
    func phaseBChecks() -> [AuditCheck] {
        [
            AuditCheck(id: "m13.geo_country", name: "所在国家", module: id,
                       description: "API 地理位置", command: "[API] ip-api.com",
                       tags: ["geo"],
                       priority: .a0),
            AuditCheck(id: "m13.geo_city", name: "所在城市", module: id,
                       description: "API 城市定位", command: "[API] ip-api.com",
                       tags: ["geo"],
                       priority: .a0),
            AuditCheck(id: "m13.geo_timezone", name: "时区", module: id,
                       description: "IP 时区", command: "[API] ip-api.com",
                       tags: ["geo"],
                       priority: .a0),
            AuditCheck(id: "m13.asn", name: "ASN", module: id,
                       description: "自治系统编号", command: "[API] ip-api.com",
                       tags: ["asn"],
                       priority: .a0),
            AuditCheck(id: "m13.isp", name: "ISP", module: id,
                       description: "互联网服务提供商", command: "[API] ip-api.com",
                       tags: ["isp"],
                       priority: .a0),
            AuditCheck(id: "m13.is_proxy", name: "代理检测", module: id,
                       description: "是否为代理 IP", command: "[API] ip-api.com",
                       tags: ["risk"],
                       priority: .a0),
            AuditCheck(id: "m13.is_vpn", name: "VPN 检测", module: id,
                       description: "是否为 VPN IP", command: "[API] ipapi.is",
                       tags: ["risk"],
                       priority: .a0),
            AuditCheck(id: "m13.is_tor", name: "Tor 检测", module: id,
                       description: "是否为 Tor 出口节点", command: "[API] ipapi.is",
                       tags: ["risk"],
                       priority: .a0),
            AuditCheck(id: "m13.is_datacenter", name: "数据中心检测", module: id,
                       description: "是否为数据中心 IP", command: "[API] ipapi.is",
                       tags: ["risk"],
                       priority: .a0),
            AuditCheck(id: "m13.ip_type", name: "IP 类型", module: id,
                       description: "住宅/商业/数据中心", command: "[API] ipapi.is",
                       tags: ["risk"],
                       priority: .a0),
            AuditCheck(id: "m13.risk_hosting", name: "托管检测", module: id,
                       description: "是否为托管 IP", command: "[API] ip-api.com",
                       tags: ["risk"],
                       priority: .a0),
        ]
    }

    /// Phase C: DNSBL 黑名单检测检查项
    func phaseCChecks() -> [AuditCheck] {
        [
            AuditCheck(id: "m13.dnsbl_summary", name: "DNSBL 黑名单", module: id,
                       description: "DNS 黑名单检测汇总", command: "[DNS] DNSBL x13",
                       tags: ["dnsbl", "risk"],
                       priority: .a0),
        ]
    }

    /// Phase D: 邮件端口连通性检查项（SMTP 25/587）
    func phaseDChecks() -> [AuditCheck] {
        [
            AuditCheck(id: "m13.smtp_port25", name: "SMTP Port 25", module: id,
                       description: "SMTP 25 端口连通", command: "[TCP] port 25",
                       tags: ["mail"],
                       priority: .a0),
            AuditCheck(id: "m13.smtp_port587", name: "SMTP Port 587", module: id,
                       description: "SMTP 587 端口连通", command: "[TCP] port 587",
                       tags: ["mail"],
                       priority: .a0),
        ]
    }
}
