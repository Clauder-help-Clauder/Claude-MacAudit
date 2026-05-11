# Expert 2: Uncle Bob — 清洁代码与架构审查 Round 2

## 审查焦点
架构边界与依赖方向

## 发现的问题

### 问题 1: CLI Target 反向依赖 — 架构层次穿透
- **严重程度**: CRITICAL
- **SOLID违规**: DIP（依赖倒置原则）
- **文件**: `Package.swift:15-25` + `MacAudit/Sources/MacAudit/MacAudit.swift:40-53`
- **描述**: `MacAudit`（CLI executable）同时依赖 `MacAuditCore`（通过 Package.swift 的 dependencies）**并且**自己持有完整的模块实现（`Sources/MacAudit/Modules/`）。这造成：
  - CLI target 可以 import MacAuditCore 的模块，也可以用自己的模块
  - 两者之间存在微妙的行为差异（如 Core 版的 `SysctlDef` 缺少 `isReadOnlyIPv6` 的 `mergedDesc` 逻辑）
  - `MacAudit.swift:40` 硬编码了 12 个模块实例化列表，`AppViewModel.swift:146` 又重复了一份
- **修复建议**: CLI target 的 `Modules/` 目录应完全删除。所有模块定义移入 MacAuditCore。MacAudit target 仅包含 CLI 入口、UI 适配器和 terminal-specific 代码。

### 问题 2: AppViewModel 是一个 637 行的 God Object
- **严重程度**: CRITICAL
- **SOLID违规**: SRP
- **文件**: `MacAudit/Sources/MacAuditUI/ViewModels/AppViewModel.swift`（637 行）
- **描述**: `AppViewModel` 同时承担了：
  1. 导航状态管理（`selectedScreen`, `selectedCheckId`）
  2. 偏好设置持久化（`preferredVersion`, `preferredDevice`, UserDefaults）
  3. 审计执行编排（`startAudit`, `performAudit`, `cancelAudit`）
  4. 结果聚合与评分（`systemScore`, `moduleSummaries`, `rebuildModuleSummaries`）
  5. 脚本生成（6 个不同的 `generate*Script()` 方法，约 140 行）
  6. 快照持久化（`saveAuditToDisk`, `loadSavedSnapshot`, `restoreFromSnapshot`）
  7. 单模块刷新逻辑
  8. Checks 缓存
- **修复建议**: 拆分为至少 4 个类型：
  - `NavigationState`（导航）
  - `AuditOrchestrator`（执行编排）
  - `RepairScriptGenerator`（脚本生成）
  - `AuditSnapshotStore`（持久化）

### 问题 3: AuditRunner 存在两份独立实现
- **严重程度**: HIGH
- **SOLID违规**: DRY + DIP
- **文件**: `MacAudit/CLI/AuditRunner.swift`（130 行）vs `MacAuditCore/AuditRunner.swift`（48 行）
- **描述**: CLI 版的 `AuditRunner` 包含交互式菜单逻辑（`interactive` 模式、键盘输入处理 `TerminalInput`），Core 版是纯数据执行。但两者的核心功能（`runAll`, `runModule`）高度重复。CLI 版的 `init` 有 6 个参数，`runAll()` 方法内嵌了 65 行的 UI 展示和交互逻辑。
- **修复建议**: CLI 的 `AuditRunner` 应组合 Core 的 `AuditRunner`，仅装饰交互式 UI 逻辑。用 Decorator 模式而非复制。

### 问题 4: MacAuditApp launcher 的架构价值不清
- **严重程度**: LOW
- **SOLID违规**: 无（设计合理但过度）
- **文件**: `MacAudit/Sources/MacAuditApp/MacAuditApp.swift`（14 行）
- **描述**: `MacAuditApp` 是一个 14 行的薄 launcher，仅调用 `makeMacAuditRootView()`。`PublicEntry.swift` 也只有 8 行。这种 3 层 target 分离（MacAuditApp → MacAuditUI → MacAuditCore）在理论上正确，但 `PublicEntry` 的间接层几乎无价值 — 没有任何框架初始化或配置逻辑。
- **修复建议**: 可接受。如果未来需要 framework 初始化逻辑（如 DI 容器配置），此间接层才有价值。当前可作为前瞻性设计保留。

## Philosophy 审查 — Tacit Knowledge

架构最大的隐性问题是**模块注册的去中心化**。模块列表在三个地方硬编码：`MacAudit.swift:40`、`AppViewModel.swift:146`、以及潜在的 Core 层。这意味着每次新增模块需要修改至少 2-3 个文件。在 Clean Architecture 中，这应该通过**插件式注册**解决 — 模块通过配置文件或自动发现机制注册，而非硬编码在多个入口点。

## 本轮评分

| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| SRP | 2 | AppViewModel 637 行 God Object 是教科书级 SRP 违规 |
| OCP | 3 | 新增模块需修改 3 个文件的硬编码列表 |
| DIP | 3 | CLI 绕过 Core 直接实现模块，架构层次形同虚设 |
| 边界清晰度 | 2 | 双模块漂移 + 双 AuditRunner = 架构边界被系统性地绕过 |
| 依赖方向 | 4 | 依赖方向正确（外→内），但 CLI 不尊重内层的权威性 |
