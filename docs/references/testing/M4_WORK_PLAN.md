# M4 — macOS Tahoe 26 兼容性修复 工作计划

> 创建日期: 2026-04-23 | 状态: 待执行
> 来源: HANDOFF.md Current State 待办 + Known Gotchas #1-#5
> 目标: 修复 Tahoe 26 发现的 breaking changes，使 MacAudit 在 macOS 26 上完全兼容

---

## 总览

| Task | 标题 | 优先级 | 影响模块数 | 复杂度 | 状态 |
|------|------|--------|-----------|--------|------|
| T1 | `defaults -bool` 读取格式变更适配 | P0 | 8 | 高 | 待执行 |
| T2 | `socketfilterfw` 参数变更验证 | P1 | 2 | 低 | ✅ 已完成 |
| T3 | `plutil -create xml` 语法变更 | P2 | 0 | 无 | ✅ 不需要 |
| T4 | `kern.ipc.maxsockbuf` arm64 提示优化 | P2 | 1 | 低 | 待执行 |

---

## T1 — `defaults -bool` 读取格式变更适配 [P0]

### 问题描述 (Gotcha #1)

macOS Tahoe 26 上 `defaults write ... -bool true` 后 `defaults read` 返回格式变更：
- **旧格式** (macOS ≤15): `"1"` / `"0"`
- **新格式** (macOS 26): 可能返回 `{ "-bool" = true; }` 或其他 dict 格式

所有 `AuditCheck.command` 中用 `defaults read` 且 `expectedValue` 为 `"0"` 或 `"1"` 的检测项在 Tahoe 上可能误判。

### 影响范围

**8 个模块受影响**，每个模块文件有双副本（`Sources/MacAudit/Modules/` + `Sources/MacAuditCore/Modules/`），修改必须同步两份。

| # | 模块 | 文件 | 关键行 (MacAudit/Core) | 受影响 Check ID |
|---|------|------|----------------------|-----------------|
| 1 | NetworkSecurity | `NetworkSecurityModule.swift` | :187 / :118 | `m2.lock_password` |
| 2 | Privacy | `PrivacyModule.swift` | :24-43 / :26-45 | 16 个 `m4.*` checks |
| 3 | Animation | `AnimationModule.swift` | :141-225 / :142-225 | ~45 个 `m5.*` checks |
| 4 | Power | `PowerModule.swift` | :97-101 / :98-101 | `m7.screensaver_idle` |
| 5 | Shell | `ShellModule.swift` | :221 / :222 | `m9.system_lang` (info, 低优先) |
| 6 | Claude | `ClaudeProtectionModule.swift` | :259,348,416-440 / :259,332,406-430 | `m10.captive`, `m10.telemetry_*` |
| 7 | Chrome | `ChromeModule.swift` | :12-13 / :14-15 | 12 个 `m14.*` checks |
| 8 | Safari | `SafariModule.swift` | :10-122 / :12-124 | 13 个 `m15.*` checks |

**辅助文件也需更新**:
- `ShellExecutor.swift` — `readDefaults()` helper (:117-123)
- `FixEngine.swift` — `generateUndoCommand()` 动态生成 `defaults write -bool` undo (:157-184)

### 修复方案

#### 方案 A: Shell 端兼容（推荐）

在所有 `defaults read` 命令后追加格式归一化管道：

```bash
# 旧:
defaults read com.apple.screensaver askForPassword 2>/dev/null
# 新:
defaults read com.apple.screensaver askForPassword 2>/dev/null | grep -oE '^[01]$'
```

或更鲁棒的归一化：

```bash
# 统一归一化函数:
_norm_bool() { 
  local v="$1"
  case "$v" in
    1|true|True|TRUE|yes) echo "1" ;;
    0|false|False|FALSE|no) echo "0" ;;
    *) echo "$v" ;;
  esac
}
```

**优点**: 不改 Swift 结构，只改 command 字符串
**缺点**: command 字符串变长

#### 方案 B: Swift 端兼容

在 `ShellExecutor.readDefaults()` 或结果解析层加后处理：

```swift
func normalizeDefaultsBool(_ raw: String?) -> String? {
    guard let v = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
    if v == "1" || v.lowercased() == "true" || v.lowercased() == "yes" { return "1" }
    if v == "0" || v.lowercased() == "false" || v.lowercased() == "no" { return "0" }
    // dict 格式如 { "-bool" = true; } → 提取 true
    if v.contains("= true") || v.contains("= 1") { return "1" }
    if v.contains("= false") || v.contains("= 0") { return "0" }
    return v
}
```

**优点**: 集中处理，一处修改全部受益
**缺点**: 需要改 `AuditCheck` 的结果解析流程

#### 方案 C: 混合方案（推荐）

