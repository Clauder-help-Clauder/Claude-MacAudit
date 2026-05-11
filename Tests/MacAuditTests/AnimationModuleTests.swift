import Testing
@testable import MacAudit

// MARK: - M5 AnimationModule Tests
// Total defs: 15(general)+16(Dock)+7(Finder)+2(screensaver)+2(sequoia-only)+2(tahoe-only)+1(softwareupdate) = 45
// Sequoia count: 45 - 2 (tahoe-only) = 43
// Tahoe count:   45 - 2 (sequoia-only) = 43

@Test("M5 module id and name are non-empty")
func animationModuleMetadata() {
    let module = AnimationModule()
    #expect(module.id == "animation")
    #expect(!module.name.isEmpty)
}

@Test("M5 checks count is 43 for sequoia")
func animationChecksCountSequoia() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 43)
}

@Test("M5 checks count is 43 for tahoe")
func animationChecksCountTahoe() {
    let module = AnimationModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count == 43)
}

@Test("M5 sequoia and tahoe get different checks")
func animationVersionSpecificChecks() {
    let module = AnimationModule()
    let sequoiaChecks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let tahoeChecks = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    // Sequoia has NSUseAnimatedFocusRing and NSDisableAutomaticTermination
    // Tahoe has reduceBlurring and EnableStandardClickToShowDesktop
    // Verify by check name since IDs include array index
    let sequoiaNames = Set(sequoiaChecks.map(\.name))
    let tahoeNames = Set(tahoeChecks.map(\.name))
    #expect(sequoiaNames.contains("焦点环动画"))
    #expect(sequoiaNames.contains("禁止自动终止"))
    #expect(!sequoiaNames.contains("Liquid Glass 模糊"))
    #expect(tahoeNames.contains("Liquid Glass 模糊"))
    #expect(tahoeNames.contains("Stage Manager 点击桌面"))
    #expect(!tahoeNames.contains("焦点环动画"))
}

@Test("M5 all checks belong to animation module")
func animationCheckModuleField() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "animation")
    }
}

@Test("M5 all checks have expected values")
func animationChecksHaveExpectedValues() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.expectedValue != nil)
    }
}

@Test("M5 all checks have fix commands (except com.apple.universalaccess protected by TCC)")
func animationChecksHaveFixCommands() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        let isUniversalAccess = check.detectionCommand.contains("com.apple.universalaccess")
        if isUniversalAccess {
            #expect(check.fixCommand == nil)
        } else {
            #expect(check.fixCommand != nil)
        }
    }
}

@Test("M5 check IDs are unique")
func animationCheckIDsUnique() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M5 Dock launchanim check present and expects 0")
func animationDockAutohideCheck() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let launchanim = checks.first { $0.name == "启动弹跳动画" }
    #expect(launchanim != nil)
    #expect(launchanim?.expectedValue == "0")
}

@Test("M5 screensaver idleTime check present")
func animationScreensaverIdleTime() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let idle = checks.first { $0.name == "屏保空闲时间" }
    #expect(idle != nil)
    #expect(idle?.expectedValue == "0")
}

// MARK: - fixCommand generation branch tests

@Test("M5 integer expected value generates -int fixCommand")
func animationFixCommandInt() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // autohide = "1" → Int parseable → -int 1
    let autohide = checks.first { $0.name == "自动隐藏 Dock" }
    #expect(autohide?.fixCommand?.contains("-int 1") == true)
}

@Test("M5 float expected value generates -float fixCommand")
func animationFixCommandFloat() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // expose-animation-duration = "0.1" → contains "." and Double parseable → -float 0.1
    let expose = checks.first { $0.name == "Mission Control 动画" }
    #expect(expose?.fixCommand?.contains("-float") == true)
    #expect(expose?.fixCommand?.contains("0.1") == true)
}

@Test("M5 string expected value generates -string fixCommand")
func animationFixCommandString() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // mineffect = "scale" → -string scale
    let mineffect = checks.first { $0.name == "最小化效果" }
    #expect(mineffect?.fixCommand?.contains("-string scale") == true)
}

@Test("M5 screencapture type generates -string png fixCommand")
func animationFixCommandStringPng() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // type = "png" → -string png
    let screenshotType = checks.first { $0.name == "截图格式" }
    #expect(screenshotType?.fixCommand?.contains("-string png") == true)
}

@Test("M5 -g domain checks use 'defaults write -g' in fixCommand")
func animationFixCommandGlobalDomain() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // NSAutomaticWindowAnimationsEnabled uses -g domain
    let winAnim = checks.first { $0.name == "窗口动画" }
    #expect(winAnim?.fixCommand?.hasPrefix("defaults write -g") == true)
}

@Test("M5 non-g domain checks use 'defaults write <domain>' in fixCommand")
func animationFixCommandNamedDomain() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // autohide uses com.apple.dock domain
    let autohide = checks.first { $0.name == "自动隐藏 Dock" }
    #expect(autohide?.fixCommand?.hasPrefix("defaults write com.apple.dock") == true)
}

@Test("M5 check IDs include array enumeration index (not filtered index)")
func animationCheckIDsIncludeEnumeratedIndex() {
    let module = AnimationModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    // All IDs follow "m5.<i>_<key_prefix>" pattern where i is defs.enumerated() index
    for check in checks {
        #expect(check.id.hasPrefix("m5."))
        // ID must contain underscore separating index from key
        let withoutPrefix = check.id.dropFirst(3) // drop "m5."
        #expect(withoutPrefix.contains("_"))
    }
}
