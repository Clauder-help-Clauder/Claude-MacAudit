# Expert 4: Dijkstra — 形式逻辑与正确性审查 Round 3

## 审查焦点
算法正确性与数据流

## 发现的问题

### 问题 1: FixEngine.generateUndoCommand 正则表达式不匹配多空格/路径含空格的 defaults 命令
- **严重程度**: HIGH
- **逻辑类型**: 算法/正则
- **文件**: FixEngine.swift:160
- **形式化描述**: 正则 `^(sudo\s+)?defaults\s+(write|delete)\s+(\S+)\s+(\S+)` 用 `\S+` 匹配 domain 和 key。当 domain 或 key 包含空格（如 `defaults write "ByHost" "com.apple.."`），`\S+` 无法正确匹配引号包裹的路径。更严重的是：`\S+` 会贪婪匹配含引号的字符串但不理解引号语义。
- **反例**: 命令 `defaults write com.apple.dock "orientation" -string left` → 正确匹配。但 `defaults write "com.apple.dock" orientation -string left` → `\S+` 匹配 `"com.apple.dock"` 含引号 → undo 命令中 domain 含引号 → `defaults write "com.apple.dock" key value` 可能正常（shell 处理引号），但若原始命令用 `$HOME/Library/Preferences/com.xyz.plist` → undo 命令不含路径前缀。
- **修复建议**: 使用更宽松的匹配或 tokenize defaults 命令参数。至少处理引号包裹和路径式 domain。

### 问题 2: FixEngine.executeSafe 的 "newValue" 提取逻辑不正确
- **严重程度**: MEDIUM
- **逻辑类型**: 算法
- **文件**: FixEngine.swift:127
- **形式化描述**: `newValue: action.command.components(separatedBy: " ").last ?? ""` 取命令最后一个空格后的部分作为"新值"。对于 `defaults write /Library/Preferences/com.apple.alf globalstate -bool true`，结果为 `true`。但对于 `defaults write com.apple.dock orientation -string left`，结果为 `left`。当命令末尾有 `2>/dev/null` 或 `|| true` 时，提取的值是 `true` 而非实际设置值。
- **反例**: 命令 `defaults write com.apple.dock autohide -bool true && killall Dock` → `last` = `Dock` → FixRecord 的 newValue 为 "Dock" 而非 "true"。
- **修复建议**: 使用正则从 defaults write 命令中提取值部分，或直接存储命令执行后的读取结果。

### 问题 3: AuditModule.runChecks 的比较逻辑忽略大小写但 expectedValue 可能是布尔/数字
- **严重程度**: MEDIUM
- **逻辑类型**: 算法/不变量
- **文件**: AuditModule.swift:77
- **形式化描述**: `actual.lowercased() == expected.lowercased()` 将两边转小写比较。对于布尔值 "YES"/"Yes"/"yes" 这正确。但对于版本号 "10.15.7" vs "10.15.7" 无影响。但数字 "0" vs "0" 也无影响。真正的风险在于：某些 shell 输出含尾部空格或换行符，`trimmedOutput` 已处理。但 `defaults read` 输出 "1\n" 经 trim 后为 "1"，若 expected 为 "true" 则不匹配——这是语义层面的不匹配（1 和 true 在 defaults 域中语义相同）。
- **反例**: `defaults read` 返回 "1" 但 expectedValue 为 "true" → 比较 "1" != "true" → 误判为 fail。
- **修复建议**: 添加语义归一化层（"1"/"yes"/"true" → "true"，"0"/"no"/"false" → "false"）。

### 问题 4: ReportGenerator.generateJSON 中 Duration 转换精度问题
- **严重程度**: LOW
- **逻辑类型**: 算法
- **文件**: ReportGenerator.swift:105-106
- **形式化描述**: `Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18` 中 `1e18` 是 Double 字面量。Swift 的 `Double` 有约 15-16 位有效数字，而 attoseconds 可达 10^18 量级，除法后精度损失约 3 位。对于秒级精度这可接受，但 Round 2 中 ShellExecutor 用相同公式转毫秒，那里的精度损失更严重。
- **反例**: Duration 为 0.001 秒 → components.seconds = 0, components.attoseconds = 1e15 → 1e15/1e18 = 0.001 → 正确。Duration 为 0.0000001 秒 → 1e11/1e18 = 1e-7 → 正确。实际风险极低。
- **修复建议**: 使用 Swift 5.7+ 的 `Duration.components` 或 `Double(duration)` (Swift 6+)。

### 问题 5: BaselineManager.diff 未处理 checkId 重复
- **严重程度**: HIGH
- **逻辑类型**: 算法/不变量
- **文件**: BaselineManager.swift:61-66
- **形式化描述**: `Dictionary(uniqueKeysWithValues:)` 在遇到重复 key 时会崩溃（runtime error）。若 `results` 数组中有两个相同 `checkId` 的条目（由于模块配置错误或数据损坏），函数会 crash。
- **反例**: JSON 报告中因 bug 出现两条 `checkId: "m1.firewall"` → `Dictionary(uniqueKeysWithValues:)` → fatal error: "Duplicate values for key"。
- **修复建议**: 使用 `Dictionary(grouping:) + mapValues(.first!)` 或 `Dictionary(_:uniquingKeysWith:)` 提供去重策略。

### 问题 6: AuditModule.runChecksParallel 结果按 index 排序但 index 类型为 Int
- **严重程度**: LOW
- **逻辑类型**: 算法
- **文件**: AuditModule.swift:142
- **形式化描述**: `indexed.sorted { $0.0 < $1.0 }` 按 Int index 排序。当 `allChecks.count > 0` 时逻辑正确。但若 `allChecks` 为空数组，`withTaskGroup` 不会创建任何任务，返回空数组。边界条件正确。
- **反例**: 无反例。逻辑正确但值得注明。
- **修复建议**: 无需修复，逻辑正确。

## Philosophy 审查 — 程序哲学

> "The purpose of computing is insight, not numbers." — Hamming, 但 Dijkstra 会说：洞察力来自对不变量的精确陈述。

`Dictionary(uniqueKeysWithValues:)` 在重复 key 时崩溃——这不是"防御性编程"的问题，而是前置条件未声明的问题。函数的契约是"输入无重复 key"，但这个前置条件既未被文档化，也未被运行时检查。正确的做法：要么在类型层面保证无重复（使用 Set），要么使用安全的构造器并提供明确的行为定义。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 状态完备性 | 7 | diff 逻辑考虑了多种状态转换 |
| 边界安全 | 5 | 重复 key 崩溃、正则边界 |
| 算法正确性 | 6 | undo 生成有缺陷 |
| 并发安全 | 7 | runChecksParallel 排序正确 |
| 逻辑简洁性 | 6 | generateUndoCommand 过于复杂 |
