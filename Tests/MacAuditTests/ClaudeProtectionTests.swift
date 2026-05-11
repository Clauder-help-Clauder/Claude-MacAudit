import Testing
@testable import MacAudit

// MARK: - M10 ClaudeProtectionModule Tests (v2 — 封号机制逆向分析重构)
// 重构依据：Claude Code Account ban mechanism exploration.md
// 核心原则：融入而非消失。关闭遥测本身是风险行为。
//
// 检测项总数计算（新版）：
// 1 (hosts_total, info) + 22 (individual hosts, info) + 3 (extra hosts, info)
// + 4 (A组安全env) + 3 (B组危险env反向) + 1 (C组低影响env, info)
// + 1 (env_summary 删除) → 改为 3 (B组独立) + 1 (DISABLE_TELEMETRY新增)
// + 1 (env_no_telemetry) + 1 (env_no_otel_prompts) + 1 (env_no_otel_tools)
// + 3 (proxy) + 3 (sandbox) + 8 (surge/ipv6/mdns等) + 5 (firewall)
// + 1 (surge_dashboard) + 5 (macOS telemetry) + 1 (no_proxy) + 1 (proxy_noproxy_in_func)
// + 1 (claude_version) + 1 (ipv6_all_interfaces) + 1 (surge_stun_reject)
// + 6 (新增: device_id, git_email, npm_registry, no_custom_api, no_tls_skip, tz_info)
// = 74

@Test("M10 module id and name are non-empty")
func claudeProtectionModuleMetadata() {
    let module = ClaudeProtectionModule()
    #expect(module.id == "claude")
    #expect(!module.name.isEmpty)
}

// ── 总数 ──────────────────────────────────────────────────────────────────

@Test("M10 active checks count (merged proxy functions)")
func claudeProtectionChecksCountSequoiaV2() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(checks.count >= 30)
    #expect(module.deferredChecks.count >= 12)
}

@Test("M10 active checks count for tahoe")
func claudeProtectionChecksCountTahoeV2() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .tahoe, device: .desktop, arch: .arm64)
    #expect(checks.count >= 30)
    #expect(module.deferredChecks.count >= 12)
}

@Test("M10 all check IDs start with m10.")
func claudeProtectionCheckIDPrefix() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.id.hasPrefix("m10."))
    }
}

@Test("M10 all checks belong to claude module")
func claudeProtectionCheckModuleField() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    for check in checks {
        #expect(check.module == "claude")
    }
}

@Test("M10 check IDs are unique")
func claudeProtectionCheckIDsUnique() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let ids = checks.map(\.id)
    #expect(Set(ids).count == ids.count)
}

// ── hosts 降级为 info（expected = nil）──────────────────────────────────




// ── B组：危险变量反向检测（expected = "not set"）─────────────────────────

@Test("M10 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 反向检测 — 设置了=warn（贝叶斯风控）")
func claudeProtectionDisableTrafficIsReversed() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let check = checks.first { $0.id == "m10.env_no_disable_traffic" }
    #expect(check != nil)
    #expect(check?.expectedValue == "not set")
}

@Test("M10 CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY 反向检测 — 设置了=warn")
func claudeProtectionDisableSurveyIsReversed() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let check = checks.first { $0.id == "m10.env_no_disable_survey" }
    #expect(check != nil)
    #expect(check?.expectedValue == "not set")
}

@Test("M10 DISABLE_TELEMETRY 反向检测 — 设置了=warn（关闭遥测导致付费功能失效）")
func claudeProtectionDisableTelemetryIsReversed() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let check = checks.first { $0.id == "m10.env_no_disable_telemetry" }
    #expect(check != nil)
    #expect(check?.expectedValue == "not set")
}

// ── A组：安全变量正向检测（expected = "1"）保持不变 ───────────────────────

@Test("M10 CLAUDE_CODE_PROXY_RESOLVES_HOSTS 正向检测（安全变量，期望=1）")
func claudeProtectionProxyResolvesHosts() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let id = "m10.env_" + String("claude_code_proxy_resolves_hosts".prefix(30))
    let check = checks.first { $0.id == id }
    #expect(check != nil)
    #expect(check?.expectedValue == "1")
}

@Test("M10 CLAUDE_CODE_SUBPROCESS_ENV_SCRUB 正向检测（安全变量，期望=1）")
func claudeProtectionSubprocessEnvScrub() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let id = "m10.env_" + String("claude_code_subprocess_env_scrub".prefix(30))
    let check = checks.first { $0.id == id }
    #expect(check != nil)
    #expect(check?.expectedValue == "1")
}

@Test("M10 CLAUDE_STREAM_IDLE_TIMEOUT_MS 正向检测（安全变量，检测 .zshrc 内容，期望=1）")
func claudeProtectionStreamIdleTimeout() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let id = "m10.env_" + String("claude_stream_idle_timeout_ms".prefix(30))
    let check = checks.first { $0.id == id }
    #expect(check != nil)
    #expect(check?.expectedValue == "1")
}

// ── 原有反向检测（OTel）保持不变 ──────────────────────────────────────────

@Test("M10 reverse detection checks ensure dangerous OTel vars are not set")
func claudeProtectionReverseDetection() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let noTelemetry = checks.first { $0.id == "m10.env_no_telemetry" }
    let noPrompts   = checks.first { $0.id == "m10.env_no_otel_prompts" }
    let noTools     = checks.first { $0.id == "m10.env_no_otel_tools" }
    #expect(noTelemetry != nil)
    #expect(noPrompts != nil)
    #expect(noTools != nil)
    #expect(noTelemetry?.expectedValue == "not set")
    #expect(noPrompts?.expectedValue == "not set")
    #expect(noTools?.expectedValue == "not set")
}

