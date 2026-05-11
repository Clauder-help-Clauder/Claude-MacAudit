# CODEX 配套文档：ClaudeComplianceAddon 实施计划

生成日期：2026-04-22  
作者标识：Codex  
目标：在**不改动现有功能**的前提下，为 `MacAudit` 增加一组针对官方 `Claude Code` 用户的补充能力。

---

## 1. 实施目标

本计划的目标不是重构，而是：

- 保持现有模块、现有检查项、现有报告逻辑不变
- 通过新增模块和新增测试补充能力
- 为后续报告增强与数据保全能力打基础

约束条件：

1. 不修改现有 check id
2. 不改现有模块归属
3. 不改现有 fix command 语义
4. 不改 UI / 动效 / 页面结构
5. 不引入规避平台规则的功能

---

## 2. 总体实现策略

推荐采用“外挂式扩展”：

### 2.1 新增模块

新增：

- `MacAudit/Sources/MacAudit/Modules/ClaudeComplianceAddonModule.swift`
- `MacAudit/Sources/MacAuditCore/Modules/ClaudeComplianceAddonModule.swift`

### 2.2 新增测试

新增：

- `MacAudit/Tests/MacAuditTests/ClaudeComplianceAddonModuleTests.swift`

### 2.3 模块接入方式

在不影响现有模块顺序的前提下，新增模块追加到 `allModules` 末尾。

建议顺序：

- 保持原有顺序不变
- 在 `ClaudeProtectionModule()` 之后或全部模块末尾附加 `ClaudeComplianceAddonModule()`

推荐：
- 先追加到末尾，回归风险最小

---

## 3. 代码改动范围

### 3.1 必改文件

1. `MacAudit/Sources/MacAudit/Modules/ClaudeComplianceAddonModule.swift`
2. `MacAudit/Sources/MacAuditCore/Modules/ClaudeComplianceAddonModule.swift`
3. `MacAudit/Tests/MacAuditTests/ClaudeComplianceAddonModuleTests.swift`
4. `MacAudit/Sources/MacAuditUI/ViewModels/AppViewModel.swift`
5. `MacAudit/Sources/MacAudit/MacAudit.swift`

### 3.2 尽量不改文件

以下文件原则上不动：

- `ClaudeProtectionModule.swift`
- `ShellModule.swift`
- `NetworkSecurityModule.swift`
- `IPQualityModule.swift`
- 任意 UI 视图文件
- 报告生成逻辑（第一阶段）

---

## 4. Phase 1：最小可交付版本

### 4.1 目标

实现首批 4 个新增检查项：

1. 代理变量大小写一致性
2. Shell 与系统代理一致性
3. 本地代理端口监听
4. Claude wrapper / alias 检测

### 4.2 原因

这是最适合第一阶段的范围，因为：

- 依赖少
- 与现有模块耦合低
- 测试容易写
- 不会改变现有行为

### 4.3 建议数据结构

模块定义：

```swift
struct ClaudeComplianceAddonModule: AuditModule {
    let id = "claude_addon"
    let name = "Claude 合规补充检查"
    let description = "代理一致性、启动路径与数据保全补充检查"
}
```

首批 check id：

- `m10a.proxy_case_consistency`
- `m10a.proxy_shell_system_consistency`
- `m10a.proxy_port_alive`
- `m10a.claude_wrapper_detected`
- `m10a.claude_alias_detected`

建议命名规则：

- 使用新前缀 `m10a.`
- 避免与旧 `m10.` 冲突

---

## 5. Phase 1 详细实现

### 5.1 `m10a.proxy_case_consistency`

实现方式：

- `command` 输出大小写两组变量
- `run()` 中做轻量解析
- 返回 `pass/warn/info`

理由：

- 单纯字符串解析最稳定

### 5.2 `m10a.proxy_shell_system_consistency`

实现方式：

- 读取 shell `HTTPS_PROXY`
- 读取 `scutil --proxy`
- 解析系统代理是否启用

判定逻辑：

- 两边都没开：`info`
- 两边都开且 host/port 一致：`pass`
- 一边开一边关或不一致：`warn`

### 5.3 `m10a.proxy_port_alive`

实现方式：

- 从环境变量解析端口
- 用 `lsof` 或 `nc -z` 检查监听状态

判定逻辑：

- 有代理变量但端口不通：`fail`
- 有代理变量且端口通：`pass`
- 无代理变量：`info`

### 5.4 `m10a.claude_wrapper_detected`

实现方式：

- `type claude`
- `command -v claude`

判定逻辑：

- binary path：`pass`
- alias/function/script wrapper：`warn`

### 5.5 `m10a.claude_alias_detected`

实现方式：

- grep `~/.zshrc ~/.bashrc ~/.zprofile`

判定逻辑：

- 发现 alias/function：`warn`
- 未发现：`pass`

---

## 6. Phase 1 测试计划

