//
//  DNSBLChecker.swift
//  MacAudit
//
//  DNSBL (DNS-based Blackhole List) 黑名单检测模块。
//  通过反查 IP 地址到多个 DNSBL 服务器，判断 IP 是否被列入垃圾邮件黑名单。
//  并行查询 13 个已验证的 DNSBL 服务器，汇总结果生成审计报告。
//

import Foundation
import MacAuditCore

/// Phase C: DNSBL 黑名单检测
struct DNSBLChecker: Sendable {

    /// 验证 IPv4 地址格式是否合法
    /// - Parameter ip: 待验证的 IP 地址字符串
    /// - Returns: 是否为合法的 IPv4 地址
    static func validateIPv4(_ ip: String) -> Bool {
        IPv4Validator.isValid(ip)
    }

    /// Top 13 已验证的 DNSBL 服务器（"quick" 模式）
    static let verifiedServers: [String] = [
        "b.barracudacentral.org",
        "bl.spamcop.net",
        "dnsbl-1.uceprotect.net",
        "psbl.surriel.com",
        "all.s5h.net",
        "rbl.interserver.net",
        "dnsbl.dronebl.org",
        "noptr.spamrats.com",
        "dyna.spamrats.com",
        "spam.spamrats.com",
        "bl.mailspike.net",
        "z.mailspike.net",
        "bl.0spam.org",
    ]

    /// 并行查询所有 DNSBL 服务器，返回汇总结果
    static func check(ip: String, executor: ShellExecutor) async -> [AuditResult] {
        let summaryCheck = IPQualityModule().phaseCChecks()[0]

        if !validateIPv4(ip) {
            return [AuditResult.error(check: summaryCheck, error: "无效的 IPv4 地址: \(ip.prefix(20))")]
        }

        // 反转 IP: 1.2.3.4 → 4.3.2.1
        let reversed = ip.split(separator: ".").reversed().joined(separator: ".")

        // 并行查询
        let results = await withTaskGroup(of: DNSBLResult.self) { group in
            for server in verifiedServers {
                group.addTask {
                    await querySingle(reversed: reversed, server: server, executor: executor)
                }
            }
            var collected: [DNSBLResult] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        return [summarize(results: results, check: summaryCheck)]
    }

    /// 汇总 DNSBL 查询结果为单条 AuditResult
    /// - Parameters:
    ///   - results: 所有 DNSBL 服务器的查询结果数组
    ///   - check: 对应的审计检查项
    /// - Returns: 汇总后的审计结果（pass/warn/fail）
    ///   - 0 个列入 → pass
    ///   - 1-2 个列入 → warn
    ///   - 3 个及以上列入 → fail
    static func summarize(results: [DNSBLResult], check: AuditCheck) -> AuditResult {
        let total = results.count
        let listed = results.filter { $0.listed }.count
        let clean = total - listed
        let errors = results.filter { $0.error != nil }.count

        // 构建详情字符串
        let listedServers = results.filter { $0.listed }.map(\.server)

        let actual: String
        if listed == 0 {
            actual = "干净 \(clean)/\(total)"
        } else {
            actual = "列入 \(listed)/\(total): \(listedServers.joined(separator: ", "))"
        }

        if listed == 0 {
            return .pass(
                check: check,
                actual: actual,
                message: "DNSBL: 未列入黑名单 (\(clean)/\(total) 干净\(errors > 0 ? ", \(errors) 查询失败" : ""))"
            )
        } else if listed <= 2 {
            return .warn(
                check: check,
                actual: actual,
                message: "DNSBL: 列入 \(listed) 个黑名单"
            )
        } else {
            return .fail(
                check: check,
                actual: actual,
                message: "DNSBL: 列入 \(listed) 个黑名单（风险较高）"
            )
        }
    }

    /// 查询单个 DNSBL 服务器
    /// - Parameters:
    ///   - reversed: 反转后的 IP 地址（如 "4.3.2.1"）
    ///   - server: DNSBL 服务器域名
    ///   - executor: Shell 命令执行器
    /// - Returns: 该服务器的 DNSBL 查询结果
    static func querySingle(
        reversed: String,
        server: String,
        executor: ShellExecutor
    ) async -> DNSBLResult {
        let query = "\(reversed).\(server)"
        let result = await executor.run(
            "dig +short +time=3 +tries=1 \(query) 2>/dev/null",
            timeout: .seconds(5)
        )

        if result.timedOut {
            return DNSBLResult(server: server, listed: false, error: "timeout")
        }

        let output = result.trimmedOutput
        // 有 127.x.x.x 返回 = 在黑名单中
        if !output.isEmpty && output.hasPrefix("127.") {
            return DNSBLResult(server: server, listed: true, error: nil)
        }

        // 空输出或非 127 开头 = 不在黑名单
        return DNSBLResult(server: server, listed: false, error: result.isSuccess ? nil : "query failed")
    }
}
