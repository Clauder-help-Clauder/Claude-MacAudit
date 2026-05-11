# Expert 2: Uncle Bob — 清洁代码与架构审查 Round 3

## 审查焦点
代码清洁度与命名

## 发现的问题

### 问题 1: ShellExecutor 两份实现存在行为差异
- **严重程度**: HIGH
- **SOLID违规**: DRY（Don't Repeat Yourself）
- **文件**: `MacAudit/Utils/ShellExecutor.swift`（147 行）vs `MacAuditCore/ShellExecutor.swift`（145 行）
- **描述**: 两份实现的核心差异：
  1. CLI 版用 `OnceFlag` + `DispatchQueue.global().asyncAfter` 做超时；Core 版用 `TaskGroup` + `Task.sleep` 竞争
  2. CLI 版用 `Task.detached` 读管道；Core 版用结构化 `Task<Data, Error>`
  3. CLI 版的 `OnceFlag` 用 `NSLock`；Core 版完全不同
  4. 两者对超时后管道读取任务的处理方式不同（CLI 显式 cancel，Core 在 catch 中 cancel）

  这不是"两份相似代码"的问题，而是**两套并发模型**做同一件事。行为差异可能导致微妙的竞态条件。
- **修复建议**: 统一为 Core 版的实现（使用 Swift structured concurrency），CLI 版通过 import Core 使用。

### 问题 2: FixEngine.generateUndoCommand — 过长的正则函数
- **严重程度**: MEDIUM
- **SOLID违规**: 函数应该短小
- **文件**: `MacAudit/CLI/FixEngine.swift:157-184`
- **描述**: `generateUndoCommand` 函数 28 行，混合了正则匹配、字符串切片、类型标志提取和 fallback 逻辑。正则模式 `#"^(sudo\s+)?defaults\s+(write|delete)\s+(\S+)\s+(\S+)"#` 硬编码在函数体内。
- **修复建议**: 提取为 `DefaultsCommandParser` 小类，将正则匹配、类型提取和 undo 生成拆分为三个职责单一的函数。

### 问题 3: AppViewModel 中的魔法字符串和硬编码模块 ID
- **严重程度**: MEDIUM
- **SOLID违规**: 命名 — 意图不明确
- **文件**: `AppViewModel.swift:135-137`
- **描述**: 评分逻辑中硬编码了排除模块：
  ```swift
  $0.moduleId != "services" &&
  $0.moduleId != "dev" &&
  $0.moduleId != "animation" &&
  ```
  这些字符串散布在 `systemScore`、`rebuildModuleSummaries`、`performAudit` 三处。如果新增一个"个人偏好"模块，需要在这三处都添加排除。
- **修复建议**: 在 `AuditModule` 协议中添加 `var affectsSystemScore: Bool { get }` 属性，或用 `Set<String>` 常量集中定义排除列表。

### 问题 4: NetworkSecurityModule.checks() — 函数过长
- **严重程度**: HIGH
- **SOLID违规**: 函数应该短小（Clean Code §3）
- **文件**: `MacAudit/Modules/NetworkSecurityModule.swift:71-498`（CLI 版，`checks()` 方法 427 行）
- **描述**: 这个方法包含了 40+ 个 `AuditCheck` 实例的直接构造，每个都内嵌了多行 description 文本。整个方法体是纯粹的配置数据，但被组织为命令式代码。这是"数据与逻辑混合"的典型案例。
- **修复建议**: 将检查项定义提取为声明式数据（JSON/YAML 配置文件或静态数组），`checks()` 仅做过滤和组装。

### 问题 5: 命名质量审查 — 好的与坏的
- **严重程度**: LOW
- **SOLID违规**: 有意义的命名
- **文件**: 多处
- **描述**:
  - **好**: `AuditModule`, `ShellExecutor`, `RiskLevel`, `AuditRunner` — 意图清晰
  - **好**: `runChecksParallel` vs `runChecks` — 区分明确
  - **坏**: `wifiQ`（NetworkSecurityModule.swift:73）— 不明确的缩写，应为 `quotedWifiInterface`
  - **坏**: `m2.sip`, `m3.dns` — check ID 命名前缀混合了模块编号和功能名，`m2`/`m3` 对新开发者无意义
  - **坏**: `safeActions` 在 `FixEngine` 和 `MacAudit.run()` 中有不同的过滤条件（前者 `<= .low && !sudo`，后者相同但上下文不同）
  - **坏**: `SysctlDef` 的 init 参数全部匿名（`_ param: String, _ expected: String`），调用时无法从调用点推断参数含义

## Philosophy 审查 — Tacit Knowledge

代码中最大的清洁度问题是**数据与行为的混合**。`NetworkSecurityModule` 的 `checks()` 方法本质上是"返回一个静态数据列表"，但被实现为包含 400+ 行命令式代码的方法。这是典型的"Data Builder 反模式" — 当你有一个函数 90% 是数据定义、10% 是逻辑时，应该把数据提升到配置层面。

## 本轮评分

| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 命名 | 6 | 顶层类型命名好，局部变量和参数命名有改善空间 |
| 函数设计 | 3 | checks() 方法 427 行是 Clean Code 禁忌 |
| DRY | 3 | ShellExecutor 和 AuditModule 存在完整重复 |
| 注释质量 | 5 | NetworkSecurityModule 顶部的崩溃历史注释有价值，但过多内联修复指南应外化 |
| 死代码 | 7 | 未见明显死代码，但 `generateRepairScript()` 标注为"旧版保留" |