### 6.1 测试目标

确保新增模块：

- 元数据正确
- check ids 唯一
- 所有 checks 都归属新模块
- 关键解析逻辑稳定

### 6.2 测试项建议

#### A. 模块结构测试

1. `ClaudeComplianceAddon module id and name are non-empty`
2. `ClaudeComplianceAddon check IDs are unique`
3. `ClaudeComplianceAddon all checks belong to claude_addon`

#### B. 逻辑测试

4. `proxy_case_consistency returns warn when upper/lower mismatch`
5. `proxy_case_consistency returns pass when all equal`
6. `proxy_shell_system_consistency warns on split config`
7. `proxy_port_alive fails when env exists but no listener`
8. `claude_wrapper_detected warns on alias`

### 6.3 测试方式

优先使用：

- `ShellExecutor(stubbedOutputs:)`
- 纯字符串解析 helper

避免：

- 依赖真实本机网络状态
- 依赖当前 shell 配置

---

## 7. Phase 2：企业网络补充

### 7.1 目标

新增：

- `m10a.proxy_protocol_supported`
- `m10a.ca_file_present`
- `m10a.ca_file_readable`
- `m10a.multi_egress_detected`

### 7.2 风险

这一阶段的误报可能增加，因为：

- 企业 CA 场景差异大
- 多出口不一定等于异常

控制方式：

- 默认只给 `warn/info`
- 不要轻易打 `fail`

---

## 8. Phase 3：数据保全与快照

### 8.1 目标

新增能力：

- `m10a.claude_local_state_present`
- `m10a.snapshot_export_ready`
- 审计快照导出命令

### 8.2 建议形式

第一阶段先做检查项，第二阶段再做导出命令。

导出内容建议包括：

- 时间戳
- Claude Code 版本
- 关键 env 变量
- `scutil --proxy`
- `scutil --dns`
- IPv6 状态
- 默认路由
- 网络服务列表

输出格式：

- JSON
- Markdown

---

## 9. 报告层规划

### 9.1 第一阶段

不改现有报告结构，只在 Claude 相关区域追加一段：

- `Supplemental Claude Compliance Checks`

### 9.2 第二阶段

可考虑为新增模块单独分区：

- 合规边界补充
- 网络一致性补充
- 数据保全补充

### 9.3 暂不建议

暂不建议：

- 把新增项混入系统总分
- 修改现有高/中/低风险统计逻辑

理由：

- 会改变现有用户感知
- 难以控制回归

---

## 10. 与现有检查项的关系

### 10.1 并存原则

新增项是“补充层”，不是替换层。

例如：

- 现有 `m9.https_proxy` 检查“有没有”
- 新增 `m10a.proxy_case_consistency` 检查“是否一致”

- 现有 `m13.proxy_config` 检查“系统代理是什么”
- 新增 `m10a.proxy_shell_system_consistency` 检查“系统代理和 shell 代理是否一致”

### 10.2 避免重复输出的方法

第一阶段不做去重逻辑，只在文案层说明“此为补充检查”。

后续若需要：

- 可在报告层做 cross-reference
- 但不要修改底层检查项

---

## 11. 风险与回归预测

### 11.1 低风险项

- proxy case consistency
- wrapper/alias 检测
- proxy port alive

### 11.2 中风险项

- shell/system consistency
- multi egress detected

### 11.3 高误报潜力项

- 企业 CA
- 公司代理
- 出差/旅行场景下的地区/时区矛盾

建议：

- 高误报潜力项默认使用 `warn/info`
- 不做强修复命令

---

## 12. 推荐落地顺序

### Sprint 1

- 新模块骨架
- 4~5 个首批检查项
- 单元测试

### Sprint 2

- 企业 CA + 多出口检测
- 报告 supplemental section

### Sprint 3

- 快照导出
- 数据保全提示
- 证据等级与场景标签（仅报告层）

---

## 13. 交付标准

Phase 1 完成标准：

1. 新模块可被 CLI 和 UI 加载
2. 现有测试不受影响
3. 新增测试全部通过
4. 不修改任何现有 check 行为
5. 报告中可见新增模块结果

---

## 14. Codex 建议

如果进入实现，推荐严格按 TDD 小步推进：

1. 先写新模块元数据测试
2. 再写第一个新增检查项测试
3. 最小实现
4. 跑新增测试
5. 跑全量测试
6. 逐项向后推进

不要一次把整个 addon 模块全部做完再统一修。

---

## 15. 最终建议

在你当前的目标下，最合理的执行路线不是“重做 Claude 风险体系”，而是：

> 以最小侵入方式新增一个 `ClaudeComplianceAddonModule`，先补代理一致性与 wrapper 检测，再逐步增加企业 CA、多出口和数据保全能力。

这条路线：

- 不破坏已有功能
- 可验证
- 可渐进上线
- 与产品定位一致
