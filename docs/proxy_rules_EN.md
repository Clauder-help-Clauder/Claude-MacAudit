# PROXY RULES

[English](proxy_rules_EN.md) · [中文](proxy_rules.md)

> All Claude Code / Codex traffic must egress through a **Residential IP** proxy

---

## Why Residential IPs?

- 🔴 Datacenter IPs / VPS / cloud IPs are flagged as high-risk by Anthropic's risk-control system
- 🔴 Datacenter IP ranges are on public blocklists (datacenter / hosting / business) — Claude Code checks these on startup
- 🟢 Residential IPs are the **only** egress type that passes Anthropic's risk checks
- 🔴 Once banned, your `deviceId` is permanently linked — switching accounts won't help unless you reset `~/.claude.json`

---

## Recommended Proxy Clients

| Client | Platform | Notes |
|--------|----------|-------|
| 🟢 **Surge** | macOS / iOS | Professional network debugging tool. Rule-based routing, Fake-IP DNS, Enhanced Mode TUN captures all system traffic. **First choice for Claude protection.** |
| 🟢 **Shadowrocket** | iOS / macOS | Supports Shadowsocks / V2Ray / Trojan. Good backup when Surge is not available. |
| 🟢 **V2RayU / V2RayX** | macOS | Native macOS V2Ray clients supporting VMess / VLESS. Requires manual system-proxy setup. |
| 🟢 **Clash Verge / ClashX Meta** | macOS / Windows | Strong rule-routing. Watch DNS config to prevent leaks. |
| 🔴 **Avoid CC-SWITCH** and similar API-swapping tools | | If you need to drive other LLMs, edit config files manually. Swap tools' risk posture is unknown / unconfirmed. |

---

## Five Non-negotiable Proxy Settings

1. 🔴 **Egress IP must be Residential** — not datacenter / VPS / cloud.
2. 🔴 **Global mode** — proxy must cover all traffic (CLI, npm, git). Browser-only proxying leaks.
3. 🔴 **IPv6 fully off** — IPv6 bypasses the proxy and exposes your real IP (`ipv6=false` / disable at system level).
4. 🔴 **DNS leak protection** — use Fake IP (198.18.0.2) or encrypted DNS (DoH/DoT) to block ISP-level DNS snooping.
5. 🔴 **Pin AI domains to a stable node** — `anthropic.com` / `claude.ai` / `openai.com` / `chatgpt.com` should route through a fixed exit to avoid IP churn. Claude and Codex can share the same residential IP (their risk-control systems are independent).

---

## Surge Configuration Reference (battle-tested)

### [General] Base config

```ini
ipv6 = false                    # Disable IPv6 to prevent leaks
ipv6-vif = off                  # Disable IPv6 on the TUN interface too
dns-server = 223.5.5.5, 119.29.29.29, system
encrypted-dns-server = https://223.5.5.5/dns-query
udp-policy-not-supported-behaviour = REJECT  # Reject when UDP is unsupported
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, localhost, *.local
```

### [Rule] Claude-specific rules

```ini
# All Claude/Anthropic domains → fixed exit
DOMAIN-SUFFIX,anthropic.com,Claude-Stable
DOMAIN-SUFFIX,claude.ai,Claude-Stable
DOMAIN-SUFFIX,claude.com,Claude-Stable
DOMAIN-SUFFIX,claude.dev,Claude-Stable
DOMAIN-SUFFIX,claudeusercontent.com,Claude-Stable
DOMAIN-SUFFIX,statsigapi.net,Claude-Stable
DOMAIN-SUFFIX,datadoghq.com,Claude-Stable
DOMAIN-SUFFIX,intercom.io,Claude-Stable
DOMAIN-KEYWORD,anthropic,Claude-Stable
DOMAIN-KEYWORD,claude,Claude-Stable
```

### [Rule] Codex / OpenAI rules

```ini
# All Codex / OpenAI domains → fixed exit
# Safe to share the AI-Stable node with Claude (two companies' risk controls are independent — same residential IP is fine)
DOMAIN-SUFFIX,openai.com,AI-Stable
DOMAIN-SUFFIX,chatgpt.com,AI-Stable
DOMAIN-SUFFIX,oaistatic.com,AI-Stable
DOMAIN-SUFFIX,oaiusercontent.com,AI-Stable
DOMAIN-KEYWORD,openai,AI-Stable
DOMAIN-KEYWORD,chatgpt,AI-Stable

# Risk control / telemetry (OpenAI and Anthropic both use Statsig + Sentry + Datadog)
DOMAIN-SUFFIX,statsig.com,AI-Stable
DOMAIN-SUFFIX,sentry.io,AI-Stable
DOMAIN-SUFFIX,cloudflareinsights.com,AI-Stable
```

> 💡 You can also rename `Claude-Stable` above to a unified `AI-Stable` so Claude + Codex share the same residential IP node (recommended — most home users only have one residential IP).

### [Rule] STUN / WebRTC leak protection

