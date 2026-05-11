import Foundation

/// 单项检测结果
public struct AuditResult: Sendable, Codable {
    public let checkId: String            // 关联 AuditCheck.id
    public let checkName: String          // 检查项名称（便于展示）
    public let moduleId: String           // 所属模块 ID（如 "ip_quality"）
    public let status: AuditStatus
    public let actualValue: String?       // 实际检测值（Phase 2 回滚用）
    public let expectedValue: String?     // 期望值快照
    public let message: String            // 人类可读消息
    public let riskLevel: RiskLevel       // 检测风险等级
    public let timestamp: Date
    public let durationMs: Int            // 单项检测耗时
    public let error: String?             // 错误信息

    /// 便利创建通过结果
    public static func pass(
        check: AuditCheck,
        actual: String,
        message: String = "",
        duration: Int = 0
    ) -> AuditResult {
        AuditResult(
            checkId: check.id,
            checkName: check.name,
            moduleId: check.module,
            status: .pass,
            actualValue: actual,
            expectedValue: check.expectedValue,
            message: message.isEmpty ? "\(check.name): \(actual)" : message,
            riskLevel: check.detectionRiskLevel,
            timestamp: Date(),
            durationMs: duration,
            error: nil
        )
    }

    /// 便利创建失败结果
    public static func fail(
        check: AuditCheck,
        actual: String,
        message: String = "",
        duration: Int = 0
    ) -> AuditResult {
        let msg = message.isEmpty
            ? "\(check.name): 期望 \(check.expectedValue ?? "N/A"), 实际 \(actual)"
            : message
        return AuditResult(
            checkId: check.id,
            checkName: check.name,
            moduleId: check.module,
            status: .fail,
            actualValue: actual,
            expectedValue: check.expectedValue,
            message: msg,
            riskLevel: check.detectionRiskLevel,
            timestamp: Date(),
            durationMs: duration,
            error: nil
        )
    }

    /// 便利创建警告结果
    public static func warn(
        check: AuditCheck,
        actual: String,
        message: String = "",
        duration: Int = 0
    ) -> AuditResult {
        let msg = message.isEmpty
            ? "\(check.name): \(actual)"
            : message
        return AuditResult(
            checkId: check.id,
            checkName: check.name,
            moduleId: check.module,
            status: .warn,
            actualValue: actual,
            expectedValue: check.expectedValue,
            message: msg,
            riskLevel: check.detectionRiskLevel,
            timestamp: Date(),
            durationMs: duration,
            error: nil
        )
    }

    /// 便利创建信息结果
    public static func info(
        check: AuditCheck,
        actual: String,
        message: String = "",
        duration: Int = 0
    ) -> AuditResult {
        AuditResult(
            checkId: check.id,
            checkName: check.name,
            moduleId: check.module,
            status: .info,
            actualValue: actual,
            expectedValue: check.expectedValue,
            message: message.isEmpty ? "\(check.name): \(actual)" : message,
            riskLevel: check.detectionRiskLevel,
            timestamp: Date(),
            durationMs: duration,
            error: nil
        )
    }

    /// 便利创建跳过结果
    public static func skip(
        check: AuditCheck,
        reason: String
    ) -> AuditResult {
        AuditResult(
            checkId: check.id,
            checkName: check.name,
            moduleId: check.module,
            status: .skip,
            actualValue: nil,
            expectedValue: check.expectedValue,
            message: "\(check.name): 跳过 — \(reason)",
            riskLevel: check.detectionRiskLevel,
            timestamp: Date(),
            durationMs: 0,
            error: nil
        )
    }

    /// 便利创建错误结果
    public static func error(
        check: AuditCheck,
        error: String,
        duration: Int = 0
    ) -> AuditResult {
        AuditResult(
            checkId: check.id,
            checkName: check.name,
            moduleId: check.module,
            status: .error,
            actualValue: nil,
            expectedValue: check.expectedValue,
            message: "\(check.name): 检测失败",
            riskLevel: check.detectionRiskLevel,
            timestamp: Date(),
            durationMs: duration,
            error: error
        )
    }
}
