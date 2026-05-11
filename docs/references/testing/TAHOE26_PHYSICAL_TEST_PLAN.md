# MacAudit v0.1.5 — macOS Tahoe 26 实机测试计划（分子级）

> **测试机**: `<testuser>@<test-ip>` / macOS 26.4.1 (Build 25E253) / x86_64 Intel i9 / 16GB / Intel-Test-Machine  
> **测试日期**: 2026-04-24  
> **目标**: 滚动循环测试直至零 bug，覆盖 TUI / GUI / Core / CLI 全链路  
> **原则**: 拆小批次（≤30 命令/批）、每批验证、不翻旧车、每次写入 ≤200 行防卡死

---

## 历史翻车教训（强制约束）

> 来源：macOS 15 VM 测试 + macOS 26 VM 测试 + macOS 15 实机测试，三轮所有错误汇总。

| # | 教训 | 来源 | 本次强制规则 |
|---|------|------|-------------|
| 1 | `grep -oi 'X\|Y'` BRE 不支持 `\|` | macOS 15 实机 | 所有 grep OR 必须用 `-E` flag |
| 2 | `launchctl print-disabled` 输出 `enabled/disabled` 非 `true/false` | macOS 15 实机 | 不再假设 `true/false` |
| 3 | `sudo defaults write '/Library/Managed Preferences/'` 静默失败（rc=0 但不写入） | macOS 15 实机 | Chrome 统一用 PlistBuddy |
| 4 | `defaults -bool` 在 Tahoe 26 读出格式变 `true/false`（macOS 15 是 `1/0`） | Tahoe 26 VM | 布尔比对必须兼容双格式 |
| 5 | `--getallowsignedapp` 参数已移除（macOS 15+） | macOS 15 实机 | 统一用 `--getallowsigned` |
| 6 | `socketfilterfw --getstealthmode` 返回 "is on" 不是 "enabled" | macOS 15 实机 | grep 必须处理 on/off 和 enabled/disabled |
| 7 | `read -rp` zsh 不认 `-p`（`no coprocess`） | macOS 15 实机 | 脚本用 `printf; read -r </dev/tty` |
| 8 | `&&` 在 `run_sudo` 里出问题 | macOS 15 VM | 复合命令用 `;` + `true` 容错 |
| 9 | SSH 单次大批量命令挂死 | macOS 15/26 VM | 每批 ≤30 条命令 |
| 10 | `plutil -create xml` 在 Tahoe 26 失效 | Tahoe 26 VM | 用 PlistBuddy |
| 11 | `sysctl -w` IPv6 只读参数（accept_rtadv/forwarding） | macOS 15 实机 | fixCommand 走 `networksetup` |
| 12 | `pmset_not_found` 当 fail 处理 | macOS 15/26 VM | 必须标 info/skip |
| 13 | Swift `\(key)` 插值未展开，生成伪条目 | macOS 26 VM | 硬编码所有变量 |
| 14 | subprocess ulimit 设置丢失 | macOS 15 VM | 直接在当前 shell 设 |
| 15 | `.app` bundle 资源路径错误（MacOS/ → Resources/） | macOS 15 实机 | 验证自包含性：`cp /tmp/ && run` |
| 16 | CPU arch 纯硬件项标 FAIL | macOS 15 实机 | `expected` 必须为 nil |
| 17 | 浮点 defaults 无法还原 | macOS 15 实机 | 先读后存再还原 |
| 18 | debug 编译 bundle accessor 有 hardcoded 绝对路径 fallback | macOS 15 实机 | 必须用 release 或 `cp /tmp/` 验证 |
| 19 | 测试脚本 `grep -c ... || echo 0` 双行输出 | macOS 15 实机 | 用 `result=$(cmd); echo "${result:-0}"` |
| 20 | `sudo` stdout 间歇性丢失（background+wait+kill 模式） | macOS 26 VM | 改用 expect 或 sshpass |
| 21 | Safari plist 键全新安装不存在 | Tahoe 26 VM | "not set" 处理 |
| 22 | `com.apple.Siri` / `com.apple.photoanalysisd` 域在 Tahoe 26 不存在（VM） | Tahoe 26 VM | 物理机首次验证是否真实存在 |
| 23 | `swift --version` 冷启动超时 | macOS 15 VM | 5s per-check timeout |
| 24 | `kern.ipc.maxsockbuf` arm64 硬限 6291456 | macOS 15/26 全 | x86_64 expected=16777216 |
| 25 | JSON 提取 `\(key)` Swift 插值伪条目 | macOS 26 VM | 提取时手动展开 |
| 26 | SIGINT 不终止 MacAudit（trap 或忽略） | Tahoe 26 VM | 仅 SIGTERM 优雅退出 |

