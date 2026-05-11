# Expert 2: Uncle Bob — 清洁代码与架构审查 Round 5

## 审查焦点
架构哲学综合评分与重构路线图

## 综合评分

| 维度 | R1 | R2 | R3 | R4 | 加权均分 | 权重 |
|------|:--:|:--:|:--:|:--:|:--------:|:----:|
| SRP | 3 | 2 | 3 | 4 | **3.0** | 20% |
| OCP | 4 | 3 | — | 5 | **4.0** | 15% |
| DIP | 5 | 3 | — | — | **4.0** | 15% |
| 命名 | — | — | 6 | — | **6.0** | 10% |
| 函数设计 | — | — | 3 | 5 | **4.0** | 15% |
| 架构边界 | — | 2 | — | — | **2.0** | 15% |
| 设计模式 | — | — | — | 5 | **5.0** | 10% |

**综合评分: 3.65 / 10** — 功能可用但架构债务严重

## 核心架构缺陷总结

### 缺陷 1: 双模块是架构的根本性错误（CRITICAL）
不是"维护负担"问题，而是对"Single Source of Truth"原则的根本违反。CLI 和 Core 各持一份模块代码，意味着任何修改都有 50% 概率只改了一半。这不是可以用文档或纪律解决的问题 — 它是结构性缺陷。

### 缺陷 2: AppViewModel 是 God Object（CRITICAL）
637 行的 ViewModel 违反了 Clean Architecture 的每一个层面。它同时是 Use Case、Presenter、Data Gateway 和 Navigation Controller。这是"快速原型"的典型产物。

### 缺陷 3: 贫血模型导致行为散布（HIGH）
`AuditCheck` 和 `AuditResult` 是纯数据容器，评估逻辑在 `runChecks` 中，修复逻辑在 `FixEngine` 中，报告逻辑在 `ReportGenerator` 中。这创造了跨文件的隐式耦合。

## 重构路线图

### Phase 1: 消除双模块（2-3 天，最高优先级）

```
Before:                          After:
MacAudit/Modules/*.swift    →    删除
MacAuditCore/Modules/*.swift →   MacAuditCore/Modules/*.swift（唯一来源）
```

**步骤**:
1. 将 CLI 版的 `detailedDescription`（多行修复指南）提取为 `MacAuditCore/Modules/Descriptions/` 下的独立资源
2. `AuditCheck` 新增 `var detailedDescription: String?` 字段
3. CLI target 通过 `import MacAuditCore` 使用 Core 的模块
4. 删除 `MacAudit/Sources/MacAudit/Modules/` 整个目录

### Phase 2: 拆分 AppViewModel（3-5 天）

```
AppViewModel (637行)
  ├── NavigationState       (~50行)
  ├── AuditOrchestrator     (~120行)
  ├── RepairScriptGenerator (~140行)
  ├── AuditSnapshotStore    (~80行)
  └── AppViewModel          (~150行，仅协调)
```

**步骤**:
1. 提取 `AuditSnapshotStore`（save/load/restore）
2. 提取 `RepairScriptGenerator`（6 个 generate 方法）
3. 提取 `AuditOrchestrator`（startAudit/performAudit/cancelAudit）
4. AppViewModel 仅保留导航状态和偏好设置

### Phase 3: 赋予模型行为（2-3 天）

1. `AuditCheck.evaluate(actual:duration:) -> AuditResult` — 让 Check 自己决定 pass/fail
2. `AuditCheck.fixAction(currentValue:) -> FixAction?` — 让 Check 自己生成修复方案
3. `AuditModule` protocol 简化为 `func checks(for:device:) -> [AuditCheck]` + `func run` 使用默认实现调用 `evaluate`

### Phase 4: 模块注册去中心化（1-2 天）

```swift
// MacAuditCore/ModuleRegistry.swift
public struct ModuleRegistry {
    private static var modules: [any AuditModule] = []
    public static func register(_ module: any AuditModule) { modules.append(module) }
    public static var all: [any AuditModule] { modules }
}

// 每个模块文件底部
ModuleRegistry.register(NetworkSecurityModule())
```

或者用更 Swift 惯用的方式：
```swift
// MacAuditCore/AllModules.swift
public let allModules: [any AuditModule] = [
    SystemInfoModule(),
    NetworkSecurityModule(),
    // ...
]
```

### Phase 5: 消除 ShellExecutor 重复（1 天）

删除 `MacAudit/Utils/ShellExecutor.swift`，统一使用 `MacAuditCore/ShellExecutor`。

## Philosophy 审查 — Tacit Knowledge

这个项目的核心矛盾是：**架构意图正确（4 层 target 分离），但执行被便利性侵蚀**。每次开发者需要"快速添加一个检查项"时，同时修改两份文件太麻烦，于是接受了双模块漂移。这不是技术能力问题，而是架构纪律问题。

Clean Architecture 不是关于"画出正确的盒子图"，而是关于**依赖规则的实际执行**。如果你画了 MacAuditCore 层但 CLI 绕过它直接实现模块，那 Core 层就是装饰品。

Boy Scout Rule 的实践建议：每次新增检查项时，花 5 分钟把一项重复代码消除。5 个 Phase 不需要一次性完成，但方向必须明确。

## 最终评分

| 维度 | 评分(1-10) | 一句话总结 |
|------|-----------|----------|
| 整体架构 | 3 | 层次存在但不被尊重，双模块是结构性债务 |
| SOLID 合规 | 3.5 | SRP 系统性违反，DIP 被便利性绕过 |
| 代码清洁度 | 5 | 局部质量尚可（命名、结构），但函数过长和重复拖了后腿 |
| 可维护性 | 3 | 新增模块需改 3+ 个文件，双模块同步是定时炸弹 |
| 重构可行性 | 7 | 好消息是架构意图正确，重构路径清晰，不需要推翻重来 |

**总评: 3.65/10 — "能跑但需要大手术"**
