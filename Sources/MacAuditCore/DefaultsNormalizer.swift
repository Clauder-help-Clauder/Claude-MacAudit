import Foundation

public enum DefaultsNormalizer {
    public static func normalize(_ raw: String, expected: String?) -> String {
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

    private static func isDictBoolTrue(_ s: String) -> Bool {
        guard s.hasPrefix("{") else { return false }
        return s.contains("= true") || s.contains("= 1") || s.contains("= yes")
    }

    private static func isDictBoolFalse(_ s: String) -> Bool {
        guard s.hasPrefix("{") else { return false }
        return s.contains("= false") || s.contains("= 0") || s.contains("= no")
    }

    private static func isBoolExpected(_ expected: String) -> Bool {
        return expected == "0" || expected == "1"
    }
}
