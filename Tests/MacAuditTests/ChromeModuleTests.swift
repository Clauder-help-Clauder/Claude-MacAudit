import Testing
@testable import MacAudit

@Test("M14 Chrome module metadata")
func chromeModuleMetadata() {
    let module = ChromeModule()
    #expect(module.id == "chrome")
    #expect(!module.name.isEmpty)
}

@Test("M14 Chrome checks count")
func chromeChecksCount() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 13)
}

@Test("M14 Chrome all fixCommands use PlistBuddy")
func chromeAllFixUsePlistBuddy() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        if let fix = check.fixCommand {
            #expect(fix.contains("PlistBuddy"), "\(check.id) fixCommand should use PlistBuddy")
        }
    }
}

@Test("M14 Chrome no fixCommand uses defaults write")
func chromeNoDefaultsWrite() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        if let fix = check.fixCommand {
            #expect(!fix.contains("defaults write"), "\(check.id) fixCommand should not use defaults write")
        }
    }
}

@Test("M14 Chrome installed check present")
func chromeInstalledCheck() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(ids.contains("m14.installed"))
    let installed = checks.first { $0.id == "m14.installed" }
    #expect(installed?.expectedValue == "installed")
}

@Test("M14 Chrome all check IDs are unique")
func chromeCheckIDsUnique() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M14 Chrome module has correct module ID")
func chromeModuleID() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "chrome")
    }
}

@Test("M14 Chrome all check IDs start with m14.")
func chromeCheckIDPrefix() {
    let module = ChromeModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m14."))
    }
}
