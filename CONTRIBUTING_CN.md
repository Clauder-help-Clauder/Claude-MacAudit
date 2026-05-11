# MacAudit 贡献指南

感谢你对 MacAudit 的关注！我们欢迎所有人的贡献。

**仓库地址**：[github.com/Clauder-help-Clauder/Claude-MacAudit](https://github.com/Clauder-help-Clauder/Claude-MacAudit)

## 快速导航

- [行为准则](#行为准则)
- [开发环境搭建](#开发环境搭建)
- [代码风格](#代码风格)
- [测试要求](#测试要求)
- [Pull Request 流程](#pull-request-流程)
- [问题反馈](#问题反馈)

## 行为准则

保持尊重、建设性和专业态度。我们共同的目标是让 macOS 更安全。

## 开发环境搭建

### 前置条件

- macOS 15.0 (Sequoia) 或更高版本
- Xcode 16.0+ 及 Swift 6.0 工具链
- Git

### 构建与测试

```bash
git clone https://github.com/Clauder-help-Clauder/Claude-MacAudit.git
cd Claude-MacAudit/MacAudit
swift build -c debug
swift test
bash scripts/build_app.sh        # 构建 GUI 应用
```

### 项目结构

```
MacAudit/Sources/
├── MacAudit/         # CLI 可执行目标（internal 访问级别）
├── MacAuditCore/     # 共享框架（public 访问级别）
├── MacAuditUI/       # SwiftUI 界面
└── MacAuditApp/      # 薄启动器
```

> **重要提示**：本项目使用双副本架构。模块、模型或共享工具的修改必须同步到 `MacAudit/` 和 `MacAuditCore/`。详见 `HANDOFF.md`。

## 代码风格

### Swift 规范

- **Swift 6 严格并发** — 所有目标使用 `.swiftLanguageMode(.v6)`
- 零第三方运行时依赖
- 所有审计模块遵循 `AuditModule` 协议
- 检测项使用 `AuditCheck` 结构体：`id`、`name`、`command`、`expectedValue`、`fixCommand`、`riskLevel`、`priority`、`architectures`
- 模块文件：`Modules/` 目录下的 `*Module.swift`
- 测试文件：`Tests/MacAuditTests/` 目录下的 `*Tests.swift`

### 命名规范

- 模块：PascalCase + `Module` 后缀（如 `PrivacyModule.swift`）
- 检测项 ID：`m<模块号>.<检测名>` 格式（如 `m4.diagnostics`）
- 测试：`<模块名>Tests.swift`（如 `FixEngineTests.swift`）

### 优先级体系

每条 `AuditCheck` **必须**显式设置 `priority:` 字段：
- `A0` — 关键安全（默认运行始终包含）
- `A1` — 高影响
- `A2` — 中等/外观
- `A3` — 低/信息

默认值为 `.a3` — 新检测项默认最低优先级，确保安全。

### 修复命令

- 每条修复必须有对应的撤销命令
- 修复命令由 `UndoValidator` 白名单验证
- 撤销脚本生成时使用 `0o700` 文件权限
- 新增修复命令必须测试 fix→undo 闭环

## 测试要求

### 必须项

- 所有新代码必须有对应的单元测试
- PR 提交前 `swift test` 必须零失败
- 新模块至少需要：基本加载测试、检测项数量测试、关键检测验证

### 测试级别

| 级别 | 说明 | 是否必须 |
|------|------|----------|
| 单元测试 | 模块级检测逻辑 | 是 |
| 修复闭环 | 破坏→检测→修复→验证 | 新增修复命令时 |
| 双副本同步 | MacAudit ↔ MacAuditCore 一致性 | 涉及共享组件时 |
| 跨平台 | macOS 15 + macOS 26 行为 | 涉及 OS 敏感检测时 |

## Pull Request 流程

### 提交前

1. **Fork** 仓库并创建功能分支
2. **构建**通过：`swift build -c debug` 零警告
3. **测试**通过：`swift test` 零失败
4. **代码风格**符合上述规范
5. **双副本同步**已验证（如涉及共享代码）

### PR 模板

```markdown
## 说明
简要描述变更

## 类型
- [ ] Bug 修复
- [ ] 新功能
- [ ] 新增模块
- [ ] 性能优化
- [ ] 文档

## 测试
- [ ] 单元测试已添加/更新
- [ ] `swift test` 通过
- [ ] macOS 15 / 26 上已测试（请注明）

## 检查清单
- [ ] 双副本文件已同步（如适用）
- [ ] 修复命令有 undo 支持（如适用）
- [ ] 新检测项已显式设置 priority
```

## 问题反馈

### Bug 报告

请包含：
- macOS 版本和架构（`sw_vers` + `uname -m`）
- MacAudit 版本
- 模块和检测项 ID（如 `m4.diagnostics`）
- 期望行为 vs 实际行为
- `MacAudit --self-test` 输出

### 功能请求

- 描述该功能解决的安全/性能问题
- 建议归属的模块
- 如已知，提供 `defaults`/`sysctl`/shell 命令

## 许可证

贡献即表示你同意你的贡献将在 [MIT 许可证](LICENSE) 下授权。
