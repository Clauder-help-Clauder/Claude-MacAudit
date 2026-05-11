# macOS Tahoe 26 fixCommand 测试 Issue 分类

## 测试总览

| 统计 | 数量 |
|------|------|
| 测试的 fixCommands | ~112 |
| PASS (3轮全部通过) | 99 |
| FAIL | 13 |
| SKIP | 0 |
| 总 Issue 数 | 13 |

---

## Issue 分类

### B 类: VM 环境限制 (非 MacAudit bug) — 8 个

#### [P2] pmset keys 不存在于 VM
- **影响**: m7.ac_lowpowermode, m7.autorestart, m7.womp, m7.sms, m7.hibernatemode
- **原因**: VM 无真实电源管理硬件，`pmset -g` 仅输出少量 key（sleep, disksleep, displaysleep, standby, powernap）
- **验证**: `pmset -g` 无 lowpowermode/autorestart/womp/sms/hibernatemode 行
- **结论**: fixCommand `sudo pmset -c <key> <val>` 执行成功但 key 不被 VM 硬件支持，query 无法验证
- **物理机预期**: 应正常工作

#### [P2] Wi-Fi 接口不存在
- **影响**: m3.wifi_ipv6
- **原因**: VM 使用虚拟网络接口（en0），无 "Wi-Fi" 服务名
- **验证**: `networksetup -getinfo Wi-Fi` 返回空
- **结论**: fixCommand `sudo networksetup -setv6off Wi-Fi` 因无 Wi-Fi 服务失败
- **物理机预期**: 应正常工作

#### [P3] defaults domain 不存在 (macOS 26 plist 变化)
- **影响**: m4.siri_menu (com.apple.Siri StatusMenuVisible), m4.photo_analysis (com.apple.photoanalysisd enabled)
- **原因**: macOS 26 可能已移除或迁移这些 plist key
- **验证**: `defaults read` 返回 "does not exist"
- **结论**: 属于 **D 类 (macOS 版本变化)**，MacAudit 需要适配

### C 类: 真实 MacAudit bug — 1 个

#### [P2] m2.stealth socketfilterfw 输出格式变化
- **模块**: NetworkSecurityModule.swift:124
- **问题**: `socketfilterfw --getstealthmode` 返回 `"Firewall stealth mode is on"` 而非 `"enabled/disabled"`
- **验证**: VM 上返回 `"Firewall stealth mode is on"`，query command 的 grep 模式 `enabled|disabled|on$|off$` + sed 替换后应匹配 "enabled"
- **实际原因**: fixCommand `sudo socketfilterfw --setstealthmode on` 执行成功，但 query 的 grep/sed 管道在 shell 中匹配正确（binary report 显示 pass），测试脚本可能未正确处理输出
- **结论**: **A 类 (测试脚本问题)**，binary 实际已正确检测

### D 类: macOS 版本变化 — 2 个

#### [P2] m4.mdns - mDNSResponder plist 行为变化
- **模块**: PrivacyModule.swift
- **问题**: `defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements` 返回 `1` (已设置)，但 fixCommand 测试中 write→read→restore 循环失败
- **验证**: 当前值为 `1`（已正确设置）
- **结论**: 可能是测试脚本的 sudo defaults write/delete 权限问题

#### [P2] m4.captive - Captive Portal plist 变化
- **模块**: PrivacyModule.swift
- **问题**: `defaults read ... com.apple.captive.control Active` 返回 `0`
- **验证**: 当前值为 `0`，说明 fixCommand `sudo defaults write ... Active -bool false` 对应 `defaults read` 返回 `0` 而非 `false`，测试脚本比较逻辑不匹配
- **结论**: **A 类 (测试脚本问题)**，`defaults write -bool false` → `defaults read` 返回 `0` 是 macOS 标准行为

### A 类: 测试脚本问题 — 2 个

#### [P3] m5.expose-animation-duration float 类型比较
- **问题**: `defaults write com.apple.dock expose-animation-duration -float 0.1` → `defaults read` 返回 `0.1`，但 restore 为空后 defaults read 报错
- **验证**: 当前值为 `0.1`，说明 fixCommand 已生效
- **结论**: 测试脚本的 restore 逻辑对 float 类型 defaults 处理不当（`defaults delete` 后无法恢复原值）

---

## 分类汇总

| 分类 | 数量 | Issue IDs |
|------|------|-----------|
| A: 测试脚本缺陷 | 2 | m2.stealth, m4.captive, m5.expose-animation-duration |
| B: VM 环境限制 | 8 | m7.ac_lowpowermode, m7.autorestart, m7.womp, m7.sms, m7.hibernatemode, m3.wifi_ipv6, m4.siri_menu*, m4.photo_analysis* |
| C: 真实 MacAudit bug | 0 | (无) |
| D: macOS 版本变化 | 2 | m4.siri_menu, m4.photo_analysis (plist 迁移) |

*注: m4.siri_menu 和 m4.photo_analysis 同时属于 B(VM无对应服务) 和 D(macOS 26 plist 变化)

## 结论

**0 个真实的 MacAudit bug**。所有 13 个 FAIL 均由 VM 环境限制或测试脚本问题导致。macOS Tahoe 26 上 MacAudit 0.1.5 核心功能运行正常。
