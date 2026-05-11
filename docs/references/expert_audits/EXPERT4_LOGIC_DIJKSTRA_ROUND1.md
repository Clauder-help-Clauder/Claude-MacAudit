# Expert 4: Dijkstra — 形式逻辑与正确性审查 Round 1

## 审查焦点
状态机逻辑与转换正确性

## 发现的问题

### 问题 1: cancelAudit 中 isScanning 被强制置 false 但 defer 块仍会执行
- **严重程度**: HIGH
- **逻辑类型**: 状态机
- **文件**: AppViewModel.swift:179-184 vs 171-177
- **形式化描述**: `cancelAudit()` 将 `isScanning = false` 并设 `auditTask = nil`。但 `performAudit` 内部的 `defer { isScanning = false }` 在 Task 被取消后仍可能触发，导致对已置 false 的状态再次置 false。虽然结果正确（幂等），但逻辑上 `cancelAudit` 在 `auditTask = nil` 后 `isScanning` 的真实值取决于 Task 取消的时序——存在一个时间窗口 `isScanning` 为 true 但 `auditTask` 已为 nil，构成不一致状态。
- **反例**: 用户调用 `cancelAudit()` → `auditTask = nil` → `isScanning = false` → 但 Task 的 defer 在 MainActor 排队稍后执行 → 此时 `isScanning` 已被 cancelAudit 设为 false，defer 再次执行无副作用但语义上不精确。
- **修复建议**: 在 `performAudit` 的 `defer` 中检查 `Task.isCancelled`，或统一由 `performAudit` 的 defer 管理 `isScanning`，`cancelAudit` 仅调用 `auditTask?.cancel()`。

### 问题 2: performAudit 未清理中间状态即 guard return
- **严重程度**: MEDIUM
- **逻辑类型**: 状态机
- **文件**: AppViewModel.swift:231
- **形式化描述**: `guard !Task.isCancelled else { return }` 在取消时直接返回，但此时 `isScanning` 由 defer 置 false，`results` 和 `moduleSummaries` 包含部分数据，`selectedScreen` 仍为 `.scanning`。用户看到的是扫描视图但不完整的数据。
- **反例**: 12个模块中扫描完6个后取消 → results 有6个模块数据 → selectedScreen 仍为 .scanning → 用户回到 dashboard 后点击其他操作，但残留的 results 导致 systemScore 计算基于不完整数据。
- **修复建议**: 取消时重置 `results = []`, `moduleSummaries = []`, `selectedScreen = .dashboard`。

### 问题 3: runSingleModule 与 startAudit 的互斥保护不完整
- **严重程度**: MEDIUM
- **逻辑类型**: 状态机/并发
- **文件**: AppViewModel.swift:475-507 vs 169-177
- **形式化描述**: `runSingleModule` 用 `guard !isScanning` 防止与全局审查并发。但 `startAudit` 内部用 `guard !isScanning` 保护后又设 `isScanning = true`，两者都是 MainActor 上的原子检查-设置。然而 `refreshModule` (line 512) 没有互斥保护，可与其他操作并发修改 `results`。
- **反例**: 用户在 `runSingleModule` 执行过程中调用 `refreshModule`（如 UI 上的服务 toggle）→ 两者同时 `results.removeAll` + `results.append` → 结果不可预测。
- **修复建议**: 为 `refreshModule` 添加与 `runSingleModule` 相同的 `singleModuleRunning` / `isScanning` 检查。

### 问题 4: MenuController 的 lastResults 在多次操作间无状态隔离
- **严重程度**: LOW
- **逻辑类型**: 状态机
- **文件**: MenuController.swift:37-38
- **形式化描述**: `lastResults` 在 `runSingleModule` 和 `runFullAudit` 中被覆盖，但 `exportMarkdown` 检查 `fullAuditDone` 标志。若用户先运行单模块审查（设置 lastResults），再运行全面审查但中途退出，`fullAuditDone` 仍为 false，但 `lastResults` 已被部分更新。
- **反例**: 用户选单模块审查 → lastResults = [moduleA results] → 再选全面审查但中途 quit → fullAuditDone = false → lastResults 包含部分全面审查数据 → 导出不可用（正确行为），但菜单显示的"上次审查"统计是错误的混合数据。
- **修复建议**: 全面审查开始时重置 `fullAuditDone = false`，仅在 `runAll()` 完成后设为 true。

### 问题 5: AuditRunner.runAll 在 interactive 模式下的 break 路径导致结果不完整
- **严重程度**: MEDIUM
- **逻辑类型**: 状态机/控制流
- **文件**: AuditRunner.swift:73-91
- **形式化描述**: interactive 模式下按 'q' 或 ESC 时，先 `allResults.append(contentsOf: results)` 再 `break`。但 break 后不再执行 line 94 的 append，逻辑正确。然而当 `isLast == true` 时，break 被条件阻止（`if !isLast`），最后一个模块的结果无论如何都会被追加。控制流正确但分支复杂度过高。
- **反例**: 无具体反例，但 6 条 break/continue 路径使形式化验证困难。
- **修复建议**: 提取 interactive 逻辑为独立方法，降低循环内分支复杂度。

## Philosophy 审查 — 程序哲学

> "Simplicity is prerequisite for reliability." — Dijkstra

AppViewModel 的状态空间过大：`isScanning × singleModuleRunning? × selectedScreen × results.count` 构成笛卡尔积。一个拥有 637 行的方法同时管理导航、审计执行、结果存储、脚本生成和持久化。这不是模块化——这是意大利面条。

正确的做法：将状态机显式建模为枚举 + 转换函数，使非法状态不可表示（make illegal states unrepresentable）。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 状态完备性 | 5 | 取消路径的状态清理不完整 |
| 边界安全 | 6 | 互斥保护有遗漏 |
| 算法正确性 | 7 | 评分计算逻辑正确 |
| 并发安全 | 6 | MainActor 保护了大部分，但 refreshModule 漏洞 |
| 逻辑简洁性 | 4 | AppViewModel 职责过多，状态隐式管理 |
