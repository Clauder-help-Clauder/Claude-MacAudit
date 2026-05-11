# v0.2.0 MVP Release Checklist

## Version Target
- **v0.2.0** (Beta) — First public-ready release
- Previous: v0.1.5 (Alpha)

---

## Release Criteria

### Must Have (Blocking)
- [x] All A0 code defects fixed (T1-T9: undo injection, verifyCommand, shellEscape, atomic write, DNSBL validation, etc.)
- [x] ClaudeProtectionModule 52→36 active checks (16 deferred to `deferredChecks`)
- [x] Chrome non-MDM environment fail→info (runtime MDM detection)
- [x] `CheckPriority` (A0/A1/A2/A3) on `AuditCheck` + `deferredChecks` on `AuditModule`
- [x] `checks(maxPriority:)` filter method — enables `--mvp` mode
- [x] FixEngine 3-round code review PASS (all execute* functions have verifyCommand)
- [x] `cancelAudit()` clears results + moduleSummaries
- [x] All 659 tests passing
- [ ] `--mvp` CLI flag implemented (only runs A0 checks)
- [ ] Smoke test: `MacAudit --mvp` runs in < 30 seconds with < 100 checks
- [ ] Smoke test: `MacAudit` (full) runs in < 60 seconds
- [ ] macOS 15 (Sequoia) clean VM: zero errors
- [ ] macOS 26 (Tahoe) clean VM: zero errors
- [ ] `MacAudit --fix --safe` completes without crash
- [ ] `MacAudit --undo` rolls back last fix batch
- [ ] `swift build -c release` zero warnings

### Should Have (Important)
- [ ] All A0 checks have `priority: .a0` explicitly set (currently defaulting)
- [ ] All A1/A2/A3 checks tagged with correct priority across all 12 modules
- [ ] Integration test: `checks(maxPriority: .a0)` returns only A0 items
- [ ] GUI (MacAuditApp) respects `CheckPriority` for MVP mode toggle
- [ ] Release notes (CHANGELOG.md or similar)

### Nice to Have
- [ ] `--priority A0|A1|A2|A3` CLI flag (granular priority control)
- [ ] Deferred checks listed in report footer ("16 checks deferred, run with --all to include")
- [ ] v0.2.0-phase1 tag (architecture unification — CLI uses MacAuditCore directly)

---

## A0 MVP Scope (~83 checks)

| Module | A0 Items | Description |
|--------|----------|-------------|
| Claude Protection | 36 | Risk signals, safe env, dangerous env, sandbox, proxy, firewall |
| Network Security | 15 | Firewall, stealth, IPv6, mDNS, captive portal |
| Privacy | 11 | Telemetry, diagnostics, tracking, advertising |
| Chrome | 9 | WebRTC, DoH, DNS, telemetry, extensions |
| Safari | 11 | WebRTC, tracking, search, telemetry |
| Shell Security | 3 | Dangerous aliases, history permissions, safe PATH |
| **Total** | **~85** | |

## Deferred in v0.2.0 (available in `deferredChecks`)

| Category | Count | Reason |
|----------|-------|--------|
| Telemetry duplicates (ClaudeProtection) | 5 | PrivacyModule already covers |
| Low-value env signals | 6 | Info-only, no auto-fix |
| Downgraded items | 5 | Summary/redundant, third-party tools |
| **Total** | **16** | Restorable from `deferredChecks` |

---

## Release Process

1. Tag: `git tag v0.2.0`
2. Build: `bash scripts/build_app.sh release`
3. Smoke test on Sequoia + Tahoe VMs
4. Archive to `release/v0.2.0/`
5. Update HANDOFF.md version + project stage → Beta

---

## Known Gaps (v0.2.1+)
- Architecture unification (CLI still has duplicate module files)
- ClaudeProtectionModule independent risk scoring
- M5 accessibility / localization
- ip_quality real-world performance benchmark
- A3 checks (IP quality, dev tools, system info) not yet tagged with priority
