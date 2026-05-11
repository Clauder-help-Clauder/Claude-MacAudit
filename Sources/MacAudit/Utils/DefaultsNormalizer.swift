// DefaultsNormalizer.swift — defaults 命令输出归一化工具，将布尔值的多变写法统一为 0/1

import Foundation

/// defaults 命令输出归一化器，将各种布尔表示统一为 "0" 或 "1"
enum DefaultsNormalizer {
    /// 将原始输出归一化；当期望值为布尔类型时，把 "true/yes/1" 统一为 "1"，"false/no/0" 统一为 "0"
    static func normalize(_ raw: String, expected: String?) -> String {
        guard let expected, isBoolExpected(expected) else { return raw }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "1", "true", "yes":
            return "1"
        case "0", "false", "no":
            return "0"
        default:
            if isDictBoolTrue(trimmed) { return "1" }
            if isDictBoolFalse(trimmed) { return "0" }
            return raw
        }
    }

    /// 判断字典格式输出中的布尔值是否为 true
    private static func isDictBoolTrue(_ s: String) -> Bool {
        guard s.hasPrefix("{") else { return false }
        return s.contains("= true") || s.contains("= 1") || s.contains("= yes")
    }

    /// 判断字典格式输出中的布尔值是否为 false
    private static func isDictBoolFalse(_ s: String) -> Bool {
        guard s.hasPrefix("{") else { return false }
        return s.contains("= false") || s.contains("= 0") || s.contains("= no")
    }

    /// 判断期望值是否为布尔类型（"0" 或 "1"）
    private static func isBoolExpected(_ expected: String) -> Bool {
        return expected == "0" || expected == "1"
    }
}
