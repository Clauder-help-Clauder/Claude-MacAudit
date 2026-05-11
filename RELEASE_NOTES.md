# MacAudit v0.3.1 — Codex Protection + AIBrands Extensible Architecture

**Release Date**: 2026-05-12
**Build**: Universal Binary (arm64 + x86_64), Release optimized
**Tests**: 724/724 passing
**VM Validation**: macOS 15.6.1 (Sequoia) + macOS 26.0 (Tahoe), full fix/undo closed-loop verified

---

## What's New (since v0.3.0)

### 🆕 Codex / OpenAI Account Protection

MacAudit v0.3.1 extends its AI-service protection beyond Claude to cover **Codex / OpenAI** accounts. Three new A0-priority M10 detection checks are added, with two existing checks expanded to include OpenAI domains:

- **`m10.env_no_openai_base`** — Reverse-detect dangerous `OPENAI_BASE_URL` env var (mirrors the existing `ANTHROPIC_BASE_URL` check). Setting this redirects Codex to non-official endpoints, which OpenAI's server-side risk-control flags as high-risk.
- **`m10.hosts_openai_block`** — `/etc/hosts` fallback check: verifies all 4 Codex domains (`api.openai.com`, `chatgpt.com`, `oaistatic.com`, `oaiusercontent.com`) are blackholed to `0.0.0.0` so a proxy drop never leaks the user's residential IP.
- **`m10.proxy_ai_domains`** — Data-driven scan across **7 proxy clients** (Surge / Surge-iCloud / ClashVerge / ClashX / V2RayU / V2RayX / Shadowrocket) verifying AI-brand domain coverage. Auto-extends as new brands are added.
- **`m10.sandbox_domains`** (extended) — Claude sandbox `allowedDomains` whitelist now includes OpenAI endpoints.
- **`m10.surge_stun_reject`** (extended) — WebRTC STUN allowlist now covers both Claude and OpenAI domains.

### 🏗 AIBrands Single Source of Truth

New file `Sources/{MacAuditCore,MacAudit}/Modules/AIBrands.swift` centralizes AI brand metadata. Adding a new brand (Gemini / Copilot / DeepSeek) now requires only **one line** in `AIBrands.all`:

```swift
public static let claude = AIBrand(id: "claude", ..., domains: [...], dangerousEnvVars: ["ANTHROPIC_BASE_URL"])
public static let codex  = AIBrand(id: "codex",  ..., domains: [...], dangerousEnvVars: ["OPENAI_BASE_URL"])
public static let all: [AIBrand] = [claude, codex]  // ← extend here
```

`ProxyClients.all` enumerates 7 proxy clients' config directories. Detection commands that need to iterate brands + clients now build dynamically from these arrays instead of hardcoding.

### 💡 Account Hygiene Recommendation

New section in `docs/proxy_rules.md` and README: **Fresh macOS install + iCloud subscription for Claude/Codex** (App Store IAP payment path). Credit-card-based AI subscriptions carry chargeback and fraud-label risks that commonly cascade into account bans. App Store IAP detaches billing from the bank risk chain at the cost of ~30% Apple platform fee.

### 🧹 Internal Quality

- **6 pre-existing M10 B-group env-var detections** unified with `source ~/.zshrc 2>/dev/null;` command prefix (closing the GUI subprocess-doesn't-inherit-shell-env gap that previously caused false positives on macOS where the GUI and CLI reported different results).
- **M10 active check count lower bound** raised 30 → 33 (reflecting the 3 new checks).

### 🐛 Bug Fixes

- **5 stale `v0.2.13` version strings** in `ReportGenerator.swift` (both CLI + Core copies) and `MacAudit.swift:253` CLI banner — discovered only during VM testing, now aligned to v0.3.1. Markdown + JSON reports now print the correct version.
- **1 stale v0.3.0 test assertion** in `ReportGeneratorTests.swift:110` — caught during SOP Phase 1 execution.

---

## Breaking Changes

**None.** v0.3.0 users upgrading to v0.3.1 keep all existing check IDs, fix commands, and undo history compatible.

## Upgrade Notes

- Previous `~/.macaudit/fix-history/` entries stay valid for undo.
- No config migration required.
- If you previously set `ANTHROPIC_BASE_URL` or `OPENAI_BASE_URL` via `~/.zshrc`, v0.3.1 will now **warn** on both — remove them to pass the check.

---

## VM Test Summary

Dual-platform fix/undo closed-loop test (`/tmp/MacAudit_v0.3.1_VM_Test/`):

| Metric | Sequoia 15.6.1 | Tahoe 26.0 |
|--------|----------------|------------|
| Total active checks | 384 | 384 |
| Baseline FAIL | 75 | 92 |
| Fix effectiveness (fail → pass) | +14 | +14 |
| Regressions (pass → fail) | 0 | 0 |
| Undo OK / FAIL | 32 / 3 | 38 / 3 |
| Drift (baseline vs post-undo) | 2 | 1 |

Drift items are all Siri-plist-cache related (Gotcha #5, pre-existing on VMs with no Siri setup).

---

## Architecture Note

This release introduces a lightweight data-layer refactor (`AIBrands.swift`). Future releases may lift additional per-brand detections (e.g., `env_no_openai_base` → `env_no_<brand>_base` auto-generated from `AIBrands.all`) but this patch keeps the existing check IDs stable.

---

**Full changelog**: [CHANGELOG.md](CHANGELOG.md)
**Full docs**: [docs/proxy_rules.md](docs/proxy_rules.md)
**Source repo**: https://github.com/Clauder-help-Clauder/Claude-MacAudit

**Clauder Help Clauder.** ⭐
