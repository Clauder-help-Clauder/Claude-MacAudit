/// 检测结果状态
public enum AuditStatus: String, Codable, Sendable {
    case pass       // 符合期望
    case warn       // 不符合但非关键
    case fail       // 不符合且重要
    case info       // 仅信息展示
    case skip       // 因版本/环境跳过
    case error      // 检测命令执行失败

    public var symbol: String {
        switch self {
        case .pass: "✓"
        case .warn: "!"
        case .fail: "✗"
        case .info: "i"
        case .skip: "⊘"
        case .error: "?"
        }
    }

    var color: ANSIColor {
        switch self {
        case .pass: .green
        case .warn: .yellow
        case .fail: .red
        case .info: .blue
        case .skip: .dim
        case .error: .orange
        }
    }
}
