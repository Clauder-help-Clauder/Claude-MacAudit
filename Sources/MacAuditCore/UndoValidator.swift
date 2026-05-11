import Foundation

public enum UndoValidator: Sendable {
    private static let allowedPrefixes: [String] = [
        "defaults write ", "defaults delete ",
        "sudo defaults write ", "sudo defaults delete ",
        "networksetup ", "sudo networksetup ",
        "sysctl ", "sudo sysctl ",
        "pmset ", "sudo pmset ",
        "launchctl ", "sudo launchctl ",
        "/usr/libexec/PlistBuddy ",
        "sudo /usr/libexec/PlistBuddy ",
    ]

    private static let chainingChars: Set<Character> = ["&", "|", ";", "`", "$", "\n", "(", ")", "{", "}", "<", ">"]

    public static func isValidUndoCommand(_ cmd: String) -> Bool {
        let trimmed = cmd.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") { return true }
        if trimmed.contains(where: { chainingChars.contains($0) }) { return false }
        return allowedPrefixes.contains { trimmed.hasPrefix($0) }
    }
}
