// AuditResult.swift — 单项检测结果数据模型，包含各状态（通过/失败/警告/信息/跳过/错误）的便利构造方法

import Foundation

/// 单项检测结果
struct AuditResult: Sendable, Codable {
    /// 关联 AuditCheck.id
    let checkId: String
    /// 检查项名称（便于展示）
    let checkName: String
    /// 所属模块 ID（如 "ip_quality"）
    let moduleId: String
    /// 检测状态
    let status: AuditStatus
    /// 实际检测值（Phase 2 回滚用）
    let actualValue: String?
    /// 期望值快照
    let expectedValue: String?
    /// 人类可读消息
    let message: String
    /// 检测风险等级
    let riskLevel: RiskLevel
    /// 检测时间戳
    let timestamp: Date
    /// 单项检测耗时（毫秒）
    let durationMs: Int
    /// 错误信息
    let error: String?
    /// 便利创建通过结果
    static func pass(
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
    static func fail(
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
    static func warn(
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
    static func info(
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
    static func skip(
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
    static func error(
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
