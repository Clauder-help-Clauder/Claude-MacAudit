# MacAudit VM 测试 — 覆盖率分析

## 总结

| 指标 | 总量 | 已测试 | 未测试 | 覆盖率 |
|------|------|--------|--------|--------|
| 总 check 数 | 401 | — | — | — |
| 含 command 的 check | 325 | 96 | 229 | **29.5%** |
| 含 fixCommand 的 check | 292 | 111 | 181 | **38.0%** |
| 总执行次数 | — | 621 | — | — |

## 已完整测试的模块 ✅

| 模块 | command 测试 | fixCommand 测试 |
|------|-------------|----------------|
| SafariModule (m15) | ✅ 12/12 | ✅ 11/12 (1 Tahoe-only) |
| PrivacyModule (m4) | ✅ 17/17 | ✅ 17/17 |
| NetworkSecurity M2 | ✅ 15/15 | ✅ 7/7 |
| NetworkSecurity M3 | ✅ 12/12 | ⚠️ 4/5 (缺 m3.remote_login) |
| NetworkSecurity M8 | ✅ 17/17 | ⚠️ 13/17 (缺 3 sysctl + 1 plist) |

## 未测试/部分测试的模块

### 1. ServicesModule — 0/76 fixCommand 测试 ❌

76 条 fixCommand 全部未测试。格式统一:
```
launchctl disable gui/$(id -u)/{service} && launchctl bootout gui/$(id -u)/{service} 2>/dev/null; true
```

**风险**: HIGH — 数量最多，且会实际禁用系统服务
**建议**: 抽样测试 5-10 个服务（禁用→验证→启用→验证），不做全量

### 2. DevEnvironmentModule — 0/55 fixCommand 测试 ❌

55 条 fixCommand 全部未测试。分为几类:
- **安装命令**: brew install, curl|sh, npm install -g 等 (约 40 条)
- **配置命令**: git config, echo >> ~/.zshrc, PlistBuddy 等 (约 15 条)

**风险**: HIGH — 安装命令会修改系统，不可简单 restore
**建议**: 不在 VM 上做全量安装测试；可测试配置类命令（echo >> ~/.zshrc, git config 等）

### 3. ChromeModule — 0/10 fixCommand 测试 ❌

10 条 PlistBuddy fixCommand 全部未测试。VM 未安装 Chrome。

**风险**: MEDIUM — 需要创建 Managed Preferences plist
**建议**: 手动创建空 plist 后测试 2-3 条

### 4. ClaudeProtectionModule — 6/22 fixCommand 测试 ⚠️

| 未测 fixCommand | 命令类型 |
|----------------|---------|
| m10.env_claude_code_proxy_reso | echo >> ~/.zshrc |
| m10.env_claude_enable_stream_w | echo >> ~/.zshrc |
| m10.env_claude_code_subprocess | echo >> ~/.zshrc |
| m10.env_claude_stream_idle_tim | echo >> ~/.zshrc |
| m10.sandbox_proxy | jq ~/.claude/settings.json |
| m10.sandbox_domains | jq ~/.claude/settings.json |
| m10.sandbox_managed | jq ~/.claude/settings.json |
| m10.ipv6_global | networksetup 循环 |
| m10.wifi_ipv6 | networksetup Wi-Fi |
| m10.mdns | sudo defaults write |
| m10.ipv6_rtadv | networksetup 循环 |
| m10.ipv6_fwd | sudo sysctl -w |
| m10.fw_global | socketfilterfw --setglobalstate |
| m10.fw_stealth | socketfilterfw --setstealthmode |
| m10.fw_signed | socketfilterfw --setallowsigned |
| m10.env_no_proxy | sed ~/.zshrc |

**风险**: MEDIUM — 含 jq 操作 JSON、sed ~/.zshrc 等需验证
**建议**: 补测 jq 相关和 sed 相关命令

### 5. PowerModule — 11/20 fixCommand 测试 ⚠️

| 未测 fixCommand | 原因 |
|----------------|------|
| m7.batt_sleep | VM 无电池 (laptop only) |
| m7.batt_disksleep | VM 无电池 |
| m7.batt_displaysleep | VM 无电池 |
| m7.batt_standby | VM 无电池 |
| m7.batt_powernap | VM 无电池 |
| m7.wifi_battery | VM 无电池 |
| m7.schedule | 未测试 pmset schedule |
| m7.lidwake | VM 不支持 |
| m7.server_mode | 组合命令，未单独测试 |

**风险**: LOW — AC 项已测，电池项 VM 无法测
**建议**: 电池项需在真实 MacBook 上测试

### 6. ShellModule — 3/8 fixCommand 测试 ⚠️

| 未测 fixCommand | 命令类型 |
|----------------|---------|
| m9.default_shell | chsh -s /bin/zsh |
| m9.brew_analytics | brew analytics off + echo >> ~/.zshrc |
| m9.ssh_controlmaster | grep + printf >> ~/.ssh/config |
| m9.dangerous_alias | sed -i ~/.zshrc |
| m9.zsh_history_cjk | python3 脚本 |
| m9.maxfiles_plist | sudo PlistBuddy 创建 plist |

### 7. AnimationModule — 38/42 fixCommand 测试 ⚠️

缺 2 条:
- m5.33 (NSStatusItem Visible NowPlaying) — controlcenter
- m5.42 (EnableStandardClickToShowDesktop) — WindowManager

### 8. IPQualityModule — 0/23 command 测试, 0 fixCommand ❌

23 条全部是网络检测命令 (curl, dig, whois, API 调用)，无 fixCommand。
**风险**: LOW — 只读查询，不会修改系统
**建议**: Phase 2 补测网络查询命令

### 9. SystemInfoModule — 0/12 command 测试, 0/1 fixCommand ⚠️

只读系统信息 (sw_vers, sysctl, df 等)，1 条 fixCommand (tmutil deletelocalsnapshots)。
**风险**: LOW — 只读查询为主

### 10. UserSecurityModule — 未找到源码 ❌

Phase 1 日志中无 `user_security` 模块。可能在 Gemini UI 变体中或已合并到其他模块。

## 结论

**测试覆盖率**:
- command: 96/325 = **29.5%**
- fixCommand: 111/292 = **38.0%**

**已覆盖的命令类型**:
- ✅ defaults read/write (safe + sudo)
- ✅ sysctl read/write (含 IPv6 read-only)
- ✅ pmset read/write (AC 部分)
- ✅ socketfilterfw get/set (部分)
- ✅ spctl status/enable/disable
- ✅ launchctl print-disabled/enable/disable (2 个服务)
- ✅ networksetup (Wi-Fi 部分)
- ✅ Safari/Privacy/Claude telemetry defaults
- ✅ Animation defaults + killall

**未覆盖的命令类型**:
- ❌ launchctl disable/bootout (76 个服务 — 数量最大)
- ❌ brew install / curl|sh / npm install -g (55 个开发工具)
- ❌ PlistBuddy 操作 Managed Preferences (10 个 Chrome)
- ❌ jq 操作 ~/.claude/settings.json (3 条)
- ❌ sed 编辑 ~/.zshrc (多条)
- ❌ chsh / tmutil / 网络检测 API 调用