1. 在 `ShellExecutor` 添加 `readDefaultsBool()` helper，内部做格式归一化
2. `AuditCheck.command` 中的内联 shell 命令，改用 `grep -c` 或 `plutil -convert` 做读取
3. `FixEngine` 的 undo 生成逻辑加 Tahoe 分支

### 执行步骤

1. **[调研]** 在 Tahoe 26 VM 上实测所有 `defaults read` 返回值格式，确认精确变更范围
   - 测试命令: 逐模块 `defaults read <domain> <key>` 收集输出
   - 需 SSH 到 `<vm-user>@<vm-ip>`
2. **[设计]** 选定方案 A/B/C，在 `MacOSVersion.swift` 基础上加兼容层
3. **[实现]** 按模块逐个修改，每个模块改两份（MacAudit + MacAuditCore）
   - 改动顺序: Safari → Chrome → Privacy → Animation → Claude → NetworkSecurity → Power → Shell
   - 每改完一个模块，跑 `swift test` 对应测试文件
4. **[修复命令]** 更新 `FixEngine.generateUndoCommand()` 的 `defaults write -bool` 处理
5. **[测试]**
   - 本地 `swift test` 全 492 tests
   - Tahoe VM 实测 `defaults read` 全部检测项
   - macOS 15 VM 回归验证

### 预估工作量

| 步骤 | 时间 |
|------|------|
| 调研（VM 实测） | 30 min |
| 设计 + 基础设施 | 30 min |
| 8 模块 × 2 副本修改 | 2-3 hr |
| FixEngine 适配 | 30 min |
| 测试验证 | 1 hr |
| **合计** | **~4-5 hr** |

---

## T2 — `socketfilterfw` 参数变更验证 [P1] ✅ 已完成

### 问题描述 (Gotcha #2)

`--getallowsignedapp` 在 macOS 26 不再存在。

### 调查结果

**代码已使用新参数 `--getallowsigned`（不带 `app`）**，无需修改。

已确认的位置（全部已用新参数）:
- `NetworkSecurityModule.swift` MacAudit:137 / Core:103 — 检测命令用 `--getallowsigned`
- `NetworkSecurityModule.swift` MacAudit:140 / Core:106 — 修复命令用 `--setallowsigned`
- `ClaudeProtectionModule.swift` MacAudit:382-385 / Core:372-375 — 检测+修复都用新参数
- `NetworkWarning.swift` 两副本 — 引用 `--setglobalstate`（不受影响）

MacAudit:135 有注释: `macOS 15 已合并 allowsigned 和 allowsignedapp 为单一 --setallowsigned 参数`

### 结论

**此任务已在之前版本完成**，HANDOFF.md 的待办可以关闭。建议在 Tahoe 26 VM 上做一次确认测试。

---

## T3 — `plutil -create xml` 语法变更 [P2] ✅ 不需要

### 问题描述

HANDOFF.md 记录 `plutil -create xml` 在 Tahoe 26 不工作。

### 调查结果

**代码库中零 `plutil` 引用**。全部 plist 操作使用 `PlistBuddy`：
- `NetworkSecurityModule` — XProtect 版本读取 + LaunchDaemon 创建（PlistBuddy）
- `ChromeModule` — 10 处企业策略键设置（PlistBuddy）
- `ShellModule` — maxfiles LaunchDaemon 创建（PlistBuddy）
- `DevEnvironmentModule` — Xcode 清理 LaunchAgent 创建（PlistBuddy）

"走过的弯路"记录在 Dev Log 中说明 `plutil -create xml` 不工作后，已改用 PlistBuddy。

### 结论

**此任务已完成**（通过绕过方案），HANDOFF.md 的待办可以关闭。

---

## T4 — `kern.ipc.maxsockbuf` arm64 硬限制提示优化 [P2]

### 问题描述 (Gotcha #4)

arm64 上 `kern.ipc.maxsockbuf` 硬限制为 6291456 (6MB)，当前提示信息未充分说明：
- 用户可能尝试调高此值但无法生效
- fixCommand 直接给值但未说明硬限制背景

### 影响范围

| 文件 | 行 | 内容 |
|------|-----|------|
| `MacAudit/Modules/NetworkSecurityModule.swift` | :448-457 | arm64 判断 + description + expectedValue |
| `MacAuditCore/Modules/NetworkSecurityModule.swift` | :194-203 | 同上（Core 副本） |
| `MacAudit/Modules/NetworkSecurityModule.swift` | :484-506 | `m8.sysctl_plist` fixCommand 中的硬编码值 |
| `Tests/MacAuditTests/NetworkSecurityModuleTests.swift` | :222-240 | 测试期望值 |

### 修复方案

