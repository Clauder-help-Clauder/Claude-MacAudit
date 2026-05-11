// MacOSVersion.swift — 支持的 macOS 版本枚举，提供版本检测、显示名称及主版本号映射

import Foundation

/// 支持的 macOS 版本
enum MacOSVersion: String, Codable, Sendable, CaseIterable {
    /// macOS Sequoia (majorVersion == 15)
    case sequoia
    /// macOS Tahoe (majorVersion == 26)
    case tahoe

    /// 检测当前系统版本，返回 nil 表示不支持
    static func detect() -> MacOSVersion? {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        switch v.majorVersion {
        case 15: return .sequoia
        case 26: return .tahoe
        default: return nil
        }
    }

    /// 当前系统完整版本字符串
    static var versionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// 用户可读的版本名称
    var displayName: String {
        switch self {
        case .sequoia: "macOS Sequoia 15"
        case .tahoe: "macOS Tahoe 26"
        }
    }

    /// 对应的主版本号
    var majorVersion: Int {
        switch self {
        case .sequoia: 15
        case .tahoe: 26
        }
    }
}
