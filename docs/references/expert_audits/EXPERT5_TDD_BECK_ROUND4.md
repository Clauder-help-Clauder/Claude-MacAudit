# Expert 5: Kent Beck — TDD与开发者体验审查 Round 4

## 审查焦点
开发者体验与工作流 — Package.swift / HANDOFF.md / IntegrationTests / AuditRunnerTests / Config

## 发现的问题

### 问题 1: Package.swift 测试 target 依赖 `MacAudit` 而非 `MacAuditCore`
- **严重程度**: HIGH
- **类型**: 工作流问题
- **文件**: `MacAudit/Package.swift:54-56`
- **描述**: `MacAuditTests` 依赖 `"MacAudit"`（CLI executable target），而不是 `"MacAuditCore"`。这意味着每次运行 `swift test` 都会编译整个 CLI target，包括 CLI 专属的 `MenuUI`、`ReportGenerator` 等。更严重的是，测试只能访问 CLI 命名空间中的类型，无法直接测试 GUI target（`MacAuditUI`）中的 ViewModel 和 View。
- **修复建议**: 拆分为两个测试 target：`MacAuditCoreTests`（依赖 `MacAuditCore`）和 `MacAuditUITests`（依赖 `MacAuditUI`）。CLI 测试单独一个 `MacAuditCLITests`。

### 问题 2: 双模块代码复制是项目最大技术债
- **严重程度**: CRITICAL
- **类型**: 工作流问题
- **文件**: `MacAudit/HANDOFF.md:89-104`
- **描述**: 12个模块的代码在 `Sources/MacAudit/Modules/` 和 `Sources/MacAuditCore/Modules/` 之间存在完整复制。HANDOFF.md 承认了这个问题但选择了"延后"。这意味着每次修改模块代码都需要同步两份文件，而且测试只验证了其中一份。如果两份代码产生漂移，用户可能在 CLI 和 GUI 中看到不同的审计结果。
- **修复建议**: 将模块代码统一到 `MacAuditCore/Modules/`，CLI target 通过 `import MacAuditCore` 引用。如果 CLI 需要不同的模块行为，用子类或配置区分，不要复制代码。

### 问题 3: IntegrationTests 重复列出所有12个模块
- **严重程度**: MEDIUM
- **类型**: 代码重复（违反规则2：无重复）
- **文件**: `MacAudit/Tests/MacAuditTests/IntegrationTests.swift:96-155`
- **描述**: `integrationAllModulesInstantiate`、`integrationAllModulesHaveIds`、`integrationAllModulesHaveChecks` 三个测试都手动创建了相同的12模块数组。如果新增模块，需要修改三个地方。应该提取为共享常量。
- **修复建议**: `private let allModules: [any AuditModule] = [...]`，三个测试共用。

### 问题 4: AuditRunnerTests 和 IntegrationTests 都创建了 private TestModule
- **严重程度**: MEDIUM
- **类型**: 代码重复
- **文件**: `IntegrationTests.swift:7-27` vs `AuditRunnerTests.swift:6-25`
- **描述**: 两个文件各自定义了几乎相同的 `TestModule`/`IntegrationTestModule`。这是跨文件重复，违反了 Simple Design Rule 2。
- **修复建议**: 提取 `TestModule` 到共享的 `TestHelpers.swift` 文件。

### 问题 5: IntegrationTests 执行真实 shell 命令 — 在 CI 中脆弱
- **严重程度**: HIGH
- **类型**: 测试隔离
- **文件**: `MacAudit/Tests/MacAuditTests/IntegrationTests.swift:31-90`
- **描述**: 集成测试用真实的 `AuditRunner` + 真实的 `ShellExecutor` 执行 `echo yes`/`echo no`。虽然名为"集成测试"是合理的，但它们和单元测试混在同一个 target 中。如果这些测试偶尔失败（进程调度、资源竞争），会拖慢整个测试套件。
- **修复建议**: 将集成测试标记为单独的 `@Suite` 或使用条件编译 `#if canImport(IntegrationTest)`，让 CI 可以选择性地运行。

### 问题 6: expectations.json 配置文件只有示例，未被测试覆盖
- **严重程度**: MEDIUM
- **类型**: 覆盖不足
- **文件**: `MacAudit/Config/expectations.json`
- **描述**: 配置文件支持覆盖期望值和跳过检查项，但没有测试验证这些功能是否工作。如果 JSON 解析逻辑被破坏，用户修改的配置不会生效但也不会报错。
- **修复建议**: 添加 `ExpectationsConfigTests.swift`：验证 JSON 解析、覆盖生效、跳过逻辑。

## Tacit Knowledge 审查
HANDOFF.md 是这个项目最好的开发者体验资产。它记录了踩过的坑（SIGSEGV、lazy var、双模块漂移）、构建命令、架构决策。这是真正的"Tacit Knowledge"——那些不在代码中但在开发者脑子里的知识。每次 handoff 日志都包含触发、改动、验证、提交状态，这是极好的 TDD 工作流记录。但 HANDOFF.md 也暴露了项目的核心矛盾：双模块复制。这个技术债每天都会增加认知负担，每次修改模块都要"同步两份"，这是对 Simple Design 的持续违反。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 测试质量 | 6 | IntegrationTests 和 AuditRunnerTests 写得不错，但 TestModule 重复 |
| 测试覆盖 | 5 | expectations.json 配置覆盖未被测试；GUI 层几乎没有单元测试 |
| 简单设计 | 4 | 双模块复制是最大的简单设计违反 |
| 开发者体验 | 8 | HANDOFF.md 出色；Quick Start 清晰；Known Gotchas 极具价值 |
| 重构信心 | 5 | 双模块复制让任何重构都倍增风险 |
