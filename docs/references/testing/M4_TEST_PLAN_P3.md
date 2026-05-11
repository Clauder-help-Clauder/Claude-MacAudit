# M4 Test Plan — 分段执行计划 (Part 3: 模块修复 + 验证)

> 依赖: Part 1 (P0 测试) + Part 2 (核心引擎) 必须全部通过
> 本段逐模块应用 bool 归一化 + 修复双副本分歧

---

## Agent 7: 前置分歧修复 — PrivacyModule + AuditModule

### 任务边界
- **修改文件**: 4 个
  - `Sources/MacAudit/Modules/PrivacyModule.swift` (lines 56-93)
  - `Sources/MacAuditCore/Modules/PrivacyModule.swift` (lines 53-76)
  - `Sources/MacAudit/Models/AuditModule.swift` (pmset sentinel)
  - `Sources/MacAuditCore/Models/AuditModule.swift` (pmset sentinel)
- **最大行数**: ~50 行
- **风险等级**: 中（改变检测行为，需仔细验证）

### PrivacyModule 修复 (U-08)

| Check | MacAudit CLI 当前 | MacAuditCore 当前 | 统一为 |
|-------|------------------|-------------------|--------|
| m4.mdns command | `launchctl print ... \| grep -c 'NoMulticast'` | `defaults read ... NoMulticastAdvertisements` | 使用 `defaults read` 方案（更通用） |
| m4.mdns fixCommand | `sudo killall -HUP mDNSResponder` | `sudo launchctl stop ... && start ...` | 使用 `launchctl stop/start` 方案（更正确） |
| m4.captive command | `defaults read com.apple.captive.control` | `scutil + defaults read CaptiveNetworkSupport` | 统一使用 CLI 版本的路径 |

### AuditModule pmset_not_found 修复 (U-03)

CLI 副本缺少 `pmset_not_found` 哨兵处理，需要同步 Core 的逻辑:
```swift
// 在 runChecks 中添加:
if actual == "pmset_not_found" {
    results.append(AuditResult(check: check, actualValue: actual, status: .info))
    continue
}
```

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter PrivacyModuleTests --filter PowerModuleTests --filter AnimationModuleTests
```

### 提交: `fix(U-03,U-08): unify PrivacyModule dual-copy divergence and pmset sentinel`

---

## Agent 8: ClaudeProtection + NetworkSecurity 分歧修复

### 任务边界
- **修改文件**: 4 个
  - `Sources/MacAudit/Modules/ClaudeProtectionModule.swift`
  - `Sources/MacAuditCore/Modules/ClaudeProtectionModule.swift`
  - `Sources/MacAuditCore/Modules/NetworkSecurityModule.swift` (补充 fixCommand)
- **最大行数**: ~60 行
- **风险等级**: 中

### ClaudeProtectionModule 矛盾修复 (U-09)

| Check ID | 问题 | 修复方向 |
|----------|------|---------|
| m10.env_no_proxy | CLI: `"not set"` vs Core: `"localhost"` | 统一为 `"not set"` (无代理环境) |
| m10.proxy_noproxy_in_func | CLI: `"1"` vs Core: nil (info) | 统一为 info (去掉 expected) |
| m10.sandbox_proxy | CLI 有 fixCommand, Core 无 | Core 补充 fixCommand |
| m10.surge_tun | CLI: `"1"`, Core: nil | 统一为 info |
| m10.ipv6_fwd fixCommand | CLI: `sysctl`, Core: `networksetup` | 统一使用 `sysctl` (更直接) |

### NetworkSecurityModule Core 补 fixCommand (U-10)

检查 Core 版本缺哪些 fixCommand，从 CLI 版本同步:
- m3.remote_login
- m3.remote_events
- m3.smb
- m8.sysctl_plist

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter ClaudeProtectionModuleTests --filter NetworkSecurityModuleTests
```

### 提交: `fix(U-09,U-10): reconcile ClaudeProtection and NetworkSecurity dual-copy divergence`

---

## Agent 9-12: 逐模块应用 bool 归一化

### 执行策略
每个模块一个 Agent，按从小到大顺序执行:

| Agent | 模块 | Checks 数 | 文件数 | 预计时间 |
|-------|------|----------|--------|---------|
| 9 | PowerModule | 1 bool | 2 | 15 min |
| 10 | NetworkSecurityModule | 2 bool | 2 | 20 min |
| 11 | ClaudeProtectionModule | 6 bool | 2 | 25 min |
| 12 | PrivacyModule | 14 bool | 2 | 30 min |

### 每个模块的修改模式

由于 Agent 4 已在比较层添加 `DefaultsNormalizer`，模块级的改动主要是:

1. **command 字符串** (可选优化): 在 inline shell 命令中追加格式归一化管道:
   ```bash
   defaults read DOMAIN KEY 2>/dev/null || echo 'not set'
   # 优化为:
   defaults read DOMAIN KEY 2>/dev/null | head -1 || echo 'not set'
   ```
   注意: `head -1` 防止 Tahoe 多行 dict 输出，但不改变单行值。

