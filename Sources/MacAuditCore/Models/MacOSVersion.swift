import Foundation

/// 支持的 macOS 版本
public enum MacOSVersion: String, Codable, Sendable, CaseIterable {
    case sequoia  // majorVersion == 15
    case tahoe    // majorVersion == 26

    /// 检测当前系统版本，返回 nil 表示不支持
    public static func detect() -> MacOSVersion? {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        switch v.majorVersion {
        case 15: return .sequoia
        case 26: return .tahoe
        default: return nil
        }
    }

    /// 当前系统完整版本字符串
    public static var versionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    public var displayName: String {
        switch self {
        case .sequoia: "macOS Sequoia 15"
        case .tahoe: "macOS Tahoe 26"
        }
    }

    public var majorVersion: Int {
        switch self {
        case .sequoia: 15
        case .tahoe: 26
        }
    }
}
