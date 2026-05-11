/// 检测项风险等级
public enum RiskLevel: Int, Comparable, Codable, Sendable, CaseIterable {
    case safe = 0      // 只读检测，无副作用
    case low = 1       // defaults write，可撤销
    case medium = 2    // 影响系统行为，需确认
    case high = 3      // 需要 sudo 权限
    case critical = 4  // 可能断网或数据丢失

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .safe: "SAFE"
        case .low: "LOW"
        case .medium: "MEDIUM"
        case .high: "HIGH"
        case .critical: "CRITICAL"
        }
    }

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