2. **expectedValue**: 无需修改（归一化层处理格式差异）

3. **fixCommand**: 无需修改（写入用 `-bool true/false` 在所有 macOS 版本通用）

4. **双副本同步**: 确保两份文件的改动完全一致

### 每个 Agent 的验证门禁

```bash
bash scripts/build_app.sh && \
swift test --filter <Module>Tests && \
git add -A && git commit -m "fix(T1): apply bool normalization to <Module>"
```

### Agent 13: AnimationModule (最大模块)

- **文件数**: 2 个副本
- **Checks 数**: ~45 个
- **预计时间**: 45 min
- **策略**: 分两批处理，每批 ~22 个 check，中间 commit

### Agent 14: SafariModule + ChromeModule

- **文件数**: 4 个（Safari ×2 + Chrome ×2）
- **Checks 数**: Safari 13 + Chrome 14
- **策略**: Safari 已在 Agent 5 拆分了 popup_block，此处应用归一化到所有 check
- Chrome 的 fixCommand 全用 PlistBuddy，无需 defaults 归一化，但检测命令可能需要 `head -1`

---

## 最终验证 (All Agents 完成后)

### Agent 15: 全量验证

```bash
# 1. 全量构建
bash scripts/build_app.sh

# 2. 全量测试 (仅本地，不在 VM)
swift test --filter MacAuditTests

# 3. 双副本一致性检查 (用 diff)
for module in SafariModule ChromeModule PrivacyModule AnimationModule PowerModule ShellModule ClaudeProtectionModule NetworkSecurityModule; do
  diff <(grep -v '^public' Sources/MacAudit/Modules/$module.swift | sed 's/public //') \
       <(grep -v '^public' Sources/MacAuditCore/Modules/$module.swift | sed 's/public //') \
  && echo "$module: PASS" || echo "$module: DIVERGENT"
done

# 4. Release 构建
bash scripts/build_app.sh release
```

### VM 集成测试 (Sub-Agent)

如果 Tahoe VM 可用:
```bash
# 由独立 sub-agent 执行，保持主进程上下文清洁
scp debug/MacAudit-v0-1-5 <vm-user>@<vm-ip>:/tmp/
ssh <vm-user>@<vm-ip> '/tmp/MacAudit-v0-1-5 --module safari --json' > safari_result.json
ssh <vm-user>@<vm-ip> '/tmp/MacAudit-v0-1-5 --module privacy --json' > privacy_result.json
# 每次最多 25 条命令
```

### HANDOFF 更新

完成后更新 HANDOFF.md:
- Current State: 标记 T1/T4 完成
- Dev Log: 追加 M4 完成记录
- Known Gotchas: 更新 Gotcha #1 #2 状态为已解决
- Milestones: M4 标记为 100%

---

## 完整依赖图

```
Phase 0 (Part 1):
  Agent 1 (Safari+Chrome tests) ─┐
  Agent 2 (FixEngine tests) ─────┤
                                  ▼
Phase 1 (Part 2):
  Agent 3 (FixEngine fix) ───────┬──▶ Agent 5 (Safari popup) ──┐
  Agent 4 (DefaultsNormalizer) ──┤    Agent 6 (Chrome verify) ─┤
                                  │                              │
Phase 2 (Part 3):                 │                              │
  Agent 7 (Privacy+pmset) ───────┤                              │
  Agent 8 (Claude+Network) ──────┤                              ▼
  Agent 9-12 (small modules) ────┼──▶ Agent 13 (Animation) ──▶ Agent 15 (Full validation)
  Agent 14 (Safari+Chrome) ──────┘
```

## Agent 总览

| Agent | 类型 | 文件数 | 最大行数 | 可并行? |
|-------|------|--------|---------|---------|
| 1 | 测试创建 | 2 NEW | 180 | ✅ 与 2 并行 |
| 2 | 测试追加 | 1 EDIT | 100 | ✅ 与 1 并行 |
| 3 | 核心修复 | 2 EDIT | 80 | ❌ 依赖 1+2 |
| 4 | 基础设施 | 2 NEW + 2 EDIT | 80 | ✅ 与 3 并行 |
| 5 | 模块修复 | 2 EDIT | 15 | ❌ 依赖 3 |
| 6 | 验证 | 0-1 | 30 | ❌ 依赖 3 |
| 7 | 分歧修复 | 4 EDIT | 50 | ✅ 与 3 并行 |
| 8 | 分歧修复 | 4 EDIT | 60 | ✅ 与 3 并行 |
| 9-12 | 模块归一化 | 2/ea EDIT | 20/ea | ✅ 与 4 并行 |
| 13 | 最大模块 | 2 EDIT | 40 | ❌ 依赖 4 |
| 14 | 浏览器模块 | 4 EDIT | 30 | ❌ 依赖 5 |
| 15 | 全量验证 | 0 | 0 | ❌ 依赖全部 |
