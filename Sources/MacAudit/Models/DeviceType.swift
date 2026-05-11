// DeviceType.swift — 设备类型枚举（笔记本/台式机），通过 pmset 检测电池判断设备类型

import Foundation

/// 设备类型：笔记本（有电池）或台式机（无电池）
enum DeviceType: String, Codable, Sendable {
    /// MacBook Pro 等带电池设备
    case laptop
    /// Mac Studio / Mac Pro / Mac mini / iMac 等无电池设备
    case desktop

    /// 通过 pmset -g batt 检测设备类型
    static func detect() -> DeviceType {
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

    /// 用户可读的设备类型名称
    var displayName: String {
        switch self {
        case .laptop: "笔记本"
        case .desktop: "台式机"
        }
    }
}
