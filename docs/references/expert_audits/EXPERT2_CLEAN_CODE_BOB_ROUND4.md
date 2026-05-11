# Expert 2: Uncle Bob — 清洁代码与架构审查 Round 4

## 审查焦点
设计模式与抽象质量

## 发现的问题

### 问题 1: AuditResult 工厂方法 — 过多的静态便利构造器
- **严重程度**: MEDIUM
- **SOLID违规**: OCP（开放-封闭原则）
- **文件**: `MacAudit/Models/AuditResult.swift:18-150`
- **描述**: `AuditResult` 有 6 个 static factory 方法（`pass`, `fail`, `warn`, `info`, `skip`, `error`）。每个方法都在做相同的模式：构造 `AuditResult` 实例，只是 `status` 和部分字段不同。这本身是好的（Factory Method 模式），但问题是：
  - `message` 的默认值逻辑分散在每个工厂方法中（`isEmpty ? "\(check.name): \(actual)" : message`）
  - 新增状态需要添加新的工厂方法，违反 OCP
  - `pass/fail/info` 在 `runChecks` 中通过 `if-else` 链选择，而非由状态对象自己决定
- **修复建议**: 考虑将 status-specific 逻辑（消息格式化）移入 `AuditStatus` enum 的方法中，减少工厂方法中的重复。

### 问题 2: AuditCheck — 贫血模型的边界案例
- **严重程度**: MEDIUM
- **SOLID违规**: SRP + 告知而非询问（Tell, Don't Ask）
- **文件**: `MacAudit/Models/AuditCheck.swift:1-62`
- **描述**: `AuditCheck` 是一个纯数据容器（62 行 struct），包含 14 个存储属性和 1 个 `isApplicable` 方法。数据和行为分离体现在：
  - `AuditModule.runChecks` 中通过 `check.expectedValue` 判断是否做比较 — 这是 Check 应该自己的逻辑
  - `FixEngine.extractFixActions` 中通过 `check.fixCommand` 和 `check.fixRiskLevel` 提取修复信息 — 这也是 Check 的行为
  - `isApplicable` 方法存在但模块的 `checks()` 方法自己做了版本/设备过滤
- **修复建议**: 将 `evaluate(actual:duration:)` 方法添加到 `AuditCheck`，让它自己决定 pass/fail/info，以及 `generateFixAction()` 方法让它自己生成修复方案。

### 问题 3: ReportGenerator — 函数过长，混合了格式化和数据计算
- **严重程度**: MEDIUM
- **SOLID违规**: SRP + 函数应该短小
- **文件**: `MacAudit/CLI/ReportGenerator.swift:7-94`（`generateMarkdown` 88 行）
- **描述**: `generateMarkdown` 单个函数做了：
  1. 系统信息表生成
  2. 统计汇总计算（pass/fail/warn/info/skip/error 计数）
  3. 按模块分组
  4. 每模块的表格渲染
  5. 可修复项摘要
  同时 `generateJSON`（54 行）重复了部分统计计算逻辑。两者的数据聚合（统计摘要）完全重复。
- **修复建议**: 提取 `AuditSummary` struct 统一计算统计数据，`generateMarkdown` 和 `generateJSON` 仅负责格式化。

### 问题 4: RiskLevel — 优秀的设计，但 color 属性位置不当
- **严重程度**: LOW
- **SOLID违规**: SRP（展示逻辑混入领域模型）
- **文件**: `MacAudit/Models/RiskLevel.swift:23-31`
- **描述**: `RiskLevel` 的 `color: ANSIColor` 属性将终端颜色逻辑硬编码在领域模型中。`ANSIColor` 是 CLI 展示概念，不应出现在 Core 领域层。如果 GUI 需要不同的颜色映射，这个设计就不适用了。
- **修复建议**: 将颜色映射移入 CLI 层的 extension（`RiskLevel+ANSIColor.swift`），Core 层的 `RiskLevel` 只保留领域语义。

### 问题 5: BaselineManager.diff — JSON 手动解析的脆弱性
- **严重程度**: MEDIUM
- **SOLID违规**: 告知而非询问
- **文件**: `MacAudit/CLI/BaselineManager.swift:51-115`（64 行）
- **描述**: `diff` 方法手动解析 JSON（`JSONSerialization.jsonObject` + 字典下标访问 + 类型转换），而不是反序列化为 `AuditResult` 模型再比较。这导致：
  - 无法利用 `AuditStatus` 的类型安全比较，只能用字符串 `"fail" == "pass"`
  - 无法利用已有的 `Codable` 基础设施
  - 字段名（`"checkId"`, `"status"`）是脆弱的字符串常量
- **修复建议**: 反序列化为 `[AuditResult]` 后做 diff，利用模型的 `status` 和 `checkId` 字段做类型安全比较。

## Philosophy 审查 — Tacit Knowledge

项目在模型层表现出"数据结构崇拜"的倾向 — `AuditCheck` 和 `AuditResult` 都是纯数据容器，行为被散布在 `AuditModule.runChecks`、`FixEngine`、`ReportGenerator` 等外部函数中。这是过程式编程的特征，不是面向对象编程。Clean Code 的核心教义是"对象封装数据和行为"，而这里的数据和行为被强制分离了。

好的方面是 `AuditModule` 协议的设计 — 它确实定义了一个清晰的边界，让模块可以独立实现。但 protocol extension 中的 `runChecks` 把模板方法和具体实现耦合在一起，阻碍了更灵活的策略替换。

## 本轮评分

| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| SRP | 4 | ReportGenerator 和 FixEngine 混合了格式化和业务逻辑 |
| OCP | 5 | AuditResult 的工厂方法模式尚可，但新增状态需改多处 |
| 告知非询问 | 3 | AuditCheck 是贫血模型，行为散布在外部函数中 |
| 策略模式 | 6 | AuditModule 协议是好的策略接口，但 runChecks 模板方法限制了灵活性 |
| 模板方法 | 5 | AuditModule extension 的 runChecks 是模板方法，但混合了展示逻辑 |
