# MacAudit VM 全量测试报告

- 日期: 2026-04-23
- VM: macOS 15.6.1 (24G90), arm64, UTM
- IP: <vm-ip>, user: tksandbox
- MacAudit 版本: v0.1.5 (debug, Universal binary)

---

## 测试概览

| Phase | 内容 | 条数 | 执行次数 | 结果 |
|-------|------|------|---------|------|
| Phase 1 | 模块级 3 轮稳定性 | 12 模块 | 36 次 | ✅ 11/12 一致, 1 冷启动波动 |
| Phase 2 | Shell 读命令压力测试 | 96 条 | 288 次 | ✅ 0 issues |
| Phase 3 | fixCommand apply/verify/restore | 111 条 | 333 次 | ⚠️ 128 issues (4 真实 + 124 假阳性/测试工具) |
| **总计** | | **207 条** | **621 次** | |

---

## Phase 1: 模块稳定性 (12 模块 × 3 轮)

| 模块 | ID | R1 | R2 | R3 | 结果 |
|------|-----|----|----|-----|------|
| 网络安全机制及调优 | network_security | ✅ | ✅ | ✅ | CONSISTENT |
| 网络接口 | ip_quality | ✅ | ✅ | ✅ | CONSISTENT |
| 电源配置 | power | ✅ | ✅ | ✅ | CONSISTENT |
| 隐私与遥测 | privacy | ✅ | ✅ | ✅ | CONSISTENT |
| 服务与守护进程 | services | ✅ | ✅ | ✅ | CONSISTENT |
| 系统信息 | system_info | ✅ | ✅ | ✅ | CONSISTENT |
| 开发环境 | dev | ⚠️ | ✅ | ✅ | INCONSISTENT (swift 冷启动) |
| 用户与登录 | user_security | ✅ | ✅ | ✅ | CONSISTENT |
| Shell 环境 | shell | ✅ | ✅ | ✅ | CONSISTENT |
| Claude 安全防护 | claude | ✅ | ✅ | ✅ | CONSISTENT |
| Chrome | chrome | ✅ | ✅ | ✅ | CONSISTENT (skip=13) |
| Safari | safari | ✅ | ✅ | ✅ | CONSISTENT |

### Phase 1 Issue

- **[dev] m11.swift**: R1=error, R2=info, R3=info
  - 原因: `swift --version` 首次执行冷启动超时
  - 严重程度: 低，不影响实际审计结果

---

## Phase 2: Shell 读命令 (96 条 × 3 轮)

### 测试命令明细

#### Safari defaults (12 条)
- UniversalSearchEnabled, SuppressSearchSuggestions, PreloadTopHit
- WarnAboutFraudulentWebsites, AutoOpenSafeDownloads, ShowFullURLInSmartSearchField
- InstallExtensionUpdatesAutomatically, WebKitJavaScriptCanOpenWindowsAutomatically
- AutoFillFromAddressBook, AutoFillCreditCardData, EnableEnhancedPrivacyInPrivateBrowsing
- WBSEnablePrivateRelay

#### Network security (6 条)
- csrutil status
- spctl --status
- socketfilterfw --getglobalstate
- socketfilterfw --getstealthmode
- socketfilterfw --getblockall
- defaults read /Library/Preferences/com.apple.alf globalstate

#### Gatekeeper/System (9 条)
- spctl --status
- spctl --global-disable
- defaults read com.apple.SoftwareUpdate (6 keys)
- softwareupdate --schedule

#### pmset (3 条)
- pmset -g
- pmset -g assertions
- pmset -g custom

#### sysctl (6 条)
- net.inet6.ip6.accept_rtadv
- net.inet6.ip6.forwarding
- net.inet.tcp.delayed_ack
- kern.sugid_coredump
- kern.sysv.shmmax
- net.inet.ip.forwarding

#### networksetup (7 条)
- -listallnetworkservices
- -getdnsservers Wi-Fi
- -getproxybypassdomains Wi-Fi
- -getwebproxy Wi-Fi
- -getsecurewebproxy Wi-Fi
- -getsocksfirewallproxy Wi-Fi
- scutil --proxy

#### launchctl (2 条)
- launchctl print-disabled
- launchctl list

#### DNS/mDNS (3 条)
- dig +short myip.opendns.com
- dscacheutil -flushcache
- killall -HUP mDNSResponder

#### Shell/Environment (9 条)
- $SHELL, $TERM, ulimit -n, ulimit -u
- $LANG, $LC_ALL
- defaults read -g AppleLanguages
- test -f limit.maxfiles.plist
- ls -d ~/.[!.]*