---

## Phase 0: 环境基线（~10 min）

**目的**: 确认 SSH 稳定、系统信息采集完成、二进制部署成功

### 0.1-0.5 系统信息（已完成 ✅）

已采集数据：

| 项目 | 值 |
|------|-----|
| macOS | 26.4.1 (Build 25E253) |
| Kernel | Darwin 25.4.0, xnu-12377.101.15 |
| 架构 | x86_64（Intel MacBook Pro） |
| CPU | 16 核 |
| 内存 | 16 GB |
| 主机名 | <test-hostname> |
| 网络 | Wi-Fi (en0) + USB LAN (en6) + Thunderbolt Bridge |
| 防火墙 | 已启用，允许已签名软件（`--getallowsigned` 正常） |
| SIP | enabled |
| FileVault | Off |
| Gatekeeper | assessments enabled |
| Dark Mode | 已开启 |
| pmset | sleep=10, hibernatemode=0, womp=1, powernap=0 |

### 0.6 部署二进制

```bash
# 绕过 Surge 代理
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY CLAUDE_CODE_PROXY_RESOLVES_HOSTS

# SCP 产物到测试机
scp -o StrictHostKeyChecking=no debug/MacAuditApp-v0.1.5.app <testuser>@<test-ip>:/tmp/ 2>/dev/null || true
scp -o StrictHostKeyChecking=no debug/MacAudit-v0-1-5 <testuser>@<test-ip>:/tmp/MacAudit
scp -o StrictHostKeyChecking=no debug/MacAudit_MacAuditUI.bundle <testuser>@<test-ip>:/tmp/
```

### 0.7 权限设置

```bash
ssh <testuser>@<test-ip> 'xattr -dr com.apple.quarantine /tmp/MacAuditApp-v0.1.5.app 2>/dev/null; chmod +x /tmp/MacAudit'
```

### 0.8 Self-Test

```bash
ssh <testuser>@<test-ip> '/tmp/MacAudit --self-test'
```

**通过标准**: 4/4 passed（MacOSVersion / DeviceType / ShellExecutor / readSysctl）

### 0.9 系统日志监控准备

```bash
ssh <testuser>@<test-ip> 'log show --predicate "processImagePath CONTAINS \"MacAudit\"" --last 1m --info 2>/dev/null | tail -5'
```

**Phase 0 通过标准**: SSH 稳定、二进制部署成功、self-test 4/4 pass、无系统日志异常

---

## Phase 1: TUI 全量审查 × 3 轮一致性（~30 min）

**目的**: 在真机上跑 MacAudit 二进制，确认 ~400 检测项 × 3 轮输出完全一致  
**批次大小**: 每轮 1 条命令（JSON 全量输出）

### 1A: 首轮全量 JSON 审查

```bash
/tmp/MacAudit --json --no-color > /tmp/ma_r1.json 2>/tmp/ma_r1_stderr.log
```

**验证项**:
- [ ] JSON 完整可解析（`python3 -c "import json; json.load(open('/tmp/ma_r1.json'))"`）
- [ ] stderr 为空或仅有无害 warning
- [ ] 总检测项数记录（预期 ~400，Intel Tahoe 26 应去掉 arm64 专属项）
- [ ] `error` 数 = 0
- [ ] 无 `timedOut` 项
- [ ] 执行时间 < 10 秒
- [ ] `summary` 字段各状态计数合理

### 1B: 第二轮

```bash
/tmp/MacAudit --json --no-color > /tmp/ma_r2.json 2>/tmp/ma_r2_stderr.log
```

### 1C: 第三轮

```bash
/tmp/MacAudit --json --no-color > /tmp/ma_r3.json 2>/tmp/ma_r3_stderr.log
```

