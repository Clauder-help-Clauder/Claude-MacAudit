import Foundation

public enum IPv4Validator: Sendable {
    public static func isValid(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty else { return false }
            guard part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
            if part.count > 1 && part.first == "0" { return false }
            guard let n = Int(part) else { return false }
            return (0...255).contains(n)
        }
    }
}
