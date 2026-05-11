# Expert 2: Uncle Bob — 清洁代码与架构审查 Round 1

## 审查焦点
SOLID 原则合规性 — 双模块对比（MacAudit vs MacAuditCore）

## 发现的问题

### 问题 1: 双模块漂移 — DIP/LSP 根本性违规
- **严重程度**: CRITICAL
- **SOLID违规**: SRP（架构层面）+ OCP
- **文件**: `MacAudit/Modules/NetworkSecurityModule.swift` vs `MacAuditCore/Modules/NetworkSecurityModule.swift`
- **描述**: 两个 target 各持一份 `NetworkSecurityModule`（CLI 版 503 行 vs Core 版 242 行）。CLI 版的 `description` 使用多行字符串字面量包含详尽的修复指南，Core 版使用简洁的单行文本。这意味着：
  - 审核逻辑（checks 定义）重复拷贝，修改一处必然遗忘另一处
  - 两份文件的 `sysctlParams` 数据必须手动同步
  - CLI 版有 `fixCommand` 和 `fixRisk` 但 Core 版部分缺失
- **修复建议**: 将模块定义数据（checks 列表）完全移入 `MacAuditCore`，CLI target 仅消费 Core 的 `public` API。描述文本作为可选的 `detailedDescription` 附加层，由 CLI target 通过 extension 注入。

### 问题 2: NetworkSecurityModule 违反 SRP — 单个 struct 承载三模块逻辑
- **严重程度**: HIGH
- **SOLID违规**: SRP
- **文件**: `MacAuditCore/Modules/NetworkSecurityModule.swift:3`（注释明确写着 "M2+M3+M8 合并"）
- **描述**: 文件注释自述"合并自 SecurityModule、NetworkModule、NetworkTuningModule"。一个 struct 同时负责：
  1. 系统安全机制（SIP、Gatekeeper、FileVault）—— M2
  2. 网络安全检测（SSH、AirPlay、SMB）—— M3
  3. 内核参数调优（sysctl）—— M8
  `checks()` 方法 160+ 行，混合三种完全不同的关注点。
- **修复建议**: 拆分为三个独立的 struct：`SecurityMechanismModule`、`NetworkSecurityModule`、`NetworkTuningModule`，各自实现 `AuditModule` 协议。

### 问题 3: AuditModule 协议的胖接口 — ISP 违规
- **严重程度**: MEDIUM
- **SOLID违规**: ISP（接口隔离原则）
- **文件**: `MacAudit/Models/AuditModule.swift:17-39`
- **描述**: `AuditModule` 协议要求实现者提供 `checks(for:device:)` 和 `run(version:device:executor:)`。但 `runChecks` 和 `runChecksParallel` 作为 protocol extension 的默认实现，包含了进度报告（`InteractiveUI`）、计时逻辑和结果分类逻辑。CLI 版直接耦合 `InteractiveUI`，Core 版使用 `ProgressHandler` 回调。消费者被迫依赖两种不同的进度报告机制。
- **修复建议**: 将 `runChecks` 提取为独立的 `CheckRunner` 服务类，进度报告通过协议注入（`ProgressReporter`），而非硬编码在 extension 中。

### 问题 4: ProgressCounter 与 AuditModule 的内聚性问题
- **严重程度**: LOW
- **SOLID违规**: SRP（辅助类放置位置）
- **文件**: `MacAudit/Models/AuditModule.swift:5-14`
- **描述**: `ProgressCounter`（线程安全计数器）定义在 `AuditModule.swift` 中，但它是 `runChecksParallel` 的实现细节，与模块协议定义无关。同时存在两份几乎相同的实现（CLI 版用 `OSAllocatedUnfairLock`，Core 版也用相同实现）。
- **修复建议**: 将 `ProgressCounter` 移入独立的 `Concurrency/` 子目录，或在 Core 中只保留一份，CLI 通过 import Core 使用。

## Philosophy 审查 — Tacit Knowledge

双模块架构的背后假设是"CLI 和 GUI 需要不同的模块实现"。但真正不同的只是**展示层**（进度报告方式、描述详细程度），而非**检测逻辑**。这是一个典型的架构边界误判 — 把"消费者不同"等同于"生产者不同"。正确的架构应该是：核心检测逻辑在 Core（单一来源），展示差异通过策略模式或回调注入解决。

## 本轮评分

| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| SRP | 3 | NetworkSecurityModule 明确合并了三个关注点；双模块拷贝是 SRP 的系统性违反 |
| OCP | 4 | 添加新模块需同时修改两处代码；模块注册硬编码在 `MacAudit.swift` 和 `AppViewModel.swift` |
| LSP | 7 | AuditModule 协议的默认实现基本一致，无明显替换问题 |
| ISP | 4 | runChecks 和 runChecksParallel 混合了检测逻辑和进度展示逻辑 |
| DIP | 5 | ShellExecutor 通过 actor 注入（好），但 InteractiveUI 在 protocol extension 中硬编码（差） |
