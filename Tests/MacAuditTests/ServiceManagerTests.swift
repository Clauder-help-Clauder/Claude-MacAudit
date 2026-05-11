import Testing
@testable import MacAudit

@Test("ServiceManager fetchStatus strips quotes from labels")
func serviceManagerFetchStatusStripsQuotes() async {
    let executor = ShellExecutor(stubbedOutputs: [
        "launchctl print-disabled": "\"com.apple.assistantd\" => disabled"
    ])
    let map = await ServiceManager.fetchStatus(executor: executor)
    #expect(map["com.apple.assistantd"] == "disabled")
}

@Test("ServiceManager fetchStatus returns empty dict for empty output")
func serviceManagerFetchStatusEmpty() async {
    let executor = ShellExecutor(stubbedOutputs: ["launchctl print-disabled": ""])
    let map = await ServiceManager.fetchStatus(executor: executor)
    #expect(map.isEmpty)
}

@Test("ServicesModule has 6 groups via management API")
func servicesModuleGroupCount() {
    let module = ServicesModule()
    let svcs = module.servicesForManagement(version: .sequoia, arch: .arm64)
    let groups = Set(svcs.map { $0.group })
    #expect(groups.count == 6)
}

@Test("ServicesModule all services have non-empty hint")
func servicesModuleHints() {
    let module = ServicesModule()
    let svcs = module.servicesForManagement(version: .sequoia, arch: .arm64)
    for svc in svcs {
        #expect(!svc.hint.isEmpty, "Service \(svc.name) has no hint")
    }
}

@Test("ServicesModule Siri group contains assistantd")
func servicesModuleSiriGroup() {
    let module = ServicesModule()
    let svcs = module.servicesForManagement(version: .sequoia, arch: .arm64)
    let siriGroup = svcs.filter { $0.group == "Siri/AI" }
    #expect(!siriGroup.isEmpty)
    #expect(siriGroup.contains { $0.name == "com.apple.assistantd" })
}

@Test("ServicesModule all service labels start with com.apple")
func servicesModuleLabels() {
    let module = ServicesModule()
    let svcs = module.servicesForManagement(version: .sequoia, arch: .arm64)
    for svc in svcs {
        #expect(svc.name.hasPrefix("com.apple."), "Unexpected label: \(svc.name)")
    }
}
