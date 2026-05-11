// RiskLevel.swift — 检测项风险等级枚举，定义 safe 到 critical 五级风险及对应的标签与颜色

/// 检测项风险等级
enum RiskLevel: Int, Comparable, Codable, Sendable, CaseIterable {
    /// 只读检测，无副作用
    case safe = 0
    /// defaults write，可撤销
    case low = 1
    /// 影响系统行为，需确认
    case medium = 2
    /// 需要 sudo 权限
    case high = 3
    /// 可能断网或数据丢失
    case critical = 4

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 用于显示的大写标签字符串
    var label: String {
        switch self {
        case .safe: "SAFE"
        case .low: "LOW"
        case .medium: "MEDIUM"
        case .high: "HIGH"
        case .critical: "CRITICAL"
        }
    }

    /// 对应的终端 ANSI 颜色
    var color: ANSIColor {
        switch self {
        case .safe: .green
        case .low: .blue
        case .medium: .yellow
        case .high: .orange
        case .critical: .red
        }
    }
}
