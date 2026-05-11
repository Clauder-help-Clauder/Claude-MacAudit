# M4 Test Plan — 分段执行计划 (Part 2: 核心引擎修复)

> 依赖: Part 1 (P0 测试) 必须全部通过
> 本段修改核心引擎代码，是最关键的一步

---

## Agent 3: 修复 FixEngine.generateUndoCommand()

### 任务边界
- **修改文件**: 2 个
  - `Sources/MacAudit/CLI/FixEngine.swift` (lines 127, 157-184)
  - `Sources/MacAuditCore/FixEngine.swift` (lines 127, 157-184)
- **最大行数**: ~80 行/文件（替换 generateUndoCommand 函数）
- **风险等级**: 高（影响所有 fix → undo 流程）

### 修改点 1: newValue 提取 (line 127)

```swift
// 现有代码:
newValue: action.command.components(separatedBy: " ").last ?? ""

// 修复为:
newValue: {
    let firstSegment = action.command.components(separatedBy: " && ").first ?? action.command
    return firstSegment.components(separatedBy: " ").last ?? ""
}()
```

### 修改点 2: generateUndoCommand() 函数 (lines 157-184)

扩展正则匹配，支持:
1. `defaults write/delete` — 现有逻辑（保留）
2. `PlistBuddy -c 'Set/Add'` — 新增: 生成 `PlistBuddy -c 'Delete'` 或 `'Set :key prevValue'`
3. 复合命令 (`&&`) — 新增: 只处理第一个命令段
4. previousValue 转义 — 新增: 对 shell 特殊字符做单引号包裹

伪代码:
```
if fixCommand matches PlistBuddy pattern:
    extract key path from PlistBuddy command
    if previousValue == "not set": undo = "PlistBuddy -c 'Delete :keyPath' plist"
    else: undo = "PlistBuddy -c 'Set :keyPath previousValue' plist"

elif fixCommand matches defaults write (after stripping && suffix):
    (existing logic, with previousValue shell-escaping added)

else:
    "# 手动回滚: fixCommand"
```

### 关键: previousValue Shell 转义

```swift
static func shellEscape(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
    return "'\(escaped)'"
}
```

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter FixEngineTests --filter FixHistoryTests
```

### 回滚: `git checkout Sources/MacAudit/CLI/FixEngine.swift Sources/MacAuditCore/FixEngine.swift`

### 提交: `fix(U-01,U-06,B-02): FixEngine undo supports PlistBuddy, compound, Tahoe dict`

---

## Agent 4: 添加 DefaultsNormalizer

### 任务边界
- **创建文件**: 1 个
  - `Sources/MacAuditCore/Utils/DefaultsNormalizer.swift` (NEW)
- **修改文件**: 1 个
  - `Sources/MacAuditCore/Models/AuditModule.swift` (比较层加入归一化)
- **对应副本**:
  - `Sources/MacAudit/Models/AuditModule.swift` (CLI 副本也需同步)
- **最大行数**: ~60 行新文件 + ~20 行修改
- **风险等级**: 中（改变比较行为，但仅在 expected 为 "0"/"1" 时触发）

### 新文件: DefaultsNormalizer.swift

```swift
public enum DefaultsNormalizer {
    public static func normalize(_ raw: String, expected: String?) -> String {
        guard let expected, isBoolExpected(expected) else { return raw }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "1", "true", "yes":
            return "1"
        case "0", "false", "no":
            return "0"
        default:
            if trimmed.hasPrefix("{") && trimmed.contains("= true") { return "1" }
            if trimmed.hasPrefix("{") && trimmed.contains("= false") { return "0" }
            if trimmed.hasPrefix("{") && trimmed.contains("= 1") { return "1" }
            if trimmed.hasPrefix("{") && trimmed.contains("= 0") { return "0" }
            return raw
        }
    }

    private static func isBoolExpected(_ expected: String) -> Bool {
        return expected == "0" || expected == "1"
    }
}
```

### 修改 AuditModule.swift 比较层

在 `actual.lowercased() == expected.lowercased()` 之前添加:

```swift
let normalized = DefaultsNormalizer.normalize(actual, expected: check.expectedValue)
let actual = normalized  // 覆盖原始 actual
```

### 创建测试: DefaultsNormalizerTests.swift

8 个测试用例:
1. `"1"` → `"1"` (直通)
2. `"0"` → `"0"` (直通)
3. `"true"` → `"1"`
4. `"false"` → `"0"`
5. `{ "-bool" = true; }` → `"1"` (Tahoe dict)
6. `{ "-bool" = false; }` → `"0"` (Tahoe dict)
7. `"scale"` → `"scale"` (非 bool 直通)
8. `""` → `""` (空值直通)

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter AnimationModuleTests --filter SafariModuleTests --filter ChromeModuleTests
```

### 提交: `feat(U-02): add DefaultsNormalizer for Tahoe bool comparison tolerance`

---

## Agent 5: 修复 Safari popup_block 复合 fixCommand

### 任务边界
- **修改文件**: 2 个
  - `Sources/MacAudit/Modules/SafariModule.swift` (line ~74)
  - `Sources/MacAuditCore/Modules/SafariModule.swift` (line ~76)
- **最大行数**: ~15 行/文件
- **风险等级**: 低

### 修改方案: 拆分为两个独立 check

```swift
// 现有: m15.popup_block 包含:
// fixCommand: "defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false && defaults write com.apple.Safari WebKit2JavaScriptCanOpenWindowsAutomatically -bool false"

// 拆为:
// m15.popup_block_webkit:
//   fixCommand: "defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false"
// m15.popup_block_webkit2:
//   fixCommand: "defaults write com.apple.Safari WebKit2JavaScriptCanOpenWindowsAutomatically -bool false"
```

### 更新 SafariModuleTests
- 增加测试: 验证两个拆分后的 check 都有独立的 fixCommand
- 更新 check count 断言

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter SafariModuleTests --filter FixEngineTests
```

### 提交: `fix(U-16): split Safari popup_block into WebKit/WebKit2 for correct undo`

---

## Agent 6: 验证 Chrome PlistBuddy undo

### 任务边界
- **修改文件**: 0 个（验证型任务）
- **运行**: ChromeModuleTests + FixEngineTests
- **最大行数**: 如需添加测试，~30 行

### 任务
1. 运行 Agent 3 修复后的 FixEngine
2. 对每个 Chrome fixCommand 调用 generateUndoCommand
3. 验证输出是可执行命令（不是 `# 手动回滚` 注释）
4. 如 Agent 3 的 PlistBuddy 支持不够，在此补充

### 验证门禁
```bash
bash scripts/build_app.sh && \
swift test --filter ChromeModuleTests --filter FixEngineTests
```

### 提交: `test(B-02): verify Chrome PlistBuddy undo generation`

---

## 依赖图

```
Agent 3 (FixEngine) ─────┬──▶ Agent 5 (Safari popup) ──┐
                         └──▶ Agent 6 (Chrome verify) ──┤
                                                         ├──▶ Part 3
Agent 4 (DefaultsNormalizer) ───────────────────────────┤
```

Agent 3 和 Agent 4 **可并行**。Agent 5 和 Agent 6 依赖 Agent 3。
