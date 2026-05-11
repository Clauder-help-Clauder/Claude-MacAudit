# Expert 4: Dijkstra — 形式逻辑与正确性审查 Round 5

## 审查焦点
形式逻辑综合评分与解决方案

## 综合评分

| 维度 | R1 | R2 | R3 | R4 | 综合 | 说明 |
|------|:--:|:--:|:--:|:--:|:----:|------|
| 状态完备性 | 5 | 6 | 7 | 6 | **6** | 状态机隐式管理，取消路径不完整 |
| 边界安全 | 6 | 5 | 5 | 7 | **5.5** | IP 验证缺失、超时溢出、重复 key 崩溃 |
| 算法正确性 | 7 | 7 | 6 | 7 | **6.75** | undo 生成缺陷、比较语义不足 |
| 并发安全 | 6 | 7 | 7 | 5 | **6.25** | actor 串行化瓶颈、非原子写入 |
| 逻辑简洁性 | 4 | 7 | 6 | 6 | **5.75** | AppViewModel 职责过重 |

**总体形式正确性评分: 6.1 / 10**

---

## CRITICAL 问题汇总（必须修复）

### C1: DNSBLChecker 不验证 IP 格式 (R2-P4)
```swift
static func check(ip: String, executor: ShellExecutor) async -> [AuditResult] {
+   guard IPFetcher.isValidIPv4(ip) else {
+       let check = IPQualityModule().phaseCChecks()[0]
+       return [.error(check: check, error: "无效 IP 地址: \(ip)")]
+   }
    let reversed = ip.split(separator: ".").reversed().joined(separator: ".")
```

### C2: BaselineManager.diff 崩溃风险 (R3-P5)
```swift
- let oldMap = Dictionary(uniqueKeysWithValues: oldResults.compactMap { ... })
+ let oldMap = Dictionary(oldResults.compactMap { ... }, uniquingKeysWith: { $1 })
```

### C3: FixHistory.saveBatch 非原子写入 (R4-P3)
```swift
func saveBatch(_ batch: FixBatch) throws {
    try ensureDir()
    var batches = loadAll()
    batches.append(batch)
    let data = try JSONEncoder().encode(batches)
-   try data.write(to: URL(fileURLWithPath: historyPath))
+   let tmpURL = URL(fileURLWithPath: historyPath + ".tmp")
+   try data.write(to: tmpURL, options: .atomic)
+   try FileManager.default.moveItem(at: tmpURL, to: URL(fileURLWithPath: historyPath))
}
```

### C4: AuditRunner.runAll 不检查中途取消 (R4-P4)
```swift
for (i, module) in modules.enumerated() {
+   guard !Task.isCancelled else { break }
    let checkCount = module.checkCount(for: effectiveVersion, device: device)
```

---

## HIGH 问题汇总（强烈建议修复）

### H1: ShellExecutor 超时整数溢出 (R2-P1)
使用 `Duration.milliseconds` 或 `clamped(to:)` 代替手动转换。

### H2: cancelAudit 状态不一致 (R1-P1/P2)
统一由 `performAudit` 的 defer 管理 `isScanning`，取消时清理 `results` 和 `screen`。

### H3: generateUndoCommand 正则边界 (R3-P1)
扩展正则以处理引号包裹的 domain/key。

### H4: ShellExecutor actor 串行化抵消并行化 (R4-P1)
改为 `nonisolated` 方法或使用独立的 Process 不共享状态。

### H5: AuditModule.runChecks 的语义归一化缺失 (R3-P3)
添加 "1"/"YES" → "true" 的归一化层。

---

## 形式化不变量清单

项目应维护以下不变量，任何违反都应被检测：

| # | 不变量 | 当前状态 |
|---|--------|----------|
| I1 | `isScanning == true` ⟹ `results` 正在被写入，外部不可修改 | 违反：refreshModule 无互斥 |
| I2 | `results` 中的 `checkId` 在同一 `moduleId` 内唯一 | 未验证 |
| I3 | `systemScore` 返回 `[0, 100]` 范围内的整数 | 成立 ✓ |
| I4 | `ShellExecutor.run` 的 `exitCode >= 0` 或 `== -1`（超时） | 成立 ✓ |
| I5 | `DNSBLChecker.check` 的 IP 输入是有效 IPv4 | **违反** |
| I6 | `FixHistory` 文件不会被并发写入损坏 | **违反** |
| I7 | `cancelAudit()` 后 `isScanning == false` 且 `auditTask == nil` | 成立 ✓（幂等） |
| I8 | `moduleSummaries.count <= allModules.count` | **违反**：singleModuleRefresh 可添加新 summary |

---

## Philosophy 审查 — 程序哲学

> "The question of whether machines can think is about as relevant as the question of whether submarines can swim." — Dijkstra

这个项目的一个核心矛盾是：`ShellExecutor` 被设计为 actor（追求安全性），但其使用场景要求高并行度。这就像设计了一辆装甲车却发现它必须参加 F1 赛事。正确的抽象不是"给一切加锁"——而是消除共享状态的需求。每个 `Process` 是独立的 OS 进程，没有共享可变状态。因此 `ShellExecutor` 的方法不需要 actor 隔离。

Dijkstra 的最终忠告：

1. **前置条件必须被验证**——`isValidIPv4` 存在但未被调用是设计失败
2. **不变量必须被声明**——这个项目没有显式的不变量文档
3. **状态机必须被枚举**——AppViewModel 的隐式状态组合是 bug 的温床
4. **原子性必须被保证**——FixHistory 的非原子写入是数据损坏的定时炸弹

> "Simplicity is a great virtue but it requires hard work to achieve it and education to appreciate it." — Dijkstra

将 AppViewModel 拆分为 `NavigationStateMachine` + `AuditEngine` + `ReportService` 三个独立组件，每个组件的状态空间小到可以人工验证。这才是通向正确性的道路。

---

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 状态完备性 | 6 | 隐式不变量需显式化 |
| 边界安全 | 6 | CRITICAL 问题有明确修复方案 |
| 算法正确性 | 7 | 评分和比较逻辑基本正确 |
| 并发安全 | 6 | actor 模型需重新设计 |
| 逻辑简洁性 | 6 | 拆分方案已给出 |