```ini
# Block STUN requests to anything outside Claude/Codex domains
AND,((PROTOCOL,STUN),(NOT,((OR,((DOMAIN-SUFFIX,anthropic.com),(DOMAIN-SUFFIX,claude.ai),(DOMAIN-SUFFIX,openai.com),(DOMAIN-SUFFIX,chatgpt.com)))))),REJECT
```

### [Host] Encrypted DNS for Claude / Codex domains

```ini
# Force AI service domains through Google DoH
*.anthropic.com = server:https://dns.google/dns-query
*.claude.ai = server:https://dns.google/dns-query
*.claude.com = server:https://dns.google/dns-query
*.statsigapi.net = server:https://dns.google/dns-query
*.openai.com = server:https://dns.google/dns-query
*.chatgpt.com = server:https://dns.google/dns-query
*.oaistatic.com = server:https://dns.google/dns-query
```

### [Proxy Group] Stable egress (shared by Claude + Codex)

```ini
# Recommended: Claude and Codex share one residential-IP node
AI-Stable = fallback, main-node, backup-1, backup-2,
  url=http://cp.cloudflare.com/generate_204, interval=300, timeout=5
```

### ⚠️ Claude / Codex account best practices

- 🟢 **Claude and Codex can share the same residential IP** (independent risk-control systems)
- 🔴 Don't cycle your egress IP frequently — every switch adds risk signal
- 🟢 Strict combo: 1 machine + 1 residential IP + 1 account set is the most stable setup
- 🔴 Once banned, the `deviceId` is permanently linked. Switching accounts won't recover you — you must reset the AI client's local state

---

## Shadowrocket configuration notes

- Select "Global Proxy" mode after adding a node (NOT rule mode)
- Install and trust the CA cert: Settings → General → About → Certificate Trust Settings
- Disable IPv6: Settings → Cellular → Cellular Data Options → IPv6 Off
- Encrypted DNS: set to `https://1.1.1.1/dns-query`

---

## V2RayU configuration notes

- PAC mode is unsafe; use **Global mode** or configure system proxy to cover all traffic
- Manually set system proxy: Network → Wi-Fi → Proxies → HTTP/HTTPS → `127.0.0.1:<port>`
- Verify IPv6 off and no DNS leaks via MacAudit checks
- ⚠️ V2RayU doesn't support Fake IP — manually configure DoH to prevent DNS leaks

---

## Emergency protection when Surge is off

- 🟢 Add Claude domains to `/etc/hosts` → `0.0.0.0` to hard-block direct connections
- 🟢 The hosts file is your **last line of defense** when the proxy drops
- 🟢 After editing hosts, run `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`
- 🟢 Set `CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1` in Claude Code env to ensure the proxy handles DNS

---

## Verification

- 🟢 Run MacAudit → confirm all A0 checks pass
- 🟢 Visit [ipleak.net](https://ipleak.net) → DNS egress matches your proxy IP
- 🟢 Visit [browserleaks.com/webrtc](https://browserleaks.com/webrtc) → "No Leak"
- 🟢 Visit [whoer.net](https://whoer.net) → score 85+ and Proxy shows "No"
- 🟢 Terminal: `curl ip.sb --proxy $HTTPS_PROXY` → egress shows residential IP

---

## Account-Hygiene Best Practices (Account-Layer Protection)

- 🟢 **Strongly recommended: fresh macOS install** (Erase All Content and Settings / clean install)
  - Clean device fingerprint, no old-account links
  - Removes lingering login state, cookies, Keychain entries in `~/Library/`
- 🟢 **Subscribe to Claude / Codex via an iCloud account** when possible
  - Payment flows through App Store IAP (In-App Purchase) — **fully detaches billing from credit cards**
  - Apple takes ~30% platform fee, in return you get:
    - No credit-card fraud / chargeback exposure
    - No bank risk-labeling (cross-account card sharing is a leading ban driver)
    - Compliant, traceable payments (Apple ID purchase history)
  - One-tap cancel; no long-term bound payment method
- 🔴 **Credit-card-based AI subscriptions carry the highest ban risk** of any payment method

---

## About Our Practice

> We continuously run **3× Claude Max 20×** and **3× Codex 20×** accounts, protected by the proxy and system-hardening rules above. **One month. Zero bans.**

The formula is simple but hard to execute:

> **Stable residential IP → all Claude domains through a fixed node → don't change machines or lines → execute the full protection plan → no bans.**

The hard part is everything in the middle: DNS-leak prevention, IPv6-bypass blocking, making sure every CLI tool routes through the proxy, configuring Surge/Clash rules so `anthropic.com` / `claude.ai` / `statsigapi.net` / `datadoghq.com` are all routed correctly. MacAudit automates the detection.

**Thanks to [wstormai](https://wstormai.store/) for providing reliable subscription top-up service throughout our testing.**

**Clauder Help Clauder.** ⭐ If this kept your account alive, please give us a star. [https://github.com/Clauder-help-Clauder/Claude-MacAudit/](https://github.com/Clauder-help-Clauder/Claude-MacAudit/)
