import Foundation

/// Phase A: 本地 IP 信息获取（纯 shell 命令，无需 API Key）
struct IPFetcher: Sendable {
    /// 获取公网 IPv4 — 多源并行竞争，取最快成功的结果
    static func publicIPv4(executor: ShellExecutor) async -> String? {
        let sources = [
            "curl -s --max-time 4 https://ifconfig.me 2>/dev/null",
            "curl -s --max-time 4 https://api.ipify.org 2>/dev/null",
            "curl -s --max-time 4 https://icanhazip.com 2>/dev/null",
        ]
        return await withTaskGroup(of: String?.self) { group in
            for cmd in sources {
                group.addTask {
                    let result = await executor.run(cmd, timeout: .seconds(5))
                    let ip = result.trimmedOutput
                    return (result.isSuccess && isValidIPv4(ip)) ? ip : nil
                }
            }
            // 返回第一个非 nil 结果，取消其余任务
            for await result in group {
                if let ip = result {
                    group.cancelAll()
                    return ip
                }
            }
            return nil
        }
    }

    /// 获取公网 IPv6 — 多源并行竞争，取最快成功的结果
    static func publicIPv6(executor: ShellExecutor) async -> String? {
        let sources = [
            "curl -6 -s --max-time 4 https://api64.ipify.org 2>/dev/null",
            "curl -6 -s --max-time 4 https://ipv6.icanhazip.com 2>/dev/null",
        ]
        return await withTaskGroup(of: String?.self) { group in
            for cmd in sources {
                group.addTask {
                    let result = await executor.run(cmd, timeout: .seconds(5))
                    let ip = result.trimmedOutput
                    return (result.isSuccess && !ip.isEmpty && ip.contains(":")) ? ip : nil
                }
            }
            for await result in group {
                if let ip = result {
                    group.cancelAll()
                    return ip
                }
            }
            return nil
        }
    }

    /// 获取反向 DNS
    static func reverseDNS(ip: String, executor: ShellExecutor) async -> String? {
        guard isValidIPv4(ip) else { return nil }
        let result = await executor.run("dig +short -x \(ip) 2>/dev/null", timeout: .seconds(5))
        guard result.isSuccess else { return nil }
        let output = result.trimmedOutput
        return output.isEmpty ? nil : output
    }

    /// 获取 whois 基础信息（组织 + 国家）
    static func whoisInfo(ip: String, executor: ShellExecutor) async -> (org: String?, country: String?) {
        guard isValidIPv4(ip) else { return (nil, nil) }
        let result = await executor.run("whois \(ip) 2>/dev/null | head -80", timeout: .seconds(10))
        guard result.isSuccess else { return (nil, nil) }
        let lines = result.stdout.components(separatedBy: "\n")

        var org: String?
        var country: String?

        for line in lines {
            let lower = line.lowercased()
            if org == nil && (lower.hasPrefix("orgname:") || lower.hasPrefix("org-name:") || lower.hasPrefix("descr:")) {
                org = extractValue(line)
            }
            if country == nil && lower.hasPrefix("country:") {
                country = extractValue(line)
            }
            if org != nil && country != nil { break }
        }
        return (org, country)
    }

    /// 获取系统 DNS 服务器
    static func dnsServers(executor: ShellExecutor) async -> String {
        let result = await executor.run(
            "scutil --dns 2>/dev/null | grep 'nameserver\\[' | awk '{print $3}' | sort -u | head -5 | tr '\\n' ', ' | sed 's/,$//'",
            timeout: .seconds(5)
        )
        return result.isSuccess ? result.trimmedOutput : "N/A"
    }

    /// 获取系统代理配置
    static func proxyConfig(executor: ShellExecutor) async -> String {
        let result = await executor.run(
            "scutil --proxy 2>/dev/null | grep -E '(HTTPEnable|HTTPSEnable|SOCKSEnable|HTTPProxy|HTTPSProxy|SOCKSProxy)' | head -6",
            timeout: .seconds(5)
        )
        if result.isSuccess && !result.trimmedOutput.isEmpty {
            return result.trimmedOutput
        }
        return "无代理"
    }

    /// 获取默认网关
    static func defaultGateway(executor: ShellExecutor) async -> String {
        let result = await executor.run(
            "route -n get default 2>/dev/null | grep gateway | awk '{print $2}'",
            timeout: .seconds(5)
        )
        return result.isSuccess ? result.trimmedOutput : "N/A"
    }

    /// 获取本地网络接口 IP
    static func localInterfaces(executor: ShellExecutor) async -> String {
        let result = await executor.run(
            "ifconfig 2>/dev/null | grep -E 'inet (addr:)?[0-9]' | grep -v '127.0.0.1' | awk '{print $2}' | head -5 | tr '\\n' ', ' | sed 's/,$//'",
            timeout: .seconds(5)
        )
        return result.isSuccess ? result.trimmedOutput : "N/A"
    }

    // MARK: - Helpers

    static func isValidIPv4(_ s: String) -> Bool {
        IPv4Validator.isValid(s)
    }

    static func extractValue(_ line: String) -> String? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
