# M4 Test Plan — 分段执行计划 (Part 1: P0 测试编写)

> 本文件为分段执行计划的第一部分：P0 测试编写
> 每段 ≤200 行，由独立 sub-agent 执行
> 执行前必须: `git checkout -b fix/m4-tahoe-compat`

---

## Pre-Flight 检查清单

- [ ] 当前在 `fix/m4-tahoe-compat` 分支
- [ ] `bash scripts/build_app.sh` 构建成功
- [ ] `swift test --filter MacAuditTests` 基线通过
- [ ] `git status` 工作区干净

---

## Agent 1: SafariModuleTests + ChromeModuleTests

### 任务边界
- **创建文件**: 2 个新文件
- **修改文件**: 0 个
- **最大行数**: ~180 行（Safari ~80 + Chrome ~100）
- **风险等级**: 极低（纯新增，不触碰现有代码）

### 文件 1: Tests/MacAuditTests/SafariModuleTests.swift (~80 行)

```swift
// 需要包含的测试:
@Test("Safari module metadata") func safariModuleMetadata()
  → module.id == "safari", name 非空

@Test("Safari checks count for sequoia laptop arm64")
func safariChecksCountSequoia()
  → 验证 check 数量

@Test("Safari checks count for tahoe laptop arm64")
func safariChecksCountTahoe()
  → tahoe 比 sequoia 多 1 (m15.enhanced_regular)

@Test("Safari all checks belong to safari module")
func safariAllChecksBelongToModule()
  → 所有 check.module == "safari"

@Test("Safari popup_block has compound fixCommand with &&")
func safariPopupBlockCompoundFix()
  → m15.popup_block 的 fixCommand 包含 "&&"

@Test("Safari tahoe exclusive check present")
func safariTahoeExclusiveCheck()
  → checks(for: .tahoe) 包含 id 含 "enhanced_regular"

@Test("Safari all checks have expected values")
func safariAllChecksHaveExpected()
  → 非 info 类型的 check 都有 expectedValue

@Test("Safari all check IDs are unique")
func safariCheckIDsUnique()
  → id 集合大小 == checks 数量
```

### 文件 2: Tests/MacAuditTests/ChromeModuleTests.swift (~100 行)

```swift
// 需要包含的测试:
@Test("Chrome module metadata") func chromeModuleMetadata()
  → module.id == "chrome", name 非空

@Test("Chrome checks count")
func chromeChecksCount()
  → 验证总 check 数量

@Test("Chrome all fixCommands use PlistBuddy")
func chromeAllFixUsePlistBuddy()
  → 每个 fixCommand 包含 "PlistBuddy"

@Test("Chrome no fixCommand uses defaults write")
func chromeNoDefaultsWrite()
  → 每个 fixCommand 不匹配 "defaults write"

@Test("Chrome installed check present")
func chromeInstalledCheck()
  → 包含 id == "m14.installed"

@Test("Chrome all check IDs are unique")
func chromeCheckIDsUnique()

@Test("Chrome module has correct module ID")
func chromeModuleID()
  → 确认 module.id 正确
```

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter SafariModuleTests --filter ChromeModuleTests
```

### 提交: `test: add SafariModule and ChromeModule test coverage (P0)`

---

## Agent 2: FixEngine Tahoe Undo 测试

### 任务边界
- **修改文件**: 1 个 (`Tests/MacAuditTests/FixEngineTests.swift`)
- **最大行数**: ~100 行（追加到文件末尾）
- **风险等级**: 低（追加测试，不修改现有代码）

### 追加测试到 FixEngineTests.swift

```swift
// 需要追加的测试:
@Test("generateUndoCommand handles Tahoe dict previousValue")
func undoTahoeDictPreviousValue()
  → previousValue = "{ \"-bool\" = true; }"
  → 验证 undo 命令不包含未转义的大括号

@Test("generateUndoCommand handles PlistBuddy command")
func undoPlistBuddyCommand()
  → fixCommand = "sudo /usr/libexec/PlistBuddy -c 'Set :BlockPopups true ...'"
  → 验证 undo 为 "# 手动回滚" 注释 或 正确的 PlistBuddy Delete

@Test("generateUndoCommand handles compound && fixCommand")
func undoCompoundFixCommand()
  → fixCommand = "defaults write A K1 -bool false && defaults write A K2 -bool false"
  → 验证行为（至少处理第一个命令）

@Test("generateUndoCommand handles sudo prefix")
func undoSudoPrefix()
  → fixCommand = "sudo defaults write ..."
  → 验证 undo 正确处理 sudo 前缀

@Test("generateUndoCommand preserves -string type flag")
func undoStringTypeFlag()
  → fixCommand = "defaults write ... -string none"
  → previousValue = "prompt"
  → 验证 undo 为 "defaults write ... -string prompt"

@Test("generateUndoCommand handles pipe compound (killall Dock)")
func undoPipeCompound()
  → fixCommand = "defaults write ... && killall Dock"
  → 验证行为
```

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter FixEngineTests
```

### 提交: `test: add FixEngine undo tests for Tahoe/compound/PlistBuddy (P0)`

---

## Agent 依赖关系

```
Agent 1 (Safari+Chrome tests) ──┐
Agent 2 (FixEngine tests) ──────┤
                                 ├──▶ Part 2 可以开始
```

Agent 1 和 Agent 2 **可并行执行**，互不依赖。

---

## 安全约束

| 约束 | 值 | 原因 |
|------|-----|------|
| 每文件最大行数 | 200 | 防止上下文腐烂 |
| SSH 命令数 | N/A（本段无 SSH） | — |
| 修改文件数 | ≤2 | 本段只新增测试 |
| swift test 全量运行 | 禁止 | 仅 `--filter` 针对性测试 |
| swift build | 禁止裸跑 | 必须用 `bash scripts/build_app.sh` |
