import Foundation

/// 设备类型：笔记本（有电池）或台式机（无电池）
public enum DeviceType: String, Codable, Sendable {
    case laptop    // MacBook Pro
    case desktop   // Mac Studio / Mac Pro / Mac mini / iMac

    /// 通过 pmset -g batt 检测设备类型
    public static func detect() -> DeviceType {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "pmset -g batt 2>/dev/null"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            // 如果输出包含 "Battery" 或 "InternalBattery"，是笔记本
            return output.contains("Battery") ? .laptop : .desktop
        } catch {
            return .desktop // 默认台式机（更保守）
        }
    }

    public var displayName: String {
        switch self {
        case .laptop: "笔记本"
        case .desktop: "台式机"
        }
    }
}
