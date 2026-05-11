# Expert 5: Kent Beck — TDD与开发者体验审查 Round 5

## 审查焦点
综合评分与TDD改进路线图

## 项目总体 TDD 成熟度评估

### 优势
1. **FixEngineTests 是教科书级别的 TDD 示范**：mock 注入、confirm 闭包依赖注入、四象限测试、边界条件覆盖、tmpDir+UUID 隔离。如果整个项目的测试都达到这个水平，评分会高很多。
2. **ServicesModule run() 测试**：三路分支（disabled/enabled/unmanaged）+ mock executor + 结果数量验证，是模块行为测试的好例子。
3. **HANDOFF.md 的 Known Gotchas**：将隐性的调试知识显性化，这对新开发者上手极其重要。
4. **Swift Testing 框架使用得当**：`@Test` + `#expect` 的可读性优于 XCTest。
5. **测试总数 484 个且全绿**：说明团队重视测试，且有持续维护。

### 核心缺陷
1. **80% 的测试在验证数据结构，不是系统行为**
2. **Mock 使用不一致**：FixEngine 用了完美 mock，ShellExecutor 却用真实进程
3. **双模块代码复制**让测试价值减半
4. **ResultsViewModel 测试重写了被测逻辑**

## 综合评分

| 维度 | R1 | R2 | R3 | R4 | 综合 | 说明 |
|------|----|----|----|----|------|------|
| 测试质量 | 4 | 5 | 7 | 6 | **5.5** | 高低差距大，FixEngineTests 优秀但其他文件平庸 |
| 测试覆盖 | 5 | 6 | 7 | 5 | **5.8** | 结构覆盖>80%，行为覆盖<30% |
| 简单设计 | 6 | 6 | 6 | 4 | **5.5** | AuditCheck 设计合理；双模块复制是最大违反 |
| 开发者体验 | 5 | 5 | 6 | 8 | **6.0** | HANDOFF.md 是亮点；构建体验良好 |
| 重构信心 | 3 | 4 | 7 | 5 | **4.8** | 模块内部重构信心不足；FixEngine 重构信心高 |
| **总评** | | | | | **5.5/10** | 及格但有很大改进空间 |

## TDD 改进路线图

### Phase 1: 立即可做（1-2天）

1. **删除无价值的 getter/setter 测试**
   - 文件：`AuditCheckTests.swift` 前12个测试
   - 原因：测试 Swift struct 属性系统，不是测试业务逻辑
   - 保留：`isApplicable` 四象限测试和 `AuditResult` 工厂方法测试

2. **修复 ResultsViewModel 测试**
   - 文件：`ResultsViewModelTests.swift`
   - 问题：本地重写 `sortResultsFailFirst()` 而非测试真实代码
   - 方案：直接测试 ViewModel 的真实方法

3. **用 ID 而非中文名称查找 check**
   - 文件：`AnimationModuleTests.swift`
   - 问题：`$0.name == "启动弹跳动画"` 在本地化修改后断裂
   - 方案：`$0.id == "m5.xxx"`

### Phase 2: 短期改进（1周）

4. **统一 Mock 策略**
   - 提取 `ShellExecutor` 为协议，创建 `MockShellExecutor`
   - 所有涉及 shell 调用的测试统一使用 mock
   - 仅保留 2-3 个集成测试使用真实 shell

5. **提取共享测试工具**
   - 创建 `TestHelpers.swift`：共享 `TestModule`、`makeCheck()`、`makeResult()`
   - 消除 `AuditRunnerTests` 和 `IntegrationTests` 之间的重复

6. **添加 expectations.json 配置加载测试**
   - 验证 JSON 解析、覆盖逻辑、跳过逻辑

### Phase 3: 中期重构（2-3周）

7. **消除双模块代码复制**
   - 统一模块代码到 `MacAuditCore/Modules/`
   - CLI target 通过 `import MacAuditCore` 引用
   - 这是提升重构信心的最关键一步

8. **添加行为驱动的测试**
   - 每个模块至少3个行为测试：
     - "当检测命令返回期望值时，结果为 pass"
     - "当检测命令返回非期望值时，结果为 fail"
     - "当检测命令超时/失败时，结果为 error/warn"
   - 使用 mock executor 验证，不依赖真实 shell

9. **拆分测试 target**
   - `MacAuditCoreTests`（单元测试，纯逻辑）
   - `MacAuditCLITests`（CLI 集成测试）
   - `MacAuditUITests`（ViewModel/View 测试）

## Tacit Knowledge 综合洞察

这个项目的测试让我想起一句话："测试覆盖率不是目的，信心才是。" 484个测试听起来很多，但当你问"如果我重构了 AnimationModule 的内部实现，测试能告诉我行为是否改变了吗？"答案是：不能。因为大部分测试在验证"有多少个 check"、"ID 是否有前缀"，而不是"当系统处于状态X时，行为Y是否发生"。

最让我欣慰的是 FixEngineTests——它展示了团队完全理解 TDD 的正确方式。问题不是能力，而是优先级。模块测试选择了最容易写的路径（验证数据结构），而不是最有价值的路径（验证行为）。

**一句话总结**：减少一半的结构性测试，把精力投入行为测试。500个测试中有200个验证行为，比500个都验证结构有价值得多。

---

*Kent Beck, 2026-04-21*
*"Simple Made Easy — 简单设计是所有复杂问题的终极解决方案"*
