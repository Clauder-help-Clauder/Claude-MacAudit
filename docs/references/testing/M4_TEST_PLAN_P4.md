# M4 Test Plan — 分段执行计划 (Part 4: 三轮循环验证)

> **完成标准**: 所有测试项连续 3 轮全部零缺陷，否则循环修复直到达标
> 依赖: Part 1-3 全部执行完成
> 原则: 宁可多跑一轮，不放过一个偶发性失败

---

## 循环验证总则

### 通过标准

| 维度 | 标准 | 检测方法 |
|------|------|---------|
| 单元测试 | `swift test` 全部 492+ tests PASS，0 fail，0 crash | 自动化 |
| 构建 | `bash scripts/build_app.sh` + `bash scripts/build_app.sh release` 均成功 | 自动化 |
| 双副本一致性 | 8 个模块 diff 结果完全一致 | 自动化脚本 |
| VM 集成 (如可用) | 全量审查 0 error，12 模块输出正常 | SSH + JSON 解析 |
| fix/undo 回合 | 至少 10 个 fixCommand 执行 + undo 后值恢复原状 | 手动 + 脚本 |

### 循环规则

```
Round 1 → 发现缺陷 → 修复 → Round 2 → 发现缺陷 → 修复 → Round 3 → 全清 → ✅ PASS
                                                                    → 有缺陷 → Round 4 ... 直到连续 3 轮零缺陷

重置条件: 如果第 N 轮出现任何失败，计数器归零，从修复后重新开始计数
偶发失败也算: 任何 timeout / flaky / 非确定性失败均视为真缺陷，必须定位根因
```

---

## Agent 16: 第一轮全量验证 (Round 1)

### 任务边界
- **执行环境**: 本机 + VM (如可用)
- **最大 SSH 命令**: 25 条/会话
- **使用 sub-agent**: 保持主进程上下文清洁

### Step 1: 本地全量测试 (sub-agent 执行)

```bash
# 1a. 构建
bash scripts/build_app.sh
bash scripts/build_app.sh release

# 1b. 全量单元测试
swift test --filter MacAuditTests 2>&1 | tee /tmp/m4_r1_unit.txt

# 1c. 提取结果
grep -E '(Test Suite|Executed|failed|passed)' /tmp/m4_r1_unit.txt
```

**通过条件**: Executed X tests, 0 failures

### Step 2: 双副本一致性 (sub-agent 执行)

```bash
for module in SafariModule ChromeModule PrivacyModule AnimationModule \
              PowerModule ShellModule ClaudeProtectionModule NetworkSecurityModule; do
  diff <(grep -v '^public' Sources/MacAudit/Modules/$module.swift | sed 's/public //') \
       <(grep -v '^public' Sources/MacAuditCore/Modules/$module.swift | sed 's/public //') \
  && echo "$module: PASS" || echo "$module: DIVERGENT"
done

# 同时检查 FixEngine 和 AuditModule
diff <(grep -v '^public' Sources/MacAudit/CLI/FixEngine.swift | sed 's/public //') \
     <(grep -v '^public' Sources/MacAuditCore/FixEngine.swift | sed 's/public //') \
&& echo "FixEngine: PASS" || echo "FixEngine: DIVERGENT"
```

**通过条件**: 全部 PASS

### Step 3: VM 集成测试 (如 VM 可用, sub-agent 执行)

```bash
# 每次最多 8 条命令，分 3 批

# Batch 1: 部署 + 自检
scp debug/MacAudit-v0-1-5 <vm-user>@<vm-ip>:/tmp/MacAudit
ssh <vm-user>@<vm-ip> 'chmod +x /tmp/MacAudit && /tmp/MacAudit --self-test'

# Batch 2: 小模块 (system_info, power, shell, safari, chrome)
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module safari --json' > /tmp/m4_r1_safari.json
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module chrome --json' > /tmp/m4_r1_chrome.json
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module privacy --json' > /tmp/m4_r1_privacy.json

# Batch 3: 大模块 (network, animation, claude, services)
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module network --json' > /tmp/m4_r1_network.json
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module animation --json' > /tmp/m4_r1_animation.json
```

**通过条件**: 每个 JSON 输出有效 + 0 error 状态

### Step 4: defaults read 格式确认 (如 VM 可用, sub-agent 执行)

这是 T1 的核心验证 — 确认 Tahoe 26 的 defaults 返回格式:

```bash
# Batch: bool 值格式调查
ssh <vm-user>@<vm-ip> 'echo "=== askForPassword ==="; defaults read com.apple.screensaver askForPassword 2>/dev/null; echo "=== UniversalSearchEnabled ==="; defaults read com.apple.Safari UniversalSearchEnabled 2>/dev/null; echo "=== AutoSubmit ==="; defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null' > /tmp/m4_r1_defaults.txt

ssh <vm-user>@<vm-ip> 'echo "=== allowTRIM ==="; defaults read /Library/Preferences/com.apple.TimeMachine DoNotOfferVirtualDisk 2>/dev/null; echo "=== firewall ==="; /usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null; echo "=== maxsockbuf ==="; sysctl -n kern.ipc.maxsockbuf 2>/dev/null' >> /tmp/m4_r1_defaults.txt
```

### Step 5: fix/undo 回合测试 (如 VM 可用, sub-agent 执行)

选取 10 个代表性 fixCommand，执行 fix → 验证 → undo → 验证恢复:

