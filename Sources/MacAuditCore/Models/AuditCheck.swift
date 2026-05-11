import Foundation

public enum CheckPriority: String, Sendable, Codable, Comparable {
    case a0 = "A0"
    case a1 = "A1"
    case a2 = "A2"
    case a3 = "A3"

    public static func < (lhs: CheckPriority, rhs: CheckPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 单个检查项定义
public struct AuditCheck: Identifiable, Sendable {
    public let id: String                              // 如 "m2.sip_status"
    public let name: String                            // 如 "SIP 状态"
    public let module: String                          // 如 "security"
    public let description: String                     // 检测说明
    public let detectionCommand: String                // 检测命令
    public let expectedValue: String?                  // 期望值（nil = 仅信息收集）
    public let supportedVersions: Set<MacOSVersion>    // 适用版本（空 = 全部）
    public let detectionRiskLevel: RiskLevel           // 检测时的风险等级
    public let fixRiskLevel: RiskLevel?                // 修复时的风险等级（Phase 2）
    public let fixCommand: String?                     // 修复命令（Phase 2）
    public let requiresSudo: Bool                      // 检测是否需要 sudo
    public let networkRisk: Bool                       // 是否可能导致网络断开
    public let tags: Set<String>                       // 标签
    public let crossRef: String?                       // 跨模块引用 ID
    public let deviceTypes: Set<DeviceType>?           // nil = 所有设备
    public let architectures: Set<CPUArchitecture>?    // nil = 所有架构
    public var priority: CheckPriority                 // 业务优先级（A0=必须 A3=可砍）

    /// 便利初始化：大部分字段有默认值
    public init(
        id: String,
        name: String,
        module: String,
        description: String = "",
        command: String,
        expected: String? = nil,
        versions: Set<MacOSVersion> = [],
        risk: RiskLevel = .safe,
        fixRisk: RiskLevel? = nil,
        fixCommand: String? = nil,
        sudo: Bool = false,
        networkRisk: Bool = false,
        tags: Set<String> = [],
        crossRef: String? = nil,
        devices: Set<DeviceType>? = nil,
        architectures: Set<CPUArchitecture>? = nil,
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

    public func isApplicable(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> Bool {
        let versionOk = supportedVersions.isEmpty || supportedVersions.contains(version)
        let deviceOk = deviceTypes == nil || deviceTypes!.contains(device)
        let archOk = architectures == nil || architectures!.contains(arch)
        return versionOk && deviceOk && archOk
    }
}
