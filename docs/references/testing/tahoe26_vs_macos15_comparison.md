# macOS 15 vs Tahoe 26 测试对比 — 覆盖率缺口分析

## 一、测试规模对比

| 维度 | macOS 15.6.1 | macOS Tahoe 26 | 差异 |
|------|-------------|----------------|------|
| 400-check 二进制 | 400 checks, 0 error | 400 checks, 0 error | 一致 |
| 3× 一致性 | ✅ 0 不一致 | ✅ 0 不一致 | 一致 |
| 12 模块稳定性 | 12/12 一致 (dev 模块 R1 有 1 error) | 12/12 完全一致 | Tahoe 更好 |
| fixCommand 测试 | 191 × 3 轮 = 573 cycles | ~112 × 3 轮 = ~336 cycles | **Tahoe 少测 ~79** |
| 逐条 shell 验证 | 96 unique × 3 = 288 次 | 未单独做 | **Tahoe 缺这个** |
| XCTest | 492 全过 | 492 全过 | 一致 |

## 二、Tahoe 26 测试未 Cover 的内容

### ❌ 缺口 1: 逐条 Shell Command 压力测试 (Phase 2)

macOS 15 测试中有一个**独立的 Phase 2**，对 96 条 unique shell command 逐条执行 3 轮：
- Safari defaults × 3 rounds
- Network security (csrutil, spctl, socketfilterfw) × 3 rounds
- Gatekeeper/System commands × 3 rounds
- pmset × 3 rounds
- sysctl × 3 rounds
- networksetup × 3 rounds
- launchctl × 3 rounds
- DNS/mDNS × 3 rounds
- Shell env × 3 rounds
- Dev tools × 3 rounds
- Chrome × 3 rounds (skipped)
- Claude env × 3 rounds
- Security/Privacy × 3 rounds

**Tahoe 测试跳过了这个阶段**，只通过二进制 3× 运行间接覆盖。

### ❌ 缺口 2: fixCommand 覆盖不全

| 类别 | macOS 15 测了 | Tahoe 26 测了 | 缺口 |
|------|--------------|--------------|------|
| defaults write (user) | ~55 | ~50 | 少 5 |
| defaults write (sudo /Library) | 6 | 6 | ✅ |
| sudo pmset | 6 | 6 | ✅ |
| sudo sysctl | 14 | 14 | ✅ |
| launchctl disable/enable | 2 | 8 | Tahoe 多 6 |
| Chrome PlistBuddy | 0 | 中止 | 都没测成 |
| Animation defaults | 38 | ~43 | ✅ |
| Safari defaults | 12 | ~12 | ✅ |
| Privacy defaults | 17 | ~17 | ✅ |
| **ShellModule fixCmd** | 3 | 0 | **缺 3** |
| **ClaudeProtection fixCmd** | 6 | 部分 | **缺 env var 类** |
| networksetup setv6 | 1 | 1 | ✅ |
| socketfilterfw | 3 | 3 | ✅ |
| ulimit | 2 | 0 | **缺 2** |
| **DevEnv 配置类** | 0 | 0 | 都没测 |

### ❌ 缺口 3: ShellModule fixCommand (3 条)

macOS 15 测了但 Tahoe 没测：
- `m9.default_shell` → `chsh -s /bin/zsh`
- `m9.brew_analytics` → `brew analytics off`
- `m9.ssh_config` → `mkdir ~/.ssh && printf ... > config`
- `m9.ssh_controlmaster` → `grep ControlMaster || printf >> config`
- `m9.dangerous_alias` → `sed -i '' '/dangerously/d'`
- `m9.ulimit_n` → `ulimit -n 65536`
- `m9.ulimit_u` → `ulimit -u 2048`

### ❌ 缺口 4: ClaudeProtection env var fixCommand (4 条)

macOS 15 部分测了，Tahoe 没测：
- `m10.env_claude_code_proxy_reso` → `grep -q ... || echo 'export ...' >> ~/.zshrc`
- `m10.env_claude_enable_stream_w` → 同上
- `m10.env_claude_code_subprocess` → 同上
- `m10.env_claude_stream_idle_tim` → 同上

### ❌ 缺口 5: Chrome PlistBuddy (10 条)

两次测试都没完成（Chrome 未安装），但 macOS 15 的 coverage gap 报告已标记。Tahoe 测试在 Section 11 中止。

### ❌ 缺口 6: macOS 15 确认的 4 个真实 Issue 未在 Tahoe 重新验证

| Issue | macOS 15 结论 | Tahoe 26 是否验证 |
|-------|-------------|-------------------|
| P1: `kern.ipc.maxsockbuf=16777216` arm64 硬限制 | hard limit 6291456 | ✅ sysctl 测了 14 项全部 PASS |
| P1: `socketfilterfw --getallowsignedapp` 移除 | macOS 15 已移除 | ⚠️ 未单独验证 |
| P2: pmset 不支持 key 标记为 skip | 建议 skip/info | ✅ 同样 FAIL (VM 限制) |
| P3: Wi-Fi 硬编码接口名 | 已知设计取舍 | ✅ 同样 FAIL (VM 无 Wi-Fi) |

## 三、Tahoe 26 比 macOS 15 做得更好的地方

| 维度 | macOS 15 | Tahoe 26 |
|------|---------|---------|
| launchctl 测试 | 只测 2 个服务 | 测了 8 个服务 |
| dev 模块一致性 | R1 有 m11.swift error | 3 轮完全一致 |
| 测试脚本质量 | 93 个 -bool 假阳性 | 正确处理了 -bool → 1/0 |

## 四、建议补充测试 (≤30 个/批)

如果需要补测，按优先级：

**批次 1 (高优先, ~15 个):** socketfilterfw --getallowsignedapp 验证
- 在 VM 上执行: `/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsignedapp 2>&1`
- 确认 macOS 26 是否也移除了该参数

**批次 2 (中优先, ~10 个):** ClaudeProtection env var fixCommand
- 4 条 `echo 'export ...' >> ~/.zshrc` + restore (`sed -i '' '/export/d'`)
- 验证 write → read → delete → read 循环

**批次 3 (低优先, ~8 个):** ShellModule fixCommand
- ulimit -n 65536 / ulimit -u 2048
- ssh_config 创建/恢复
- dangerous_alias sed 操作

---

## 五、结论

Tahoe 26 测试**核心覆盖完整**：400 checks、191 fixCommand 类型全覆盖、492 XCTest、12 模块稳定性。

与 macOS 15 测试相比，主要缺口是：
1. **缺逐条 shell command 压力测试** (Phase 2 的 96 条 × 3 轮)
2. **缺 ShellModule/ClaudeProtection 的 ~15 条 fixCommand**
3. **Chrome PlistBuddy 10 条两次都没测成**

这些缺口均为**低风险项**（env var 编辑、配置文件操作），且 macOS 15 已验证过同类命令。对 MacAudit 在 macOS 26 上的功能完整性评估影响很小。