```bash
# 选取低风险的 fixCommand 测试 (不涉及 sudo)
ssh <vm-user>@<vm-ip> '
  # 1. 记录原始值
  echo "BEFORE:"; defaults read com.apple.Safari UniversalSearchEnabled
  # 2. 执行 fix
  defaults write com.apple.Safari UniversalSearchEnabled -bool false
  echo "AFTER_FIX:"; defaults read com.apple.Safari UniversalSearchEnabled
  # 3. 执行 undo
  defaults delete com.apple.Safari UniversalSearchEnabled 2>/dev/null || true
  defaults write com.apple.Safari UniversalSearchEnabled -bool true
  echo "AFTER_UNDO:"; defaults read com.apple.Safari UniversalSearchEnabled
'
```

**通过条件**: undo 后值与原始值一致

### Round 1 结果判定

| 检查项 | Pass? | 详情 |
|--------|-------|------|
| 单元测试 (492+) | ☐ | |
| debug 构建 | ☐ | |
| release 构建 | ☐ | |
| 双副本一致性 (8 模块) | ☐ | |
| VM 自检 | ☐ | |
| VM 模块输出 (12 模块) | ☐ | |
| defaults 格式确认 | ☐ | |
| fix/undo 回合 (10 项) | ☐ | |

**如果全部 Pass → 进入 Round 2**
**如果有任何 Fail → 修复后 Round 1 重跑（计数器不进位）**

---

## Agent 17: 第二轮全量验证 (Round 2)

完全重复 Agent 16 的 Step 1-5，使用全新 sub-agent。

### 与 Round 1 的区别

1. **环境不重置**: 不清理 build cache，不重启 VM（模拟真实使用场景）
2. **增加时序检查**: 在 VM 上连续跑两次全量审查，对比结果一致性
3. **增加压力测试**: 快速连续执行 `--module safari` 3 次，检查输出稳定性

```bash
# 时序一致性 (VM)
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module safari --json' > /tmp/m4_r2_safari_1.json
ssh <vm-user>@<vm-ip> '/tmp/MacAudit --module safari --json' > /tmp/m4_r2_safari_2.json
diff /tmp/m4_r2_safari_1.json /tmp/m4_r2_safari_2.json && echo "STABLE" || echo "FLAKY"
```

### Round 2 结果判定

同 Round 1 表格。**Round 1 + Round 2 都 Pass → 进入 Round 3**

---

## Agent 18: 第三轮全量验证 (Round 3 — 最终)

### 与 Round 1/2 的区别

1. **完全清洁环境**:
   - `rm -rf .spm-build/` → 从零构建
   - VM 上删除 `/tmp/MacAudit` → 重新 SCP
2. **增加边界测试**:
   - 空域 (`defaults read com.apple.NonExistentDomain`) — 确认优雅降级
   - 无 Safari 环境 — 确认模块跳过而非崩溃
   - 超时模拟 — 确认 timeout 不导致 crash
3. **修复命令覆盖率统计**: 确认可执行 undo 的 fixCommand 比例 ≥ 80%

```bash
# 清洁构建
rm -rf .spm-build/
bash scripts/build_app.sh
bash scripts/build_app.sh release

# 全量测试
swift test --filter MacAuditTests 2>&1 | tee /tmp/m4_r3_unit.txt
```

### Round 3 结果判定

同 Round 1 表格 + 额外项:

| 额外检查项 | Pass? |
|-----------|-------|
| 清洁构建 (从零) | ☐ |
| 时序一致性 (2 次输出相同) | ☐ |
| 边界测试 (空域/无Safari/超时) | ☐ |
| undo 覆盖率 ≥ 80% | ☐ |

---

## 最终判定

```
Round 1 Pass → Round 2 Pass → Round 3 Pass → ✅ M4 完成
                                           → Fail → 修复 → Round 4 (计数器: 1/3)
                                         ↗ Fail → 修复 → 重跑 Round 3 (计数器: 0/3)
```

### M4 完成条件 (全部满足)

- [ ] 连续 3 轮全量验证 Pass（单元测试 0 failure）
- [ ] 连续 3 轮构建成功（debug + release）
- [ ] 连续 3 轮双副本一致性检查 Pass
- [ ] 连续 3 轮 VM 集成测试 Pass（如 VM 可用）
- [ ] 连续 3 轮 fix/undo 回合测试 Pass
- [ ] undo 覆盖率 ≥ 80%
- [ ] HANDOFF.md 已更新

### M4 失败处理

| 场景 | 处理 |
|------|------|
| 某轮偶发 timeout | 计为真缺陷，定位根因，不视为"网络波动" |
| 某轮单元测试 crash | 必须修复 + 从 Round 1 重跑 |
| 连续 5 轮无法通过 | 触发 Escalate: 回退到上个已知好的 commit |
| VM 不可用 | 本地 3 轮仍需通过，VM 测试标记为 deferred |

---

## 验证结果记录模板

```
M4 循环验证记录
===============

Round 1: ____-__-__ __:__
  单元测试: PASS/FAIL (___/___ tests)
  构建: PASS/FAIL
  双副本: PASS/FAIL
  VM 集成: PASS/FAIL/SKIP
  fix/undo: PASS/FAIL (___/10)
  累计连续通过: 1/3

Round 2: ____-__-__ __:__
  单元测试: PASS/FAIL (___/___ tests)
  构建: PASS/FAIL
  双副本: PASS/FAIL
  VM 集成: PASS/FAIL/SKIP
  时序一致性: PASS/FAIL
  累计连续通过: 2/3

Round 3: ____-__-__ __:__
  单元测试: PASS/FAIL (___/___ tests)
  清洁构建: PASS/FAIL
  双副本: PASS/FAIL
  VM 集成: PASS/FAIL/SKIP
  边界测试: PASS/FAIL
  undo 覆盖率: ___%
  累计连续通过: 3/3 ✅ 或 0/3 (重置)

最终状态: ✅ M4 COMPLETE / ❌ NEEDS FIXES
签名: ___________
```