1. **description 优化**: 明确标注 "arm64 内核硬限制 6291456 (6MB)，无法通过 sysctl 提升"
2. **fixCommand 调整**: arm64 下不再建议 `sudo sysctl -w kern.ipc.maxsockbuf=6291456`（当前值已是硬限制，无意义），改为提示 "当前已是 arm64 硬限制最优值，无需调整"
3. **risk 级别考虑**: arm64 下 maxsockbuf 检测项可降为 `info`（因为无法修改）
4. **测试更新**: 确认测试期望值和 description 内容

### 执行步骤

1. 修改 `NetworkSecurityModule.swift` 两副本的 description 和 fixCommand
2. 考虑对 arm64 + macOS 26 组合做特殊处理（如果 Tahoe 改了硬限制值）
3. 更新测试文件
4. 本地 `swift test` 验证
5. Tahoe VM 实测确认（如限制值有变）

### 预估工作量

| 步骤 | 时间 |
|------|------|
| 代码修改 | 30 min |
| 测试 | 15 min |
| **合计** | **~45 min** |

---

## 执行顺序建议

```
Phase 1 — 关闭已完成项（30 min）
  ├── T2: 确认 socketfilterfw 已用新参数 → 更新 HANDOFF.md 关闭待办
  └── T3: 确认 plutil 已绕过 → 更新 HANDOFF.md 关闭待办

Phase 2 — 核心修复（4-5 hr）
  ├── T1-Step1: Tahoe VM 实测 defaults 返回值格式
  ├── T1-Step2: 设计兼容方案 + 实现基础设施
  ├── T1-Step3: 逐模块修改（8 模块 × 2 副本）
  ├── T1-Step4: FixEngine 适配
  └── T1-Step5: 全量测试（本地 + VM）

Phase 3 — 收尾优化（45 min）
  ├── T4: maxsockbuf 提示优化
  └── 更新 HANDOFF.md，标记 M4 完成
```

---

## 关键文件速查

### 双副本文件（修改必须同步）

```
Sources/MacAudit/Modules/NetworkSecurityModule.swift    ←→ Sources/MacAuditCore/Modules/NetworkSecurityModule.swift
Sources/MacAudit/Modules/SafariModule.swift              ←→ Sources/MacAuditCore/Modules/SafariModule.swift
Sources/MacAudit/Modules/PrivacyModule.swift             ←→ Sources/MacAuditCore/Modules/PrivacyModule.swift
Sources/MacAudit/Modules/AnimationModule.swift           ←→ Sources/MacAuditCore/Modules/AnimationModule.swift
Sources/MacAudit/Modules/PowerModule.swift               ←→ Sources/MacAuditCore/Modules/PowerModule.swift
Sources/MacAudit/Modules/ShellModule.swift               ←→ Sources/MacAuditCore/Modules/ShellModule.swift
Sources/MacAudit/Modules/ClaudeProtectionModule.swift    ←→ Sources/MacAuditCore/Modules/ClaudeProtectionModule.swift
Sources/MacAudit/Modules/ChromeModule.swift              ←→ Sources/MacAuditCore/Modules/ChromeModule.swift
Sources/MacAudit/CLI/NetworkWarning.swift                ←→ Sources/MacAuditCore/NetworkWarning.swift
Sources/MacAudit/CLI/FixEngine.swift                     ←→ Sources/MacAuditCore/FixEngine.swift
```

### 基础设施文件

```
Sources/MacAuditCore/ShellExecutor.swift          — readDefaults() helper
Sources/MacAuditCore/Models/MacOSVersion.swift    — .sequoia / .tahoe 枚举
Sources/MacAuditCore/Models/CPUArchitecture.swift — .arm64 / .x86_64 枚举
Sources/MacAuditCore/Models/AuditCheck.swift      — 数据模型
```

### 测试文件

```
Tests/MacAuditTests/NetworkSecurityModuleTests.swift  — maxsockbuf 测试
Tests/MacAuditTests/FixHistoryTests.swift             — fixCommand 测试
Tests/MacAuditTests/FixEngineTests.swift              — undo 生成测试
Tests/MacAuditTests/NetworkWarningTests.swift         — socketfilterfw 检测测试
```

---

## 风险与注意事项

1. **双副本同步**: 每次修改必须同步两份文件，遗漏会导致 CLI 和 Core 行为不一致
2. **VM 依赖**: T1 需要 Tahoe 26 VM 验证，VM 不可用时只能做本地编译检查
3. **回归风险**: `defaults` 命令修改影响面广，必须跑完全部 492 XCTest + VM 实测
4. **macOS 15 兼容**: 所有修改必须同时兼容 macOS 15（Sequoia），不能破坏已有行为
5. **FixEngine 影响**: undo 命令生成逻辑改错会导致 `--undo` 功能失效
