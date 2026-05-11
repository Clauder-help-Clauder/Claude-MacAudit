// AuditStatus.swift — 检测结果状态枚举，定义通过/警告/失败/信息/跳过/错误六种状态及对应符号和颜色

/// 检测结果状态
enum AuditStatus: String, Codable, Sendable {
    /// 符合期望
    case pass
    /// 不符合但非关键
    case warn
    /// 不符合且重要
    case fail
    /// 仅信息展示
    case info
    /// 因版本/环境跳过
    case skip
    /// 检测命令执行失败
    case error

    /// 状态对应的显示符号
    var symbol: String {
        switch self {
        case .pass: "✓"
        case .warn: "!"
        case .fail: "✗"
        case .info: "i"
        case .skip: "⊘"
        case .error: "?"
        }
    }

    /// 状态对应的终端 ANSI 颜色
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
