# MacAudit v0.3.0 — Stable Release

**Release Date**: 2026-05-11
**Build**: Universal Binary (arm64 + x86_64), Release optimized
**Tests**: 719/719 passing
**VM Validation**: macOS 15 + macOS 26, 10-round stability test, 100% consistent

---

## What's New (since v0.2.0)

### Fix System Overhaul
- **Idempotent fix execution** — sed delete-then-append strategy, never duplicates
- **Post-fix verification** — grep-based verify for env var fixes, defaults-read for system prefs
- **Anchored sed patterns** — `^export VAR=` prevents accidental comment/heredoc deletion
- **Full audit logging** — audit/fix/actions logs in ~/.macaudit/logs/

### Essential Mode (120 checks, 7 modules)
- IP Quality: all 23 checks → A0
- Chrome/Safari: all checks → A0
- SystemInfo, Privacy, NetworkSecurity DNS-leak checks → A0

### Security Hardening (dual-agent audit)
- ShellExecutor param validation (isSafeParam)
- ProxyRuleView plain-text rendering (no link injection)
- All curl calls use HTTPS
- ClaudeProtection temp files use ~/.claude/ (not /tmp/)
- FixEngine shellEscape blocks `"` and `\`
- AuditLogger newline sanitization + NSLock

### CLI Improvements
- Proxy Rules menu entry
- Version + GitHub URL on home screen
- Paged output for long lists
- Merged proxy function checks (1 command deploys all)

### GUI Fixes
- CLI/GUI check alignment (source ~/.zshrc for env detection)
- Info-only modules show 100%
- PROXY RULES online fetch

---

## Downloads

| File | Description |
|------|-------------|
| `builds/MacAudit-CLI-v0-3-0` | CLI (Universal, release) |
| `builds/MacAudit-GUI-v0.3.0.app` | GUI (Universal, release) |

---

## Compatibility

| macOS | Tested | Result |
|-------|--------|--------|
| 15.6.1 (Sequoia) arm64 | 10 rounds | 0 error, 100% stable |
| 26.0 (Tahoe) arm64 | 10 rounds | 0 error, 100% stable |