### 1D: 三轮一致性比对

```bash
python3 << 'PYEOF'
import json
def load(p):
    with open(p) as f:
        d = json.load(f)
    return {r['checkId']: (r['status'], r.get('actualValue','')) for r in d['results']}

r1, r2, r3 = load('/tmp/ma_r1.json'), load('/tmp/ma_r2.json'), load('/tmp/ma_r3.json')
ids = sorted(set(r1) | set(r2) | set(r3))
diffs = []
for i in ids:
    v1, v2, v3 = r1.get(i), r2.get(i), r3.get(i)
    if v1 != v2 or v2 != v3:
        diffs.append((i, v1, v2, v3))
print(f"Total: {len(ids)} checks, Inconsistent: {len(diffs)}")
for i, a, b, c in diffs[:50]:
    print(f"  {i}: R1={a} R2={b} R3={c}")
PYEOF
```

### 1E: 首轮详细分析

```bash
python3 << 'PYEOF'
import json
with open('/tmp/ma_r1.json') as f:
    d = json.load(f)
s = d['summary']
print(f"Version: {d.get('version','?')}")
print(f"Total: {s['total']}  Pass: {s['pass']}  Fail: {s['fail']}")
print(f"Warn: {s['warn']}  Info: {s['info']}  Skip: {s['skip']}  Error: {s.get('error',0)}")

# 按 module 分组统计
from collections import Counter
mod = Counter()
for r in d['results']:
    mod[f"{r['moduleId']}:{r['status']}"] += 1
for k in sorted(mod.keys()):
    print(f"  {k}: {mod[k]}")

# 列出所有 fail/error
print("\n--- FAIL items ---")
for r in d['results']:
    if r['status'] == 'fail':
        print(f"  {r['checkId']}: actual={r.get('actualValue','?')} expected={r.get('expectedValue','?')}")
print("\n--- ERROR items ---")
for r in d['results']:
    if r['status'] == 'error':
        print(f"  {r['checkId']}: {r.get('message','?')}")
PYEOF
```

**Phase 1 通过标准**: 0 不一致项、error = 0、stderr = 空、执行时间 < 10s

---

## Phase 2: 逐模块精确验证（~60 min，12 批次）

**目的**: SSH 逐条执行每个模块的 detection command，手动对比 MacAudit JSON 输出  
**批次大小**: 每批 ≤30 条命令  
**方法**: 先从 Phase 1 JSON 提取每个 checkId 的 actualValue，再 SSH 执行对应命令逐条比对

### 批次 2.1: system_info (12 checks)

| 检查项 | 手动验证命令 | 预期 |
|--------|-------------|------|
| m1.macos_version | `sw_vers -productVersion` | `26.4.1` |
| m1.hardware_model | `sysctl -n hw.model` | `Intel-Test-Machine` |
| m1.software_info | `uname -r` | `25.4.0` |
| m1.cpu_arch | `uname -m` | `x86_64` |
| m1.memory | `echo "$(( $(sysctl -n hw.memsize) / 1073741824 )) GB"` | `16 GB` |
| m1.disk_space | `df -h / \| tail -1 \| awk '{print $4}'` | 实际可用空间 |
| m1.hostname | `hostname` | `<test-hostname>` |
| m1.username | `whoami` | `<testuser>` |
| m1.uptime | `uptime \| sed 's/.*up //' \| sed 's/,.*//'` | 实际值 |
| m1.memory_pressure | `sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null \|\| echo 0` | 0-4 |
| m1.apfs_snapshots | `tmutil listlocalsnapshots / 2>/dev/null \| wc -l \| tr -d ' '` | 数字 |
| m1.login_items | `ls ~/Library/LaunchAgents/ 2>/dev/null \| wc -l \| tr -d ' '` | 数字 |

**验证**: 手动命令输出 === JSON actualValue

### 批次 2.2: network_security — Security 机制 (15 checks)

**高危翻车点**（必须逐条手动验证）:

- [ ] `m2.sip`: `csrutil status 2>/dev/null | grep -o 'enabled\|disabled'` → 应输出 `enabled`
- [ ] `m2.gatekeeper`: `spctl --status 2>/dev/null | head -1` → 应输出 `assessments enabled`
- [ ] `m2.firewall`: `socketfilterfw --getglobalstate | grep -oiE 'enabled|disabled'` → 已确认 `enabled`
- [ ] `m2.stealth`: `socketfilterfw --getstealthmode | awk ...` → ⚠️ 历史返回 "is on"，MacAudit 必须转为 `enabled`
- [ ] `m2.allowsigned`: `socketfilterfw --getallowsigned | grep -oiE 'ENABLED|DISABLED'` → 已确认正常
- [ ] `m2.lock_password`: `defaults read com.apple.screensaver askForPassword` → **Tahoe 关键**：返回 `1` 还是 `true`？
- [ ] `m2.lock_delay`: `defaults read com.apple.screensaver askForPasswordDelay` → 预期 `0`
- [ ] `m2.autologin`: `defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo 'disabled'`
- [ ] `m2.filevault`: `fdesetup status | head -1` → 已知 `FileVault is Off.` → 应为 info 非 fail
- [ ] `m2.filevault_key`: `fdesetup haspersonalrecoverykey | grep -o 'true\|false'`
- [ ] `m2.xprotect`: PlistBuddy 读 XProtect.meta.plist Version

### 批次 2.3: network_security — Network (12 checks)

- [ ] `m3.remote_login`: `launchctl print-disabled system/ | grep sshd | grep -o 'enabled\|disabled'` → 输出格式验证
- [ ] `m3.remote_events`: 同上 `eppc`
- [ ] `m3.airplay`: `lsof -nP -iTCP:5000 -sTCP:LISTEN | grep -c ControlCe` → 预期单行输出
- [ ] `m3.smb`: `sharing -l 2>/dev/null | grep -c 'name:'` → 预期单行
- [ ] `m3.wifi_ipv6`: ⚠️ **物理机关键测试** — VM 没有 Wi-Fi，物理机首次验证 `networksetup -getinfo 'Wi-Fi'`
- [ ] `m3.wifi_proxy`: `networksetup -getwebproxy 'Wi-Fi'` → 物理机首次验证
- [ ] `m3.ipv6`: `ifconfig | grep inet6 | grep -v 'fe80\|::1\|%lo' | wc -l` → 预期 `0`
- [ ] `m3.surge_dns`: scutil grep 198.18.0.2 — 物理机可能没 Surge
- [ ] `m3.listening_ports` / `m3.interfaces` / `m3.dns`

### 批次 2.4: network_security — Sysctl 调优 (17 checks)

**重点**:
- [ ] `m8.kern_ipc_maxsockbuf`: `sysctl -n kern.ipc.maxsockbuf` → Intel x86_64 expected `16777216`
- [ ] `sysctl -n kern.ipc.maxsockbuf=16777216` 是否可写（`sudo sysctl -w` 验证，不实际执行）
- [ ] 每条 `sysctl -n` 实际输出 vs JSON actualValue
- [ ] `m8.sysctl_plist`: `/Library/LaunchDaemons/com.server.sysctl.plist` 存在性
- [ ] `net.inet6.ip6.accept_rtadv` / `forwarding`: 读 sysctl 确认值

### 批次 2.5: privacy (17 checks)

**Tahoe 26 关键测试（物理机首次）**:
- [ ] `m4.siri_menu`: `defaults read com.apple.Siri StatusMenuVisible` — **VM 域不存在，物理机可能存在**
- [ ] `m4.photo_analysis`: `defaults read com.apple.photoanalysisd enabled` — 同上
- [ ] `m4.mdns`: macOS 15+ 用 `launchctl print system/com.apple.mDNSResponder` 而非 plist
- [ ] `m4.siri_enabled` / `m4.siri_sharing`: `com.apple.assistant.support` 域存在性
- [ ] 所有布尔项（`-bool false`）的 `defaults read` 返回格式 → **Tahoe 核心验证点**

### 批次 2.6: animation (43 checks)

