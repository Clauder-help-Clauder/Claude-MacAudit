// CPUArchitecture.swift — CPU 架构枚举，支持运行时检测、显示名称及 Apple Silicon 判断

import Foundation

/// CPU 架构类型
enum CPUArchitecture: String, Codable, Sendable, CaseIterable {
    /// Apple Silicon (ARM64)
    case arm64
    /// Intel (x86_64)
    case x86_64

    /// 通过 sysctl 检测当前 CPU 架构
    static func detect() -> CPUArchitecture {
        var buf = [CChar](repeating: 0, count: 64)
        var size = buf.count
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        let machine = String(cString: buf)
        return machine.hasPrefix("arm64") ? .arm64 : .x86_64
    }

    /// 用户可读的架构名称
    var displayName: String {
        switch self {
        case .arm64: "Apple Silicon"
        case .x86_64: "Intel"
        }
    }

    /// 是否为 Apple Silicon 架构
    var isAppleSilicon: Bool { self == .arm64 }
}
