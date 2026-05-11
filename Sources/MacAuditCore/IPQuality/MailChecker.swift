import Foundation

/// Phase D: 邮件端口检测
struct MailChecker: Sendable {

    /// 检测 SMTP 端口连通性
    static func check(executor: ShellExecutor) async -> [AuditResult] {
        let checks = IPQualityModule().phaseDChecks()

        // 并行检测 Port 25 和 Port 587
        async let port25 = checkPort(port: 25, executor: executor)
        async let port587 = checkPort(port: 587, executor: executor)

        let r25 = await port25
        let r587 = await port587

        return [
            portResult(check: checks[0], open: r25, port: 25),
            portResult(check: checks[1], open: r587, port: 587),
        ]
    }

    /// 使用 nc 检测端口是否开放（通过连接知名 SMTP 服务器）
    static func checkPort(port: Int, executor: ShellExecutor) async -> Bool {
        // 测试 smtp.gmail.com 作为代表性 SMTP 服务器
        let result = await executor.run(
            "nc -z -w 3 smtp.gmail.com \(port) 2>/dev/null && echo OPEN || echo CLOSED",
            timeout: .seconds(5)
        )
        return result.trimmedOutput.contains("OPEN")
    }

    static func portResult(check: AuditCheck, open: Bool, port: Int) -> AuditResult {
        if open {
            return .pass(check: check, actual: "开放",
                         message: "\(check.name): Port \(port) 可达")
        } else {
            return .warn(check: check, actual: "关闭",
                         message: "\(check.name): Port \(port) 不可达（可能被 ISP 封锁）")
        }
    }
}