- [ ] `m5.reduceBlurring`（Tahoe-only）: `defaults read com.apple.universalaccess reduceBlurring` — 存在否？
- [ ] `m5.EnableStandardClickToShowDesktop`（Tahoe-only）: WindowManager 域
- [ ] `m5.reducemotion` / `m5.reducetransparency`: TCC 保护 → fixCommand 为空、expected 有值
- [ ] 所有 `defaults read -g` 布尔项 → 返回 `1`/`0` 还是 `true`/`false`？
- [ ] Dock 设置项: `autohide-delay` / `autohide-time-modifier` / `launchanim` 等

### 批次 2.7: services (57 checks)

**首次在真机完整测试（VM 跳过，历史最大覆盖缺口）**:
- [ ] `launchctl print-disabled gui/$(id -u)` 完整输出 → 解析 `key => value` 对
- [ ] 57 个服务状态是否真实（不是 VM 的 "not managed"）
- [ ] 6 个 Apple Intelligence 服务（`intelligenceflowd` 等 arm64 only）→ Intel 上**不应出现**
- [ ] 22 个 Siri/AI 服务状态
- [ ] 16 个 Telemetry/Analytics 服务状态
- [ ] 7 个 Sharing/Handoff 服务状态
- [ ] fixCommand `launchctl disable gui/$(id -u)/<name> && launchctl bootout gui/$(id -u)/<name> 2>/dev/null; true` 语法验证

### 批次 2.8: power (19-28 checks)

**物理机独有测试点（VM 完全无法覆盖，最大新增价值）**:
- [ ] `m7.batt_sleep` / `batt_disksleep` / `batt_displaysleep` / `batt_standby` / `batt_powernap`: **电池域设置首次可测**
- [ ] `m7.womp`: Wake on LAN → 物理机有真实网卡，预期 `1`
- [ ] `m7.lidwake`: 合盖唤醒 → 物理机有 lid 传感器
- [ ] `m7.hibernatemode`: laptop 预期 `0`（当前 pmset 输出已确认）
- [ ] `m7.ac_lowpowermode`: 物理机应能读取，预期 `0`
- [ ] `m7.autorestart`: laptop-only → 预期不出现（仅 desktop）
- [ ] `m7.amphetamine`: 进程检测 → 已确认 Amphetamine 在运行
- [ ] `pmset -g` 所有键都有值 → **不再出现 `pmset_not_found`**
- [ ] `m7.maxfiles` / `m7.memory_pressure` / `m7.server_mode`

### 批次 2.9: shell (18-19 checks)

- [ ] `m9.ulimit_n`: `ulimit -n` 物理机实际值（VM 可能 256，物理机可能不同）
- [ ] `m9.ulimit_u`: `ulimit -u` 物理机实际值（VM 硬限 2000，物理机可能 2048+）
- [ ] `m9.default_shell`: `echo $SHELL` → 预期 `/bin/zsh`
- [ ] `m9.dangerous_alias`: `grep -c 'dangerously' ~/.zshrc ~/.zprofile`
- [ ] `m9.zsh_history_cjk`: python3 检测 CJK 字符
- [ ] `m9.brew_analytics` / `m9.git_name` / `m9.git_email` / `m9.ssh_config`

### 批次 2.10: claude (45+ checks)

**覆盖大量 macOS 安全 + Claude 环境检查**:
- [ ] `m10.fw_signed`: 用 `--getallowsigned`（Tahoe 关键验证）
- [ ] `m10.fw_stealth`: stealth mode 输出格式（历史翻车点）
- [ ] `m10.env_*`: 环境变量检测（CLAUDE_CODE_DISABLE_* / DISABLE_TELEMETRY 等）
- [ ] `m10.surge_dns/tun/dashboard`: 如果没有 Surge → 应为 info
- [ ] `m10.lulu` / `m10.knockknock`: 第三方安全工具检测 → 预期 skip/info
- [ ] `m10.claude_version` / `m10.claude_improve`: Claude CLI 检测
- [ ] `m10.ipv6_global` / `m10.wifi_ipv6` / `m10.ipv6_rtadv` / `m10.ipv6_fwd`: IPv6 全链路
- [ ] `m10.proxy_https` / `m10.all_proxy_on_func` / `m10.all_proxy_off_func`: 代理检测
- [ ] `m10.device_id` / `m10.git_email_leak` / `m10.npm_registry`: 身份/泄漏检测

### 批次 2.11: dev (55-67 checks)

