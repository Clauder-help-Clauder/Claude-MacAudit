# Expert 4: Dijkstra — 形式逻辑与正确性审查 Round 4

## 审查焦点
并发逻辑正确性

## 发现的问题

### 问题 1: ShellExecutor 作为 actor 的串行化瓶颈
- **严重程度**: HIGH
- **逻辑类型**: 并发/性能
- **文件**: ShellExecutor.swift:31
- **形式化描述**: `ShellExecutor` 是 `actor`，所有方法调用串行执行。当 `runChecksParallel` (AuditModule.swift:96) 并行执行 N 个 check 时，每个 check 调用 `executor.run()`，由于 actor 隔离，实际执行是串行的——N 个 `await executor.run()` 被逐一串行处理。
- **反例**: `runChecksParallel` 用 TaskGroup 并行调度 50 个 check，但 `ShellExecutor` actor 将它们串行化 → 实际耗时 = sum(每个命令耗时) 而非 max(每个命令耗时)。并行化被完全抵消。
- **修复建议**: 将 `ShellExecutor` 改为普通 `final class` + 使用 `nonisolated` 方法，或使用 Task-local executor 池。最少应确认 `runChecksParallel` 调用时传入的 executor 是否被串行化。

### 问题 2: AuditModule.runChecksParallel 中 TaskGroup 子任务共享同一 ShellExecutor actor
- **严重程度**: HIGH
- **逻辑类型**: 并发/数据竞争
- **文件**: AuditModule.swift:106-143
- **形式化描述**: `runChecksParallel` 在 `withTaskGroup` 中创建多个子任务，每个子任务调用 `await executor.run()`。由于 `ShellExecutor` 是 actor，子任务不会产生数据竞争（actor 保证互斥）。但问题是 `ProgressCounter` 使用 `@unchecked Sendable` + `OSAllocatedUnfairLock`，而 `InteractiveUI.updateProgress` 可能在不同并发上下文中被调用。若 `InteractiveUI` 内部有共享状态（如终端光标位置），则存在竞争。
- **反例**: 两个 TaskGroup 子任务同时完成 → 同时调用 `counter.increment()` → lock 保护了 counter → 但 `InteractiveUI.updateProgress` 内部若使用 `print()` 则输出交错。
- **修复建议**: 确认 `InteractiveUI.updateProgress` 是线程安全的。若使用 `print()`，应改用 `flockfile/funlockfile` 或串行队列。

### 问题 3: FixHistory.saveBatch 非原子写入导致数据损坏
- **严重程度**: HIGH
- **逻辑类型**: 并发/不变量
- **文件**: FixHistory.swift:36-42
- **形式化描述**: `saveBatch` 先 `loadAll()` → `append` → `encode` → `write`。这不是原子操作：若两个进程/任务同时调用 `saveBatch`，两者都读到相同的旧数据 → 各自 append → 后写入者覆盖先写入者的数据。
- **反例**: 用户在 CLI 执行修复的同时 GUI 也在执行修复 → 两个 `saveBatch` 并发 → 一个批次的记录丢失。
- **修复建议**: 使用文件锁（`flock` 或 `NSFileCoordinator`）或原子写入（write-to-temp + rename）。

### 问题 4: AppViewModel.startAudit 中 Task 与 defer 的交互
- **严重程度**: MEDIUM
- **逻辑类型**: 并发/任务取消
- **文件**: AppViewModel.swift:171-177
- **形式化描述**: `auditTask = Task { [weak self] in ... defer { isScanning = false } ... }` 创建非结构化并发任务。`cancelAudit()` 调用 `auditTask?.cancel()`。Swift 的 Task.cancel() 是协作式的：它设置取消标志但不中断执行。`performAudit` 内部的 `await runner.runAll()` 需要内部检查取消状态才能实际停止。`AuditRunner.runAll` 不检查 `Task.isCancelled`——它只在最后检查一次（line 231）。
- **反例**: 用户在 12 个模块的扫描中第 3 个模块时取消 → `cancelAudit()` 被调用 → `process.terminate()` 不被触发 → `runAll` 继续执行到第 12 个模块 → `guard !Task.isCancelled` 在最后才触发 → 用户等待全部模块完成。
- **修复建议**: 在 `AuditRunner.runAll` 的循环中每轮迭代检查 `Task.isCancelled`。

### 问题 5: NetworkSecurityModule 的 checks() 每次调用都重建大量 AuditCheck
- **严重程度**: LOW
- **逻辑类型**: 性能/不变量
- **文件**: NetworkSecurityModule.swift:77-237
- **形式化描述**: `checks(for:device:)` 每次调用创建 30+ 个 `AuditCheck` 实例（含正则、字符串拼接）。在 `AppViewModel` 中，`check(for:)` 缓存了结果，但 `systemScore` 计算（每次 results 变更时重新计算）和 `allFixActions()` 都调用 `allModules.flatMap { $0.checks(...) }`。当 `moduleFixCounts` 和 `repairActionCounts` 在 View body 中被访问时，每次 SwiftUI 渲染都触发 `checks()` 重建。
- **反例**: 12 个模块 × 476+ checks → 每次 View 渲染创建 ~5700 个 AuditCheck 实例。在动画或滚动时可能导致掉帧。
- **修复建议**: 在 `AppViewModel` 中全局缓存 `allChecks`，或让模块惰性初始化 checks 列表。

### 问题 6: @Sendable 合规 — PrivacyModule.defs 是实例属性但模块是 struct
- **严重程度**: LOW
- **逻辑类型**: 并发/Sendable
- **文件**: PrivacyModule.swift:25
- **形式化描述**: `PrivacyModule` 是 `public struct` 且遵循 `AuditModule: Sendable`。`defs` 是 `[PrivacyDef]` 类型的 `private let`。`PrivacyDef` 不是 `Sendable` 的（它是 private struct，无显式一致性）。在 Swift 6 strict concurrency 下，非 Sendable 类型作为 struct 的存储属性可能导致编译警告/错误。
- **反例**: Swift 6 编译器可能拒绝将 `PrivacyModule` 作为 `any AuditModule` 传递跨 actor 边界，因为 `PrivacyDef` 未标记 `Sendable`。
- **修复建议**: 为 `PrivacyDef` 和 `SysctlDef` 添加 `Sendable` 一致性。

## Philosophy 审查 — 程序哲学

> "If debugging is the process of removing bugs, then programming must be the process of putting them in." — Dijkstra

`ShellExecutor` 作为 actor 提供了安全性保证（无数据竞争），但同时也扼杀了并行性。这是一个经典的安全与性能的权衡。然而，正确的做法不是放弃安全——而是重新设计抽象。一个 `nonisolated` 的 shell 执行函数（每个调用创建独立的 Process）天然无共享状态，因此无需 actor 隔离。当且仅当存在真正的共享可变状态时，才需要互斥。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 状态完备性 | 6 | 取消传播不完整 |
| 边界安全 | 7 | actor 隔离提供了基本保证 |
| 算法正确性 | 7 | 并行化被串行化抵消 |
| 并发安全 | 5 | FixHistory 非原子、ProgressCounter 的 InteractiveUI 依赖 |
| 逻辑简洁性 | 6 | actor 语义正确但语义与意图不符 |