#### Dev tools (13 条)
- xcode-select -p, clang --version, xcodebuild -version
- brew --version, which brew, node -v, npm -v
- python3 --version, swift --version, git --version
- which powermetrics, ulimit -n, $JAVA_HOME

#### Claude env vars (14 条)
- CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
- CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY
- DISABLE_TELEMETRY, ANTHROPIC_BASE_URL
- NODE_TLS_REJECT_UNAUTHORIZED
- CLAUDE_CODE_PROXY_RESOLVES_HOSTS
- CLAUDE_ENABLE_STREAM_WATCHDOG
- CLAUDE_CODE_SUBPROCESS_ENV_SCRUB
- CLAUDE_STREAM_IDLE_TIMEOUT_MS
- HTTPS_PROXY, NO_PROXY, TZ, LANG, LC_ALL

#### Security/Privacy (12 条)
- loginwindow GuestEnabled, SHOWFULLNAME
- screensaver askForPassword, askForPasswordDelay
- dock orientation, autohide, expose-animation-duration
- finder ShowExternalHardDrivesOnDesktop, ShowHardDrivesOnDesktop
- fdesetup status
- system_profiler SPSoftwareDataType
- loginwindow LoginwindowText

### Phase 2 结果: 0 issues ✅

---

## Phase 3: fixCommand 测试 (111 条 × 3 轮)

### Section 1: defaults write (safe, no sudo) — 34 条

| # | ID | Domain | Key | Fix Type | Fix Value | 结果 |
|---|-----|--------|-----|----------|-----------|------|
| 1 | m2.lock_password | com.apple.screensaver | askForPassword | -bool | true | ✅ fix成功, ⚠️ 验证误报(1 vs true) |
| 2 | m2.lock_delay | com.apple.screensaver | askForPasswordDelay | -int | 0 | ✅ |
| 3 | m15.search_universal | com.apple.Safari | UniversalSearchEnabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 4 | m15.search_suggest | com.apple.Safari | SuppressSearchSuggestions | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 5 | m15.preload | com.apple.Safari | PreloadTopHit | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 6 | m15.fraud_warning | com.apple.Safari | WarnAboutFraudulentWebsites | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 7 | m15.auto_open | com.apple.Safari | AutoOpenSafeDownloads | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 8 | m15.full_url | com.apple.Safari | ShowFullURLInSmartSearchField | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 9 | m15.ext_update | com.apple.Safari | InstallExtensionUpdatesAutomatically | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 10 | m15.popup_block | com.apple.Safari | WebKitJavaScriptCanOpenWindowsAutomatically | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 11 | m15.autofill_address | com.apple.Safari | AutoFillFromAddressBook | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 12 | m15.autofill_cc | com.apple.Safari | AutoFillCreditCardData | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 13 | m15.enhanced_private | com.apple.Safari | EnableEnhancedPrivacyInPrivateBrowsing | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 14 | m4.diagnostics | com.apple.SubmitDiagInfo | AutoSubmit | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 15 | m4.crash_reporter | com.apple.CrashReporter | DialogType | -string | none | ✅ |
| 16 | m4.siri_enabled | com.apple.assistant.support | Assistant Enabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 17 | m4.siri_sharing | com.apple.assistant.support | Siri Data Sharing Opt-In Status | -int | 0 | ✅ |
| 18 | m4.siri_menu | com.apple.Siri | StatusMenuVisible | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 19 | m4.ad_tracking | com.apple.AdLib | allowApplePersonalizedAdvertising | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 20 | m4.usage_tracking | com.apple.UsageTracking | CoreDonationsEnabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 21 | m4.udc_automation | com.apple.UsageTracking | UDCAutomationEnabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 22 | m4.ds_network | com.apple.desktopservices | DSDontWriteNetworkStores | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 23 | m4.ds_usb | com.apple.desktopservices | DSDontWriteUSBStores | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 24 | m4.airdrop | com.apple.NetworkBrowser | DisableAirDrop | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 25 | m4.photo_analysis | com.apple.photoanalysisd | enabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 26 | m4.safari_search | com.apple.Safari | UniversalSearchEnabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 27 | m4.safari_suggest | com.apple.Safari | SuppressSearchSuggestions | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 28 | m4.spotlight_suggest | com.apple.lookup.shared | LookupSuggestionsDisabled | -bool | true | ✅ fix成功, ⚠️ 验证误报 |
| 29 | m10.telemetry_diaginfo | com.apple.SubmitDiagInfo | AutoSubmit | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 30 | m10.telemetry_crashreporter | com.apple.CrashReporter | DialogType | -string | none | ✅ |
| 31 | m10.telemetry_adlib | com.apple.AdLib | allowApplePersonalizedAdvertising | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 32 | m10.telemetry_usage1 | com.apple.UsageTracking | CoreDonationsEnabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 33 | m10.telemetry_usage2 | com.apple.UsageTracking | UDCAutomationEnabled | -bool | false | ✅ fix成功, ⚠️ 验证误报 |
| 34 | m7.screensaver | com.apple.screensaver (-currentHost) | idleTime | -int | 0 | ✅ |