**并行检查、5s per-check 超时**:
- [ ] `m11.xcode_clt`: `xcode-select -p` 是否存在
- [ ] `m11.brew`: 物理机是否有 brew → 预期可能没有
- [ ] `m11.ollama_metal`: arm64 only → Intel **不应出现**
- [ ] `m11.mlx`: Tahoe + arm64 only → Intel **不应出现**
- [ ] `m11.swift`: `swift --version` 冷启动是否超时（历史 VM 超时问题）
- [ ] 总执行时间实测（预期 30-60s）
- [ ] 检查所有 skip 项是否合理（没装的工具 = skip，不是 fail）

### 批次 2.12: ip_quality + chrome + safari (49 checks)

**IP 质量 (22 checks)**:
- [ ] `m13.*`: 全部 22 项执行（需要外网），实测耗时
- [ ] Phase A (local): public_ip / dns / gateway / whois
- [ ] Phase B (API): geo / asn / is_proxy / is_vpn / is_tor / is_datacenter
- [ ] Phase C (DNSBL): dnsbl_summary
- [ ] Phase D (Mail): smtp_port25 / smtp_port587
- [ ] 网络预检查: `curl -s --max-time 6 ifconfig.me` 必须通过

**Chrome (14 checks)**:
- [ ] `m14.installed`: Chrome 是否安装 → 决定后续 13 项是执行还是 skip
- [ ] 如果安装: 全部 14 项 + PlistBuddy fixCommand 验证
- [ ] 如果未安装: 全部 skip，确认 skip 逻辑正确

**Safari (13-14 checks)**:
- [ ] `m15.enhanced_regular`: Tahoe-only 新特性
- [ ] Safari plist 键在物理机上是否完整存在（VM 首次启动不存在）
- [ ] `m15.popup_block` / `m15.autofill_address` / `m15.autofill_cc` 等默认值
- [ ] `m15.private_relay`: info-only

---

## Phase 3: fixCommand 逐条验证（~90 min，10 批次）

**历史从未在 Tahoe 真机完整测试过 fixCommand — 这是本次最大价值**

### 安全分区策略

| 级别 | 定义 | 处理方式 |
|------|------|----------|
| **safe** | risk ≤ low, no sudo | 直接执行 → 验证 → 还原 |
| **medium** | no sudo, no network risk | 逐条确认 → 执行 → 验证 → 还原 |
| **high** | requires sudo | 仅验证命令语法 + `which` 确认工具存在，**不实际执行** |
| **critical** | network risk | 仅输出命令 + 预期效果，记录为"待用户确认" |

### 每条 fixCommand 执行流程（safe/medium 级）

```
1. 读当前值:  defaults read <domain> <key>
2. 执行 fixCommand
3. 读新值:    defaults read <domain> <key>
4. 对比 expectedValue
5. 还原:      defaults write <domain> <key> <原值类型> <原值>
              (布尔: -bool true/false, 整数: -int N, 字符串: -string X)
6. 确认还原:  defaults read <domain> <key> === 原值
```

### 3A: safe 级 fixCommand（~40 条，分 3 批每批 15 条）

涵盖所有 `defaults write` + `fixRiskLevel ≤ low` + `requiresSudo = false` 的修复命令：

**批次 3A-1: Privacy + Animation defaults write（~15 条）**
- `m4.diagnostics`: `defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false`
- `m4.crash_reporter`: `defaults write com.apple.CrashReporter DialogType -string none`
- `m4.siri_enabled`: `defaults write com.apple.assistant.support 'Assistant Enabled' -bool false`
- `m4.ad_tracking`: `defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false`
- `m4.usage_tracking`: `defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false`
- `m4.ds_network`: `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true`
- `m4.ds_usb`: `defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true`
- `m4.airdrop`: `defaults write com.apple.NetworkBrowser DisableAirDrop -bool true`
- `m4.safari_search`: `defaults write com.apple.Safari UniversalSearchEnabled -bool false`
- `m4.safari_suggest`: `defaults write com.apple.Safari SuppressSearchSuggestions -bool true`
- `m4.spotlight_suggest`: `defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true`
- `m2.lock_password`: `defaults write com.apple.screensaver askForPassword -bool true`
- `m2.lock_delay`: `defaults write com.apple.screensaver askForPasswordDelay -int 0`
- 以及其他 safe 级 defaults write

