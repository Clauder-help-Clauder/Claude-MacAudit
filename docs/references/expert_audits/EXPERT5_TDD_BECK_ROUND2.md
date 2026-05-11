# Expert 5: Kent Beck — TDD与开发者体验审查 Round 2

## 审查焦点
测试隔离与可靠性 — NetworkSecurity / Services / ClaudeProtection / ShellExecutor

## 发现的问题

### 问题 1: ShellExecutor 测试直接调用真实 shell — 不是单元测试
- **严重程度**: CRITICAL
- **类型**: Flaky test风险
- **文件**: `MacAudit/Tests/MacAuditTests/ShellExecutorTests.swift:7-95`
- **描述**: 大量测试直接执行真实 shell 命令（`echo hello`, `sleep 10`, `exit 1`）。这些不是真正的单元测试——它们依赖真实进程 fork、环境变量、系统命令存在性。在 CI 环境、容器中、或受限沙箱中可能失败。`shellExecutorTimedOut` 测试要等100ms，`sleep 10` 在系统负载高时可能行为不同。
- **修复建议**: 将 ShellExecutor 的核心逻辑（输出解析、超时处理、结果构造）拆分为可单元测试的纯函数。仅保留2-3个集成测试验证真实 shell 行为，其余用协议抽象+mock。

### 问题 2: ServicesModule 的 run() 测试与 checks() 测试使用不同的 mock 路径
- **严重程度**: MEDIUM
- **类型**: 测试隔离
- **文件**: `MacAudit/Tests/MacAuditTests/ServicesModuleTests.swift:156-195`
- **描述**: `run()` 测试使用 `ShellExecutor(stubbedOutputs:)` mock，而 `checks()` 测试直接实例化模块。这是两种不同的测试策略混用——如果 mock 的 key（如 `"launchctl print-disabled"`）与产品代码中的实际命令不匹配，测试会给出错误的通过信号。
- **修复建议**: 集中管理 mock key 常量，确保与产品代码的命令字符串一致。考虑提取命令常量为 `static let` 属性。

### 问题 3: 每个测试函数都重新实例化 module — 重复但安全
- **严重程度**: LOW
- **类型**: 代码重复
- **文件**: `NetworkSecurityModuleTests.swift`, `ClaudeProtectionTests.swift`, `ServicesModuleTests.swift` 所有行
- **描述**: 每个测试都执行 `let module = NetworkSecurityModule()` + `let checks = module.checks(for: .sequoia, device: .laptop)`。这确保了测试隔离（好事！），但造成了大量重复。
- **修复建议**: 这是可接受的重复——测试隔离比DRY更重要。但可以用 Swift Testing 的 `@Suite` + `init()` 来减少样板代码。

### 问题 4: ClaudeProtection 测试的 ID 生成逻辑与产品代码耦合
- **严重程度**: HIGH
- **类型**: 脆弱测试
- **文件**: `MacAudit/Tests/MacAuditTests/ClaudeProtectionTests.swift:108,118,128`
- **描述**: 测试中手动构造 ID：`"m10.env_" + String("claude_code_proxy_resolves_hosts".prefix(30))`。这意味着测试知道产品代码的 ID 生成规则（截断到30字符）。如果产品代码改变了截断逻辑，测试会静默失败（找不到 check，断言 nil != nil）。
- **修复建议**: 要么用已知完整 ID 直接断言（`"m10.env_claude_code_proxy_resolves_ho"`），要么通过更稳定的属性（如检测命令内容）来查找 check。

### 问题 5: ShellExecutor 的 stubbedOutputs mock 是字符串匹配而非正则匹配
- **严重程度**: MEDIUM
- **类型**: 测试隔离
- **文件**: `MacAudit/Tests/MacAuditTests/ServicesModuleTests.swift:159`
- **描述**: `ShellExecutor(stubbedOutputs: ["launchctl print-disabled": fakeOutput])` 使用字符串包含匹配。如果产品代码的命令是 `"launchctl print-disabled system/com.apple.assistantd"`，但 mock key 只是 `"launchctl print-disabled"`，匹配行为依赖于 ShellExecutor 内部的 `contains` 实现。
- **修复建议**: Mock 的匹配策略应该被显式测试。添加一个 `ShellExecutorMockTests.swift`，验证 stub 匹配规则。

### 问题 6: 缺少异步错误路径测试
- **严重程度**: MEDIUM
- **类型**: 覆盖不足
- **文件**: `MacAudit/Tests/MacAuditTests/ShellExecutorTests.swift`
- **描述**: 所有异步测试都假设 shell 调用成功。没有测试：shell 返回非 UTF-8 输出时是否崩溃？进程被强制杀死时的行为？并行执行时的线程安全？
- **修复建议**: 添加错误路径测试：无效编码、信号终止、并行调用的结果不串扰。

## Tacit Knowledge 审查
这个项目的测试策略有一个根本性矛盾：ServicesModule 的 `run()` 测试做得很好——使用 mock、测试三路分支（disabled/enabled/unmanaged）、验证结果数量匹配。但 ShellExecutor 的测试却完全不 mock，直接调真实 shell。这说明 mock 基础设施存在但未被一致使用。好的 TDD 要求所有涉及外部资源的测试都通过抽象边界隔离——不是"能跑就行"，而是"在任何环境下都能可靠地跑"。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 测试质量 | 5 | ServicesModule run() 测试质量高，但 ShellExecutor 测试是集成测试伪装成单元测试 |
| 测试覆盖 | 6 | 正面路径覆盖充分，错误路径几乎为零 |
| 简单设计 | 6 | 测试结构清晰，但 mock 策略不一致 |
| 开发者体验 | 5 | ShellExecutor 真实 shell 测试在 CI 中可能是定时炸弹 |
| 重构信心 | 4 | ClaudeProtection ID 截断耦合让重构高风险 |
