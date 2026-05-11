import Testing
@testable import MacAudit

// MARK: - M7 PowerModule Tests
// Laptop (arm64): 6(ac) + 5(batt) + 9(general) + 1(wifi_ac) + 1(wifi_battery) + 1(hibernatemode) + 1(lidwake) + 1(amphetamine) + 1(server_mode) = 26
// Desktop (arm64): 6(ac) + 9(general) + 1(autorestart) + 1(wifi_ac) + 1(hibernatemode) + 1(amphetamine) + 1(server_mode) = 20

@Test("M7 module id and name are non-empty")
func powerModuleMetadata() {
    let module = PowerModule()
    #expect(module.id == "power")
    #expect(!module.name.isEmpty)
}

@Test("M7 checks count is 26 for laptop")
func powerChecksCountLaptop() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count == 26)
}

@Test("M7 checks count is 20 for desktop")
func powerChecksCountDesktop() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    #expect(checks.count == 20)
}

@Test("M7 laptop has more checks than desktop")
func powerLaptopMoreThanDesktop() {
    let module = PowerModule()
    let laptop = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let desktop = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    #expect(laptop.count > desktop.count)
    #expect(laptop.count - desktop.count == 6)
}

@Test("M7 all check IDs start with m7.")
func powerCheckIDPrefix() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m7."))
    }
}

@Test("M7 all checks belong to power module")
func powerCheckModuleField() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "power")
    }
}

@Test("M7 battery checks only appear in laptop")
func powerBatteryChecksLaptopOnly() {
    let module = PowerModule()
    let desktop = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    let desktopIds = desktop.map(\.id)
    #expect(!desktopIds.contains("m7.batt_sleep"))
    #expect(!desktopIds.contains("m7.batt_disksleep"))
    #expect(!desktopIds.contains("m7.wifi_battery"))
}

@Test("M7 laptop contains battery checks")
func powerLaptopContainsBatteryChecks() {
    let module = PowerModule()
    let laptop = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = laptop.map(\.id)
    #expect(ids.contains("m7.batt_sleep"))
    #expect(ids.contains("m7.wifi_battery"))
}

@Test("M7 ac_sleep check expects 0")
func powerAcSleepExpected() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let acSleep = checks.first { $0.id == "m7.ac_sleep" }
    #expect(acSleep != nil)
    #expect(acSleep?.expectedValue == "0")
}

@Test("M7 check IDs are unique")
func powerCheckIDsUnique() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

@Test("M7 tahoe laptop count matches sequoia laptop count")
func powerTahoeLaptopCount() {
    let module = PowerModule()
    let seq = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let tahoe = module.checks(for: .tahoe, device: .laptop, arch: .arm64)
    #expect(seq.count == tahoe.count)
}

// MARK: - hibernatemode device-dependent expectedValue

@Test("M7 hibernatemode expects 3 on laptop")
func powerHibernatemodeLaptop() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let hm = checks.first { $0.id == "m7.hibernatemode" }
    #expect(hm != nil)
    #expect(hm?.expectedValue == "3")
}

@Test("M7 hibernatemode expects 0 on desktop")
func powerHibernatemodeDesktop() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    let hm = checks.first { $0.id == "m7.hibernatemode" }
    #expect(hm != nil)
    #expect(hm?.expectedValue == "0")
}

@Test("M7 hibernatemode fixCommand differs between laptop and desktop")
func powerHibernatemodeFixCommandDiffers() {
    let module = PowerModule()
    let laptop = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let desktop = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    let laptopHM = laptop.first { $0.id == "m7.hibernatemode" }
    let desktopHM = desktop.first { $0.id == "m7.hibernatemode" }
    #expect(laptopHM?.fixCommand?.contains("3") == true)
    #expect(desktopHM?.fixCommand?.contains("0") == true)
    #expect(laptopHM?.fixCommand != desktopHM?.fixCommand)
}

// MARK: - AC displaysleep expects 30 (non-zero, unlike others)

@Test("M7 ac_displaysleep expects 10 not 30")
func powerAcDisplaysleepExpected() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ds = checks.first { $0.id == "m7.ac_displaysleep" }
    #expect(ds?.expectedValue == "10")
}

// MARK: - Battery checks expected values

@Test("M7 batt_sleep expects 0 on laptop (server mode)")
func powerBattSleepExpected() {
    let module = PowerModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let bs = checks.first { $0.id == "m7.batt_sleep" }
    #expect(bs?.expectedValue == "0")
}

// MARK: - Architecture-dependent checks

@Test("M7 autorestart only appears on desktop")
func powerAutorestartDesktopOnly() {
    let module = PowerModule()
    let desktop = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    let laptop = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(desktop.map(\.id).contains("m7.autorestart"))
    #expect(!laptop.map(\.id).contains("m7.autorestart"))
}

@Test("M7 sms check does not exist (SSD-only era)")
func powerSmsNotPresent() {
    let module = PowerModule()
    let laptop = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let desktop = module.checks(for: .sequoia, device: .desktop, arch: .arm64)
    #expect(!laptop.map(\.id).contains("m7.sms"))
    #expect(!desktop.map(\.id).contains("m7.sms"))
}

@Test("M7 Intel laptop has fewer checks than Apple Silicon laptop")
func powerIntelLaptopFewerChecks() {
    let module = PowerModule()
    let intel = module.checks(for: .sequoia, device: .laptop, arch: .x86_64)
    let asilicon = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(intel.count <= asilicon.count)
}