**Tahoe 26 关键验证**: 每条 `defaults write -bool false` 后 `defaults read` 返回值 → 确认 MacAudit 比对逻辑兼容

**批次 3A-2: Animation defaults write（~15 条）**
- 全局动画: `NSAutomaticWindowAnimationsEnabled` / `NSWindowResizeTime` 等
- Dock: `autohide-delay` / `autohide-time-modifier` / `launchanim`
- Finder: 各种 animation duration
- 键盘: `KeyRepeat` / `InitialKeyRepeat`
- 注意浮点还原: `expose-animation-duration` 需 `defaults write -float`

**批次 3A-3: Shell + Safari defaults write（~10 条）**
- `m9.brew_analytics`: `echo 'export HOMEBREW_NO_ANALYTICS=1' >> ~/.zshrc` → 还原: `sed -i '' '/HOMEBREW_NO_ANALYTICS/d' ~/.zshrc`
- `m9.ssh_config` / `m9.ssh_controlmaster`: 写入 ~/.ssh/config → 还原
- Safari: `m15.search_universal` / `m15.search_suggest` / `m15.preload` 等
- `m15.enhanced_regular`（Tahoe-only）

### 3B: medium 级 fixCommand（~20 条，分 2 批）

**批次 3B-1: 网络相关 no-sudo（~10 条）**
- `m8.net_inet_tcp_blackhole`: `sudo sysctl -w net.inet.tcp.blackhole=2` → 实际需 sudo，仅验证语法
- `m3.wifi_ipv6` / `m3.ipv6`: `sudo networksetup -setv6off 'Wi-Fi'` → 仅验证语法
- 其他 medium 级网络 fixCommand

**批次 3B-2: 非网络 medium 级（~10 条）**
- `m9.dangerous_alias`: `sed -i '' '/dangerously/d' ~/.zshrc ~/.zprofile` → 需先有危险别名才能测
- `m9.zsh_history_cjk`: 清理 CJK 字符
- Chrome PlistBuddy 命令（如果 Chrome 已安装）

### 3C: high 级 fixCommand — 仅输出验证（~50 条）

**不实际执行 sudo 命令，只验证命令语法正确性和工具可用性**：

验证方式:
```bash
# 确认工具存在
which sysctl pmset socketfilterfw spctl networksetup launchctl PlistBuddy

# 确认命令参数有效（dry-run 或 --help）
sysctl -a 2>/dev/null | head -1     # sysctl 可用
pmset -g                             # pmset 可用
socketfilterfw --help 2>&1 | head -5 # socketfilterfw 可用
```

覆盖项:
- sudo sysctl 系列（15 条）: `sudo sysctl -w kern.ipc.maxsockbuf=16777216` 等
- sudo pmset 系列（~11 条）: `sudo pmset -c sleep 0` 等
- sudo spctl / socketfilterfw（~5 条）
- sudo networksetup（~3 条）
- sudo launchctl disable/bootout（~57 条，仅验证语法模板）
- sudo defaults write /Library/（~3 条）
- sudo PlistBuddy Chrome（~10 条，如果 Chrome 存在）

### 3D: --fix 交互模式端到端

```bash
/tmp/MacAudit --fix --no-color
```

验证:
- [ ] fix plan 正确分级显示（safe / low / medium / high / critical 五档）
- [ ] safe actions 列表准确
- [ ] 交互提示 `Apply? [y/N]` 正常
- [ ] 执行后结果更新
- [ ] `~/.macaudit/history.json` 记录生成
- [ ] FixBatch ID 格式 `fix_yyyyMMdd_HHmmss`

### 3E: --undo 回滚验证

```bash
/tmp/MacAudit --undo --no-color
```

验证:
- [ ] 读取上次 FixBatch
- [ ] undo 命令正确生成（`defaults delete` 或 `defaults write` 还原原值）
- [ ] 执行后状态还原
- [ ] `previousValue` 不为空（历史 bug: 空 → 错误生成 `defaults delete`）
- [ ] `~/.macaudit/rollback_<batchId>.sh` 脚本生成
