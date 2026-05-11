import Foundation

public enum CPUArchitecture: String, Codable, Sendable, CaseIterable {
    case arm64
    case x86_64

    public static func detect() -> CPUArchitecture {
        var buf = [CChar](repeating: 0, count: 64)
        var size = buf.count
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        let machine = String(cString: buf)
        return machine.hasPrefix("arm64") ? .arm64 : .x86_64
    }

    public var displayName: String {
        switch self {
        case .arm64: "Apple Silicon"
        case .x86_64: "Intel"
        }
    }

    public var isAppleSilicon: Bool { self == .arm64 }
}
