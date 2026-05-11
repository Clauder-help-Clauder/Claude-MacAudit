import Testing
@testable import MacAudit

@Test("M15 Safari module metadata")
func safariModuleMetadata() {
    let module = SafariModule()
    #expect(module.id == "safari")
    #expect(!module.name.isEmpty)
}

@Test("M15 Safari checks count for sequoia laptop arm64")
func safariChecksCountSequoia() {
    let module = SafariModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 13)
}

@Test("M15 Safari checks count for tahoe laptop arm64")
func safariChecksCountTahoe() {
    let module = SafariModule()
    let checks = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    #expect(checks.count == 14)
}

@Test("M15 Safari all checks belong to safari module")
func safariAllChecksBelongByModule() {
    let module = SafariModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "safari")
    }
}

@Test("M15 Safari popup_block_webkit has independent fixCommand")
func safariPopupBlockWebkitFix() {
    let module = SafariModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let wk1 = checks.first { $0.id == "m15.popup_block_webkit" }
    let wk2 = checks.first { $0.id == "m15.popup_block_webkit2" }
    #expect(wk1 != nil)
    #expect(wk2 != nil)
    #expect(wk1?.fixCommand?.contains("&&") == false)
    #expect(wk2?.fixCommand?.contains("&&") == false)
}

@Test("M15 Safari tahoe exclusive check present")
func safariTahoeExclusiveCheck() {
    let module = SafariModule()
    let checks = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(ids.contains("m15.enhanced_regular"))
    let seqChecks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let seqIds = seqChecks.map(\.id)
    #expect(!seqIds.contains("m15.enhanced_regular"))
}

@Test("M15 Safari all checks have expected values except info")
func safariAllChecksHaveExpected() {
    let module = SafariModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        if check.id != "m15.private_relay" {
            #expect(check.expectedValue != nil, "\(check.id) should have expectedValue")
        }
    }
}

@Test("M15 Safari all check IDs are unique")
func safariCheckIDsUnique() {
    let module = SafariModule()
    let checks = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M15 Safari all check IDs start with m15.")
func safariCheckIDPrefix() {
    let module = SafariModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m15."))
    }
}