// ── 新增检测项 Phase 3 ────────────────────────────────────────────────────

@Test("M10 deferred: deviceId 存在性检测（跨账号永久设备指纹）")
func claudeProtectionDeviceIdCheck() {
    let module = ClaudeProtectionModule()
    let check = module.deferredChecks.first { $0.id == "m10.device_id" }
    #expect(check != nil)
    #expect(check?.expectedValue == nil)
    #expect(check?.priority == .a3)
}

@Test("M10 deferred: git user.email 泄露检测")
func claudeProtectionGitEmailCheck() {
    let module = ClaudeProtectionModule()
    let check = module.deferredChecks.first { $0.id == "m10.git_email_leak" }
    #expect(check != nil)
    #expect(check?.expectedValue == nil)
    #expect(check?.priority == .a3)
}

@Test("M10 npm registry 地理信号检测（保留在活跃检测，期望官方源）")
func claudeProtectionNpmRegistryCheck() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let check = checks.first { $0.id == "m10.npm_registry" }
    #expect(check != nil)
    #expect(check?.expectedValue == "https://registry.npmjs.org/")
}

@Test("M10 新增：ANTHROPIC_BASE_URL 反向检测（服务端标记为危险变量）")
func claudeProtectionCustomApiCheck() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let check = checks.first { $0.id == "m10.env_no_custom_api" }
    #expect(check != nil)
    #expect(check?.expectedValue == "not set")
}

@Test("M10 新增：NODE_TLS_REJECT_UNAUTHORIZED 反向检测（服务端危险变量）")
func claudeProtectionTlsSkipCheck() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let check = checks.first { $0.id == "m10.env_no_tls_skip" }
    #expect(check != nil)
    #expect(check?.expectedValue == "not set")
}

@Test("M10 deferred: 时区环境信号检测（info）")
func claudeProtectionTzInfoCheck() {
    let module = ClaudeProtectionModule()
    let check = module.deferredChecks.first { $0.id == "m10.tz_info" }
    #expect(check != nil)
    #expect(check?.expectedValue == nil)
    #expect(check?.priority == .a3)
}

// ── 原有测试保留（代理/防火墙/macOS遥测）───────────────────────────────────

@Test("M10 proxy_functions check expects set")
func claudeProtectionProxyFunctionsExpected() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let proxy = checks.first { $0.id == "m10.proxy_functions" }
    #expect(proxy != nil)
    #expect(proxy?.expectedValue == "set")
}

@Test("M10 fw_global check has crossRef to m2.firewall")
func claudeProtectionFwCrossRef() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let fw = checks.first { $0.id == "m10.fw_global" }
    #expect(fw != nil)
    #expect(fw?.crossRef == "m2.firewall")
}

@Test("M10 deferred: macOS telemetry checks moved to deferredChecks (duplicates of PrivacyModule)")
func claudeProtectionMacOSTelemetry() {
    let module = ClaudeProtectionModule()
    let active = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    #expect(active.first { $0.id == "m10.telemetry_diaginfo" } == nil)
    #expect(active.first { $0.id == "m10.telemetry_adlib" } == nil)
    let diaginfo = module.deferredChecks.first { $0.id == "m10.telemetry_diaginfo" }
    let adlib    = module.deferredChecks.first { $0.id == "m10.telemetry_adlib" }
    #expect(diaginfo != nil)
    #expect(adlib != nil)
    #expect(diaginfo?.expectedValue == "0")
    #expect(diaginfo?.priority == .a2)
}

@Test("M10 env_summary 已删除（不再作为单独检测项）")
func claudeProtectionEnvSummaryRemoved() {
    let module = ClaudeProtectionModule()
    let checks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let envSummary = checks.first { $0.id == "m10.env_summary" }
    // env_summary 应该被删除
    #expect(envSummary == nil)
}

@Test("CheckPriority: maxPriority .a0 returns only A0 checks; deferred items are A2/A3")
func checkPriorityFiltersCorrectly() {
    let module = ClaudeProtectionModule()
    let a0Only = module.checks(for: .sequoia, device: .laptop, arch: .arm64, maxPriority: .a0)
    #expect(a0Only.allSatisfy { $0.priority == .a0 })
    let deferred = module.deferredChecks
    #expect(deferred.allSatisfy { $0.priority > .a0 })
    #expect(deferred.filter { $0.priority == .a2 }.count > 0)
    #expect(deferred.filter { $0.priority == .a3 }.count > 0)
}

@Test("CheckPriority: rawValue comparison order is correct")
func checkPriorityOrdering() {
    #expect(CheckPriority.a0 < CheckPriority.a1)
    #expect(CheckPriority.a1 < CheckPriority.a2)
    #expect(CheckPriority.a2 < CheckPriority.a3)
    #expect(CheckPriority.a0 < CheckPriority.a3)
    #expect(!(CheckPriority.a2 < CheckPriority.a1))
}

@Test("CheckPriority: ServicesModule A0 filter excludes A1/A2 service checks")
func servicesPriorityFiltering() {
    let module = ServicesModule()
    let allChecks = module.checks(for: .sequoia, device: .laptop, arch: .arm64)
    let a0Only = module.checks(for: .sequoia, device: .laptop, arch: .arm64, maxPriority: .a0)
    #expect(a0Only.count < allChecks.count)
    #expect(a0Only.isEmpty)
    let a1AndBelow = module.checks(for: .sequoia, device: .laptop, arch: .arm64, maxPriority: .a1)
    #expect(a1AndBelow.count > 0)
    #expect(a1AndBelow.allSatisfy { $0.priority <= .a1 })
}
