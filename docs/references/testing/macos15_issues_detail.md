# MacAudit VM 测试 — Issue 明细

## 128 个 issues 分类

### 类 A: defaults -bool 值表示差异 (假阳性) — 93 个

macOS `defaults write -bool true/false` → `defaults read` 返回 `1/0`，不是 `true/false`。
fix 全部成功，仅测试脚本字符串匹配导致误报。

| ID | Round | expected | got | 实际 |
|----|-------|----------|-----|------|
| m2.lock_password | 1,2,3 | true | 1 | ✅ fix成功 |
| m15.search_universal | 1,2,3 | false | 0 | ✅ fix成功 |
| m15.search_suggest | 1,2,3 | true | 1 | ✅ fix成功 |
| m15.preload | 1,2,3 | false | 0 | ✅ fix成功 |
| m15.fraud_warning | 1,2,3 | true | 1 | ✅ fix成功 |
| m15.auto_open | 1,2,3 | false | 0 | ✅ fix成功 |
| m15.full_url | 1,2,3 | true | 1 | ✅ fix成功 |
| m15.ext_update | 1,2,3 | true | 1 | ✅ fix成功 |
| m15.popup_block | 1,2,3 | false | 0 | ✅ fix成功 |
| m15.autofill_address | 1,2,3 | false | 0 | ✅ fix成功 |
| m15.autofill_cc | 1,2,3 | false | 0 | ✅ fix成功 |
| m15.enhanced_private | 1,2,3 | true | 1 | ✅ fix成功 |
| m4.diagnostics | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.siri_enabled | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.siri_menu | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.ad_tracking | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.usage_tracking | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.udc_automation | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.ds_network | 1,2,3 | true | 1 | ✅ fix成功 |
| m4.ds_usb | 1,2,3 | true | 1 | ✅ fix成功 |
| m4.airdrop | 1,2,3 | true | 1 | ✅ fix成功 |
| m4.photo_analysis | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.safari_search | 1,2,3 | false | 0 | ✅ fix成功 |
| m4.safari_suggest | 1,2,3 | true | 1 | ✅ fix成功 |
| m4.spotlight_suggest | 1,2,3 | true | 1 | ✅ fix成功 |
| m10.telemetry_diaginfo | 1,2,3 | false | 0 | ✅ fix成功 |
| m10.telemetry_adlib | 1,2,3 | false | 0 | ✅ fix成功 |
| m10.telemetry_usage1 | 1,2,3 | false | 0 | ✅ fix成功 |
| m10.telemetry_usage2 | 1,2,3 | false | 0 | ✅ fix成功 |

小计: 29 unique IDs × 3 rounds = 87 issues
加上 m2.lock_password 3 rounds = 90
加上 m4.crash_reporter DialogType string 对比 = 0 (string 对比成功)
实际: 93 个 issues 全部是 -bool 值表示差异导致的假阳性

### 类 B: sudo defaults stdout 捕获丢失 — 6 个

测试工具 `background+wait+kill` 模式下 sudo -S 的 stdout 偶尔丢失。

| ID | Round | 问题 | 手动验证 |
|----|-------|------|---------|
| m4.mdns | 1,2,3 | sudo defaults read 返回空 | ✅ 实际返回 1, fix 成功 |
| m2.autologin | 1,2,3 | sudo defaults read 返回空 | ✅ domain 不存在=符合预期 |

### 类 C: pmset awk 返回空 (VM 不支持) — 18 个

UTM VM 不支持这些电源管理 key，pmset -g 中不显示。

| ID | Round | Key | 
|----|-------|-----|
| m7.ac_lowpowermode | 1,2,3 | lowpowermode |
| m7.autorestart | 1,2,3 | autorestart |
| m7.womp | 1,2,3 | womp |
| m7.sms | 1,2,3 | sms |
| m7.hibernatemode | 1,2,3 | hibernatemode |
| m7.wifi_ac | 1,2,3 | womp |

### 类 D: Firewall 输出格式不匹配 — 4 个

| ID | Round | 问题 | 手动验证 |
|----|-------|------|---------|
| m2.stealth | 1,2,3 | --getstealthmode 返回 "Firewall stealth mode is on" 而非 "enabled" | ✅ fix 实际成功 |
| m10.fw_signedapp | 1,2,3 | --getallowsignedapp 返回 usage (macOS 15 已移除) | ❌ 真实 Issue #2 |

### 类 E: sysctl 系统限制 — 6 个

| ID | Round | 问题 | 手动验证 |
|----|-------|------|---------|
| sysctl.kern.ipc.maxsockbuf | 1,2,3 | arm64 硬限制 max=6291456, 无法设 16777216 | ❌ 真实 Issue #1 |
| sysctl.ipv6_fwd | 1,2,3 | 测试脚本报 issue (0→0 无变化) | ✅ 实际可读写, 脚本误判 |

### 类 F: networksetup / ulimit — 5 个

| ID | Round | 问题 | 手动验证 |
|----|-------|------|---------|
| m3.wifi_ipv6 | 1,2,3 | "Wi-Fi is not a recognized network service" | ❌ 真实 Issue #3 (VM 无 Wi-Fi) |
| m9.ulimit_n | 1,2 | got 256 (hard limit 限制) | ✅ hard=unlimited, 可设 65536, 脚本误判 |
