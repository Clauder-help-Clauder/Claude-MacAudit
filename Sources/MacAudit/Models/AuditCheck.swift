// AuditCheck.swift — 单个审计检查项的数据模型，包含检查项定义、优先级及适用性判断

import Foundation

/// 检查项业务优先级，A0 最高（必须），A3 最低（可砍）
enum CheckPriority: String, Sendable, Codable, Comparable {
    /// 必须执行的检查项
    case a0 = "A0"
    /// 高优先级检查项
    case a1 = "A1"
    /// 中优先级检查项
    case a2 = "A2"
    /// 低优先级，可在剪裁模式下跳过
    case a3 = "A3"

    static func < (lhs: CheckPriority, rhs: CheckPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 单个检查项定义
struct AuditCheck: Identifiable, Sendable {
    /// 唯一标识，如 "m2.sip_status"
    let id: String
    /// 显示名称，如 "SIP 状态"
    let name: String
    /// 所属模块 ID，如 "security"
    let module: String
    /// 检测说明
    let description: String
    /// 检测命令
    let detectionCommand: String
    /// 期望值（nil 表示仅信息收集，不做比对）
    let expectedValue: String?
    /// 适用版本（空集合表示全部适用）
    let supportedVersions: Set<MacOSVersion>
    /// 检测时的风险等级
    let detectionRiskLevel: RiskLevel
    /// 修复时的风险等级（Phase 2）
    let fixRiskLevel: RiskLevel?
    /// 修复命令（Phase 2）
    let fixCommand: String?
    /// 检测是否需要 sudo
    let requiresSudo: Bool
    /// 是否可能导致网络断开
    let networkRisk: Bool
    /// 标签集合
    let tags: Set<String>
    /// 跨模块引用 ID
    let crossRef: String?
    /// 适用设备类型（nil 表示所有设备）
    let deviceTypes: Set<DeviceType>?
    /// 适用 CPU 架构（nil 表示所有架构）
    let architectures: Set<CPUArchitecture>?
    /// 业务优先级（A0=必须 A3=可砍）
    var priority: CheckPriority

    /// 便利初始化：大部分字段有默认值
    init(
        id: String,
        name: String,
        module: String,
        description: String = "",
        command: String,
        /// 期望值，nil 表示仅信息收集
        expected: String? = nil,
        /// 适用版本，空集合表示全部适用
        versions: Set<MacOSVersion> = [],
        /// 检测风险等级，默认 safe
        risk: RiskLevel = .safe,
        /// 修复风险等级
        fixRisk: RiskLevel? = nil,
        /// 修复命令
        fixCommand: String? = nil,
        /// 检测是否需要 sudo
        sudo: Bool = false,
        /// 是否可能导致网络断开
        networkRisk: Bool = false,
        /// 标签集合
        tags: Set<String> = [],
        /// 跨模块引用 ID
        crossRef: String? = nil,
        /// 适用设备类型，nil 表示所有设备
        devices: Set<DeviceType>? = nil,
        /// 适用 CPU 架构，nil 表示所有架构
        architectures: Set<CPUArchitecture>? = nil,
        /// 业务优先级，默认 A3
        priority: CheckPriority = .a3
    ) {
        self.id = id
        self.name = name
        self.module = module
        self.description = description
        self.detectionCommand = command
        self.expectedValue = expected
        self.supportedVersions = versions
        self.detectionRiskLevel = risk
        self.fixRiskLevel = fixRisk
        self.fixCommand = fixCommand
        self.requiresSudo = sudo
        self.networkRisk = networkRisk
        self.tags = tags
        self.crossRef = crossRef
        self.deviceTypes = devices
        self.architectures = architectures
        self.priority = priority
    }

    /// 判断当前检查项是否适用于指定的版本、设备类型和架构
    func isApplicable(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> Bool {
        let versionOk = supportedVersions.isEmpty || supportedVersions.contains(version)
        let deviceOk = deviceTypes == nil || deviceTypes!.contains(device)
        let archOk = architectures == nil || architectures!.contains(arch)
        return versionOk && deviceOk && archOk
    }
}