### Section 2: sudo defaults write — 3 条

| # | ID | 操作 | 结果 |
|---|-----|------|------|
| 1 | m4.mdns | sudo defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements -bool true | ✅ fix成功, 测试工具捕获丢失 |
| 2 | m4.captive | sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false | ✅ 手动验证: 1→0→1 正常 |
| 3 | m2.autologin | sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser | ✅ domain 不存在=已符合预期 |

### Section 3: Firewall — 4 条

| # | ID | 命令 | 结果 |
|---|-----|------|------|
| 1 | m2.firewall | socketfilterfw --setglobalstate on/off | ✅ |
| 2 | m2.stealth | socketfilterfw --setstealthmode on/off | ✅ fix成功, 输出格式不匹配 (见 Issue #4) |
| 3 | m2.allowsigned | socketfilterfw --setallowsigned on/off | ✅ |
| 4 | m10.fw_signedapp | socketfilterfw --setallowsignedapp on/off | ❌ macOS 15 已移除 (见 Issue #2) |

### Section 4: Gatekeeper — 1 条

| # | ID | 命令 | 结果 |
|---|-----|------|------|
| 1 | m2.gatekeeper | spctl --master-enable/disable | ✅ |

### Section 5: pmset — 11 条

| # | ID | Key | Scope | Fix Value | VM 结果 |
|---|-----|-----|-------|-----------|---------|
| 1 | m7.ac_sleep | sleep | -c | 0 | ✅ |
| 2 | m7.ac_disksleep | disksleep | -c | 0 | ✅ |
| 3 | m7.ac_displaysleep | displaysleep | -c | 10 | ✅ |
| 4 | m7.ac_standby | standby | -c | 0 | ✅ |
| 5 | m7.ac_powernap | powernap | -c | 0 | ✅ |
| 6 | m7.ac_lowpowermode | lowpowermode | -c | 0 | ❌ VM 不支持, pmset -g 无此 key |
| 7 | m7.autorestart | autorestart | -a | 1 | ❌ VM 不支持 |
| 8 | m7.womp | womp | -a | 1 | ❌ VM 不支持 |
| 9 | m7.sms | sms | -a | 0 | ❌ VM 不支持 |
| 10 | m7.hibernatemode | hibernatemode | -a | 3 | ❌ VM 不支持 |
| 11 | m7.wifi_ac | womp | -c | 1 | ❌ VM 不支持 |

### Section 6: sysctl — 13 条

| # | ID | 参数 | Fix Value | 结果 |
|---|-----|------|-----------|------|
| 1 | sysctl.sendspace | net.inet.tcp.sendspace | 1048576 | ✅ |
| 2 | sysctl.recvspace | net.inet.tcp.recvspace | 1048576 | ✅ |
| 3 | sysctl.delayed_ack | net.inet.tcp.delayed_ack | 0 | ✅ |
| 4 | sysctl.maxsockbuf | kern.ipc.maxsockbuf | 16777216 | ❌ 超系统限制 (见 Issue #1) |
| 5 | sysctl.win_scale | net.inet.tcp.win_scale_factor | 8 | ✅ |
| 6 | sysctl.slowstart | net.inet.tcp.local_slowstart_flightsize | 20 | ✅ |
| 7 | sysctl.sack | net.inet.tcp.sack | 1 | ✅ |
| 8 | sysctl.keepalive | net.inet.tcp.always_keepalive | 1 | ✅ |
| 9 | sysctl.msl | net.inet.tcp.msl | 5000 | ✅ |
| 10 | sysctl.tcp_blackhole | net.inet.tcp.blackhole | 2 | ✅ |
| 11 | sysctl.udp_blackhole | net.inet.udp.blackhole | 1 | ✅ |
| 12 | sysctl.ipv6_rtadv | net.inet6.ip6.accept_rtadv | 0 | ✅ 正确检测为 read-only |
| 13 | sysctl.ipv6_fwd | net.inet6.ip6.forwarding | 0 | ✅ 手动验证可读写 |

### Section 7: networksetup — 1 条

| # | ID | 命令 | 结果 |
|---|-----|------|------|
| 1 | m3.wifi_ipv6 | networksetup -setv6off Wi-Fi | ❌ VM 无 Wi-Fi 接口 (见 Issue #3) |

### Section 8: launchctl — 2 条

| # | ID | 命令 | 结果 |
|---|-----|------|------|
| 1 | m3.remote_events | launchctl disable/enable system/com.apple.eppc | ✅ |
| 2 | m3.smb | launchctl disable/enable system/com.apple.smbd | ✅ |

### Section 9: mDNSResponder — 1 条

| # | ID | 命令 | 结果 |
|---|-----|------|------|
| 1 | m4.mdns_killall | defaults write + killall -HUP mDNSResponder | ✅ |

### Section 10: Shell — 3 条

| # | ID | 命令 | 结果 |
|---|-----|------|------|
| 1 | m9.ulimit_n | ulimit -n 65536 | ✅ 手动验证成功 |
| 2 | m9.ulimit_u | ulimit -u 2048 | ✅ |
| 3 | m9.ssh_config | 创建 ~/.ssh/config | ✅ |

### Section 11: Animation defaults + killall — 38 条

| # | ID | Domain | Key | Kill Target | 结果 |
|---|-----|--------|-----|-------------|------|
| 1 | anim.autohide-delay | com.apple.dock | autohide-delay | Dock | ✅ |
| 2 | anim.autohide-time | com.apple.dock | autohide-time-modifier | Dock | ✅ |
| 3 | anim.launchanim | com.apple.dock | launchanim | Dock | ✅ |
| 4 | anim.magnification | com.apple.dock | magnification | Dock | ✅ |
| 5 | anim.expose-anim | com.apple.dock | expose-animation-duration | Dock | ✅ |
| 6 | anim.springboard-show | com.apple.dock | springboard-show-duration | Dock | ✅ |
| 7 | anim.springboard-hide | com.apple.dock | springboard-hide-duration | Dock | ✅ |
| 8 | anim.springboard-page | com.apple.dock | springboard-page-duration | Dock | ✅ |
| 9 | anim.mineffect | com.apple.dock | mineffect | Dock | ✅ |
| 10 | anim.tilesize | com.apple.dock | tilesize | Dock | ✅ |
| 11 | anim.show-recents | com.apple.dock | show-recents | Dock | ✅ |
| 12 | anim.wvous-tl | com.apple.dock | wvous-tl-corner | Dock | ✅ |
| 13 | anim.wvous-tr | com.apple.dock | wvous-tr-corner | Dock | ✅ |
| 14 | anim.wvous-bl | com.apple.dock | wvous-bl-corner | Dock | ✅ |
| 15 | anim.wvous-br | com.apple.dock | wvous-br-corner | Dock | ✅ |
| 16 | anim.NSAutomaticWindow | -g | NSAutomaticWindowAnimationsEnabled | - | ✅ |
| 17 | anim.NSWindowResizeTime | -g | NSWindowResizeTime | - | ✅ |
| 18 | anim.NSToolbarFullScreen | -g | NSToolbarFullScreenAnimationDuration | - | ✅ |
| 19 | anim.NSDocRevisions | -g | NSDocumentRevisionsWindowTransformAnimation | - | ✅ |
| 20 | anim.NSBrowserColumn | -g | NSBrowserColumnAnimationSpeedMultiplier | - | ✅ |
| 21 | anim.NSScrollAnimation | -g | NSScrollAnimationEnabled | - | ✅ |
| 22 | anim.NSScrollViewRubber | -g | NSScrollViewRubberbanding | - | ✅ |
| 23 | anim.QLPanelDuration | -g | QLPanelAnimationDuration | - | ✅ |
| 24 | anim.ToolTipDelay | -g | NSInitialToolTipDelay | - | ✅ |
| 25 | anim.springing-delay | -g | com.apple.springing.delay | - | ✅ |
| 26 | anim.AppSleepDisabled | NSGlobalDomain | NSAppSleepDisabled | - | ✅ |
| 27 | anim.KeyRepeat | -g | KeyRepeat | - | ✅ |
| 28 | anim.InitialKeyRepeat | -g | InitialKeyRepeat | - | ✅ |
| 29 | anim.NSUseAnimatedFocusRing | -g | NSUseAnimatedFocusRing | - | ✅ |
| 30 | anim.NSDisableAutoTerm | -g | NSDisableAutomaticTermination | - | ✅ |
| 31 | anim.FinderDisable | com.apple.finder | DisableAllAnimations | Finder | ✅ |
| 32 | anim.LSQuarantine | com.apple.LaunchServices | LSQuarantine | - | ✅ |
| 33 | anim.TMNoOffer | com.apple.TimeMachine | DoNotOfferNewDisksForBackup | - | ✅ |
| 34 | anim.ShowExtensions | NSGlobalDomain | AppleShowAllExtensions | Finder | ✅ |
| 35 | anim.SortFoldersFirst | com.apple.finder | _FXSortFoldersFirst | Finder | ✅ |
| 36 | anim.ScreenShadow | com.apple.screencapture | disable-shadow | - | ✅ |
| 37 | anim.ScreenSaverIdle | com.apple.screensaver | idleTime | - | ✅ |
| 38 | anim.ScreenCapType | com.apple.screencapture | type | - | ✅ |

---

## 确认的真实 Issues (需修改源码)

### Issue #1: kern.ipc.maxsockbuf 超系统限制 — P1

- **源码**: `NetworkSecurityModule.swift:44-45` (SysctlDef), `:494` (fixCommand plist)
- **VM 验证**: `sysctl -w kern.ipc.maxsockbuf=16777216` → `Result too large`
- **原因**: macOS arm64 内核硬限制 maxsockbuf = 6291456 (6MB)，无法设为 16777216 (16MB)
- **尝试 8388608 也失败，只有 ≤6291456 可写入**
- **建议**: 移除此 fixCommand，或改为读取当前 max 值后设置合理值

### Issue #2: socketfilterfw --getallowsignedapp macOS 15 已移除 — P1

- **源码**:
  - `ClaudeProtectionModule.swift:511-517` (m10.fw_signedapp)
  - `NetworkSecurityModule.swift:132,139` (m2.allowsigned fixCommand 包含 --setallowsignedapp)
- **VM 验证**:
  - `--getallowsignedapp` → 返回 usage（参数已不存在于 macOS 15.x）
  - `--setallowsignedapp on` → 静默不报错但不生效
  - `--getallowsigned` → 正常工作
- **原因**: macOS 15 合并了 allowsigned 和 allowsignedapp 为单一的 `--getallowsigned`
- **建议**: 移除 m10.fw_signedapp 整条 check；m2.allowsigned fixCommand 去掉 --setallowsignedapp

### Issue #3: Wi-Fi 接口名硬编码 — P3

- **源码**: `NetworkSecurityModule.swift:12` (`wifiInterfaceName = "Wi-Fi"`)
- **VM 验证**:
  - UTM VM 网络服务名: `com.redhat.spice.0`, `Ethernet`（无 Wi-Fi）
  - `networksetup -getinfo Wi-Fi` → `Wi-Fi is not a recognized network service`
  - 动态获取第一个服务名后操作成功
- **源码注释**: `⚠️ 不要改回 Process() 探测！GUI 会在 dispatchOnce 里递归死锁`
- **原因**: 已知的设计权衡，硬编码避免 GUI 死锁
- **影响**: 仅影响无 Wi-Fi 的 VM/服务器，真实 Mac 几乎总有 Wi-Fi
- **建议**: 低优先级，可在审计结果中增加 hint 提示用户手动替换接口名

### Issue #4: pmset 不支持的 key 应标记为 skip — P2

- **源码**: `PowerModule.swift` 全模块 (pmsetCmd 函数)
- **VM 验证**:

| Key | pmset 设值 | pmset -g 显示 | 原因 |
|-----|-----------|--------------|------|
| lowpowermode | 不报错 | 不出现 | VM 无电池，AC Power 不支持 |
| autorestart | 不报错 | 不出现 | UTM 虚拟电源不支持 |
| womp | 不报错 | 不出现 | VM 无物理网卡 |
| sms | 不报错 | 不出现 | VM 无 HDD 跌落传感器 |
| hibernatemode | Usage 报错 | 不出现 | VM 不支持休眠到磁盘 |
| lidwake | 不报错 | 不出现 | VM 无合盖传感器 |

- **影响**: `pmset -g | awk` 读不到值 → 返回空 → MacAudit 报告为 fail（实际是不支持）
- **建议**: pmsetCmd() 增加 fallback：若 awk 返回空，标记为 skip 而非 fail

### Bonus: socketfilterfw --getstealthmode 输出格式

- **源码**: `NetworkSecurityModule.swift:122`
- **VM 验证**: `--getstealthmode` 返回 `"Firewall stealth mode is on"` 而非 `"enabled"`
- **源码 command**: `grep -oi 'ENABLED\\|DISABLED'` → 匹配不到 `"is on"`
- **影响**: command 输出为空，比对 expected="enabled" 失败，报告为 fail
- **建议**: command 正则加上 `on$\\|off$`，或改用 `grep -o 'on$\|off$'`
