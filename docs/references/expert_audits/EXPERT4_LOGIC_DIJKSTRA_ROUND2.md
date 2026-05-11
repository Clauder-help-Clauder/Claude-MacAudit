# Expert 4: Dijkstra — 形式逻辑与正确性审查 Round 2

## 审查焦点
边界条件与不变量

## 发现的问题

### 问题 1: ShellExecutor 超时精度损失 — attoseconds 截断
- **严重程度**: HIGH
- **逻辑类型**: 边界/不变量
- **文件**: ShellExecutor.swift:91-92
- **形式化描述**: 超时转换公式 `Int(effectiveTimeout.components.seconds) * 1000 + Int(effectiveTimeout.components.attoseconds / 1_000_000_000_000_000)` 将 Duration 转为毫秒。当 `components.seconds` 超过 `Int.max / 1000` 时发生整数溢出。此外 attoseconds 的除法截断了纳秒级精度。
- **反例**: 设置 `timeout: .seconds(Int.max / 1000 + 1)` → 整数溢出 → 负数超时 → DispatchQueue 立即触发 → 所有命令立即超时。
- **修复建议**: 使用 `Duration.milliseconds` 直接计算，或加 `clamped(to:)` 保护。

### 问题 2: ShellExecutor 超时后未等待 pipe read tasks 完成
- **严重程度**: MEDIUM
- **逻辑类型**: 边界/资源泄漏
- **文件**: ShellExecutor.swift:101-106
- **形式化描述**: 超时时取消 `stdoutTask` 和 `stderrTask`，但 `Task.detached` 的 cancel 仅设置取消标志，不等待 `readDataToEndOfFile` 返回。若进程已终止但 pipe 数据尚未读完，可能丢失输出。更严重的是：若进程仍在运行但被 `process.terminate()` 杀死，pipe 的 file handle 可能泄漏。
- **反例**: 命令输出 1MB 数据但执行超过 10 秒 → 超时 → process.terminate() → pipe 中残留数据未被读取 → 资源泄漏。
- **修复建议**: 超时后给 pipe read 一个短暂的完成窗口（如 100ms），或使用 `readData(ofLength:)` 替代 `readDataToEndOfFile`。

### 问题 3: IPFetcher.publicIPv4 的 TaskGroup 取消后仍返回 nil
- **严重程度**: LOW
- **逻辑类型**: 边界/控制流
- **文件**: IPFetcher.swift:12-29
- **形式化描述**: `withTaskGroup` 中 `group.cancelAll()` 后继续 `for await result in group` 循环。根据 Swift concurrency 语义，已完成的子任务结果仍会被迭代。但如果所有源都失败（返回 nil），循环正常结束返回 nil。逻辑正确，但 `cancelAll()` 不保证子任务立即停止——它们可能继续执行 shell 命令浪费资源。
- **反例**: 三个 IP 源都不可达 → 所有子任务等待超时 → 第一个完成返回 nil → cancelAll() → 其余两个仍在等待 curl 超时 → 总耗时 = 最慢源的超时时间。
- **修复建议**: 可接受的行为，但可考虑设置 TaskGroup 的总超时。

### 问题 4: DNSBLChecker 的 IP 反转未验证输入格式
- **严重程度**: HIGH
- **逻辑类型**: 边界/不变量
- **文件**: DNSBLChecker.swift:28
- **形式化描述**: `ip.split(separator: ".").reversed().joined(separator: ".")` 未验证 `ip` 是否为有效 IPv4。若 `ip` 包含非数字部分（如 "1.2.3.4.5" 或 "abc"），反转后生成无效 DNS 查询名。虽然 `isValidIPv4` 存在，但 `check()` 方法不调用它。
- **反例**: 传入 `ip = "1.2.3.4.5"` → reversed = "5.4.3.2.1" → 查询 "5.4.3.2.1.barracudacentral.org" → DNS 返回 NXDOMAIN → 被误判为"不在黑名单" → 假阴性。
- **修复建议**: 在 `check()` 入口添加 `guard isValidIPv4(ip) else { return [.error(...)] }`。

### 问题 5: ModuleSummary.score 的整数除法向下取整
- **严重程度**: LOW
- **逻辑类型**: 算法/边界
- **文件**: AppViewModel.swift:39
- **形式化描述**: `passed * 100 / total` 使用整数除法。当 `passed = 1, total = 3` 时结果为 33（33.33...截断）。这导致 1/3 通过的评分低于直觉预期的 34。多次四舍五入累积后可能与 UI 显示的百分比不一致。
- **反例**: 模块有 7 项检查，3 项通过 → score = 3*100/7 = 42。但 3/7 = 42.857%，用户看到 "42%" 而预期 "43%"。
- **修复建议**: 使用 `Int(Double(passed) * 100.0 / Double(total) + 0.5)` 四舍五入，或使用 `Double` 类型。

### 问题 6: IPFetcher.whoisInfo 的输出截断可能丢失关键字段
- **严重程度**: LOW
- **逻辑类型**: 边界
- **文件**: IPFetcher.swift:67
- **形式化描述**: `head -80` 硬编码截断 whois 输出。某些 IP 的 `orgname` 或 `country` 字段可能出现在第 80 行之后。这构成信息丢失。
- **反例**: 某 IP 的 whois 输出前 80 行是免责声明和元数据，实际 org 信息在第 85 行 → 函数返回 `(nil, nil)`。
- **修复建议**: 增大 head 限制至 200，或使用 grep 过滤后读取。

## Philosophy 审查 — 程序哲学

> "Testing shows the presence, not the absence of bugs." — Dijkstra

DNSBLChecker 不验证 IP 格式便构造查询字符串——这正是"未证明正确性"的典型案例。`isValidIPv4` 函数已存在但未被前置条件调用。每个函数都应声明其前置条件（precondition），并在入口处验证。这不是防御性编程——这是数学上的必然要求。

## 本轮评分
| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 状态完备性 | 6 | IP 输入验证缺失 |
| 边界安全 | 5 | 超时溢出、资源泄漏、截断风险 |
| 算法正确性 | 7 | IPv4 验证逻辑正确 |
| 并发安全 | 7 | TaskGroup 使用合理 |
| 逻辑简洁性 | 7 | IPFetcher 结构清晰 |
