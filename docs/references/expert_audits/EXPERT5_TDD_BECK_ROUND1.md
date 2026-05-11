# Expert 5: Kent Beck — TDD与开发者体验审查 Round 1

## 审查焦点
测试覆盖与质量 — ShellModule / ResultsViewModel / PowerModule / AnimationModule

## 发现的问题

### 问题 1: ShellModule 测试只验证结构元数据，未验证任何行为
- **严重程度**: HIGH
- **类型**: 覆盖不足
- **文件**: `MacAudit/Tests/MacAuditTests/ShellModuleTests.swift:9-54`
- **描述**: 6个测试全部在验证 `id` 唯一性、前缀、非空命令等结构性约束。没有任何测试验证：检测命令的逻辑正确性、expectedValue 是否匹配安全策略、fixCommand 是否能真正修复问题。这是"测试数据形状"而非"测试系统行为"。
- **修复建议**: 增加 `shellCheckExpectedValues()` 测试，验证关键检查项（如 `m9.dangerous_alias`）的 expectedValue 是什么。增加测试验证 fixCommand 包含正确的修复 defaults write 命令。

### 问题 2: ResultsViewModel 测试重写了被测逻辑而非测试真实代码
- **严重程度**: CRITICAL
- **类型**: 测试坏味道
- **文件**: `MacAudit/Tests/MacAuditTests/ResultsViewModelTests.swift:130-138`
- **描述**: 测试文件自己实现了 `sortResultsFailFirst()` 和 `moduleNameFrom()` 函数，然后用这些本地副本来测试。这意味着测试验证的是"我的复制是否正确"而非"产品代码是否正确"。如果产品代码的实现改变了，这些测试仍然会通过。这是经典的"测试测试而非测试代码"问题。
- **修复建议**: 直接导入并测试 `AppViewModel` 或 `ResultsViewModel` 的真实方法。如果不能直接访问，则通过公开的公共API间接测试行为。

### 问题 3: ResultsViewModel 使用私有 `TestModuleSummary` 而非真实类型
- **严重程度**: HIGH
- **类型**: 测试坏味道
- **文件**: `MacAudit/Tests/MacAuditTests/ResultsViewModelTests.swift:5-12`
- **描述**: 创建了 `TestModuleSummary` 私有结构体来模拟真实类型。如果真实类型的 `score` 计算逻辑改变了（比如改用浮点数），测试仍然使用旧的整数除法公式，不会发现回归。测试应该描述"当真实类型被修改时，行为是否仍然正确"。
- **修复建议**: 使用真实的 `ModuleSummary` 类型（从 `@testable import MacAudit` 或 `MacAuditUI` 获取）。如果类型在不同 target，应该通过集成测试覆盖。

### 问题 4: PowerModule 测试硬编码魔术数字且无解释
- **严重程度**: MEDIUM
- **类型**: 测试坏味道
- **文件**: `MacAudit/Tests/MacAuditTests/PowerModuleTests.swift:20,27`
- **描述**: `checks.count == 28` 和 `checks.count == 21` 是硬编码的魔术数字。虽然注释中有计算过程，但测试本身无法告诉你 *为什么* 是28。当新增一个检查项时，这个测试会失败，开发者需要手动计算新的期望值。
- **修复建议**: 使用 `#expect(checks.count >= 21)` 等范围断言，或提取常量 `let expectedLaptopChecks = 28` 并配以计算注释，使失败消息自动解释原因。

### 问题 5: AnimationModule 的 fixCommand 测试依赖显示名称（中文字符串）
- **严重程度**: MEDIUM
- **类型**: 脆弱测试
- **文件**: `MacAudit/Tests/MacAuditTests/AnimationModuleTests.swift:89-161`
- **描述**: 测试通过 `$0.name == "启动弹跳动画"` 查找检查项。如果中文名称被修改（本地化调整），所有相关测试都会断裂。应该使用稳定的 `id` 字段而非人类可读的 `name`。
- **修复建议**: 改用 `checks.first { $0.id == "m5.xxx" }` 查找。ID 是稳定契约，名称是展示细节。

### 问题 6: 缺少负面测试和边界条件测试
- **严重程度**: MEDIUM
- **类型**: 覆盖不足
- **文件**: 所有4个测试文件
- **描述**: 没有测试验证：传入无效版本参数时的行为、checks 为空时的处理、模块重复调用的一致性。所有测试都是"happy path"——阳光下的测试。
- **修复建议**: 添加边界测试：`module.checks(for: .sequoia, device: .laptop)` 第二次调用是否返回相同结果？`checks(for: .tahoe, device: .laptop)` 对所有模块是否都非空？

## Tacit Knowledge 审查
这些测试更像是"配置验证器"而非"行为规格说明"。它们确认数据结构正确，但没有确认系统在用户场景中会做什么。好的测试应该让我有信心说："如果我重构了 AnimationModule 的内部实现，只要这些测试通过，系统的外部行为就没变。" 目前的测试不能给我这个信心——因为它们测试的是数据结构的形状，不是行为的含义。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 测试质量 | 4 | 大量结构性断言，缺少行为验证；ResultsViewModel 重复实现了被测逻辑 |
| 测试覆盖 | 5 | 元数据覆盖充分，行为覆盖严重不足 |
| 简单设计 | 6 | 测试代码本身简洁，但测了错的东西 |
| 开发者体验 | 5 | 测试命名清晰，但魔术数字和硬编码中文降低可维护性 |
| 重构信心 | 3 | 如果我重构内部实现，当前测试无法提供安全网 |
