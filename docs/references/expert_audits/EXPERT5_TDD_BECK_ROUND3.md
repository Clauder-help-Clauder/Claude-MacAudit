# Expert 5: Kent Beck — TDD与开发者体验审查 Round 3

## 审查焦点
简单设计4规则审查 — FixEngine / AuditCheck 源码与测试

## 发现的问题

### 问题 1: FixEngine 混合了业务逻辑和终端输出
- **严重程度**: HIGH
- **类型**: 过度设计（违反规则4：最小化类和方法数）
- **文件**: `MacAudit/Sources/MacAudit/CLI/FixEngine.swift:50-91,187-198`
- **描述**: `printFixPlan()`、`printSudoCommands()` 和 `executeMedium()` 中的 `Layout.print()` 调用把终端渲染逻辑嵌入了业务逻辑。一个 260 行的 struct 同时负责：提取修复动作、排序、分组显示、执行修复、生成 undo 命令、保存历史。这违反了单一职责，使测试必须承受终端输出的副作用。
- **修复建议**: 提取 `FixPlanRenderer` 负责终端显示，`FixEngine` 只返回数据结构。这样测试只测逻辑，不关心输出格式。

### 问题 2: AuditCheck 有15个存储属性 + 14参数的 init — 参数爆炸
- **严重程度**: MEDIUM
- **类型**: 过度设计
- **文件**: `MacAudit/Sources/MacAudit/Models/AuditCheck.swift:4-54`
- **描述**: AuditCheck 的 init 有14个参数。虽然便利 init 提供了默认值，但每次创建 check 仍然需要传递 `module`、`command` 这种重复参数。在 module 文件中，每个 check 的构造都重复了 `module: "network_security"` 这样的参数。
- **修复建议**: 使用 Builder 模式或工厂方法：`AuditCheck.make(module: "network_security") { $0.id = "m2.sip"; $0.expected = "enabled" }`。或者用 `Module` 基类提供预填充 module 的 `check()` 工厂方法。

### 问题 3: FixEngineTests 是整个项目中最好的测试文件
- **严重程度**: LOW (正面发现)
- **类型**: 最佳实践示范
- **文件**: `MacAudit/Tests/MacAuditTests/FixEngineTests.swift:1-523`
- **描述**: 这个文件展示了正确的 TDD 实践：(1) 每个测试验证一个行为；(2) 使用 mock executor 和注入 confirm 闭包；(3) 测试正面和负面路径；(4) 测试边界条件（空输入、sudo 过滤、networkRisk 过滤）；(5) 测试 is孤立——使用 tmpDir+UUID+defer 清理。这是其他测试文件应该学习的榜样。
- **修复建议**: 将 FixEngineTests 的模式推广到其他测试文件。

### 问题 4: generateUndoCommand 使用正则表达式但缺少边缘情况测试
- **严重程度**: MEDIUM
- **类型**: 覆盖不足
- **文件**: `MacAudit/Sources/MacAudit/CLI/FixEngine.swift:157-184`
- **描述**: undo 命令生成用正则匹配 `defaults write/delete`，但只测了4种情况。未测试：`defaults write -g`（全局域）、含空格的 domain/key、`defaults write com.apple.dock`（无 key）、sudo + defaults write 组合的 undo。
- **修复建议**: 添加至少3个测试：全局域 undo、sudo 命令 undo、包含 `-float` 类型标志的 undo。

### 问题 5: AuditCheckTests 测试的是 getter/setter 而非行为
- **严重程度**: MEDIUM
- **类型**: 测试坏味道
- **文件**: `MacAudit/Tests/MacAuditTests/AuditCheckTests.swift:6-131`
- **描述**: 前12个测试（第7-131行）全部是"我设置了X，我读回X，X等于我设置的值"。这是在测试 Swift 的 struct 属性系统，不是在测试任何业务逻辑。唯一有价值的测试是 `isApplicable` 的四象限测试（第71-131行）。
- **修复建议**: 删除纯粹的 getter/setter 测试。保留 `isApplicable` 四象限测试（这是真正有价值的行为测试）和 `AuditResult` 的工厂方法测试。

### 问题 6: FixEngine.executeSafe 使用真实 ShellExecutor 执行真实命令
- **严重程度**: HIGH
- **类型**: 测试隔离
- **文件**: `MacAudit/Tests/MacAuditTests/FixEngineTests.swift:188-284`
- **描述**: `executeSafe` 的多个测试创建真实的 `ShellExecutor()` 来执行 `echo`、`exit 1` 等命令。虽然 `executeMedium` 测试使用了 `stubbedOutputs`，但 `executeSafe` 测试没有。这意味着这些测试会创建真实的历史文件、执行真实的进程。
- **修复建议**: 给 `executeSafe` 测试也使用 `ShellExecutor(stubbedOutputs:)` mock。

## Tacit Knowledge 审查
AuditCheck 是项目的核心数据模型。15个属性、14参数 init 看起来很重，但考虑到它承载了"一个安全检查项的完整定义"，这个复杂度是合理的。真正的问题不在于属性多，而在于没有提供一个领域特定的构造 DSL。如果我用 TDD 的方式从头开始，我会先写 `check.isApplicable(version:device:)` 的测试（四象限），然后才考虑数据结构。这个项目的测试顺序反了——先测数据结构，后测行为。但 `isApplicable` 的四象限测试写得非常好，覆盖了所有组合。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 测试质量 | 7 | FixEngineTests 是标杆；AuditCheckTests 过度测试了 getter/setter |
| 测试覆盖 | 7 | extractFixActions 的8种路径都覆盖了；generateUndoCommand 边缘情况不足 |
| 简单设计 | 6 | FixEngine 职责过多；AuditCheck 参数过多但合理 |
| 开发者体验 | 6 | FixEngineTests 的 helper 工厂方法（makeCheck/makeResult）非常清晰 |
| 重构信心 | 7 | FixEngine 的逻辑重构有很好的测试安全网 |
