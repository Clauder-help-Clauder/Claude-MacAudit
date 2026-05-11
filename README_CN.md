<div align="center">

# MacAudit - [ Claude / Codex / ChatGPT / Gemini AI Coding 效能优化 ]

**macOS 全面系统安全审计与优化工具包**

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue.svg)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-720%2B%20passing-brightgreen.svg)](#测试)
[![Architecture](https://img.shields.io/badge/arch-Universal%20Binary-purple.svg)](#兼容性)

[English](README.md) · [中文](README_CN.md)

</div>

---

MacAudit 是一款使用 **Swift 6 严格并发模式** 原生构建的 macOS 系统安全审计与优化工具。它执行 **400+ 自动化检测项**，覆盖 12 个审计模块，涵盖安全加固、隐私保护、网络配置、性能调优和 AI 服务兼容性 — **零第三方运行时依赖**。

> 🛠 **实时构建指标** — 版本：**v0.3.1** · 发版日期：**2026-05-12** · 累计 AI token 消耗（v0.1.0 至今）：**约 26 亿+ 输入/输出 + 约 160 亿+ 缓存**（跨 Claude / GPT / Gemini / Codex / 本地模型，数百个会话）

> **从 Python 脚本到 Swift 原生应用 — 历时 1 个月、5 个里程碑、5 轮专家审计、720+ 测试用例、两个 macOS 大版本的真机验证。**

> **最新版本、测试报告和升级说明发布在 [GitHub](https://github.com/Clauder-help-Clauder/Claude-MacAudit)。**

---

> **说明**：由于平台规则限制，本软件使用「AI 网络与系统调优」作为部分防护功能的代名词。

## 特别感谢

<a href="https://wstormai.store/"><img src="docs/references/wstorm.png" alt="wstormai" width="140" align="left" style="margin-right: 16px;"></a>

**订阅充值由 [wstormai](https://wstormai.store/) 提供**

在整个开发和测试期间提供稳定可靠的 Claude/Codex 订阅充值渠道。

<br clear="left">

---

## 更新说明

最近 5 个版本。完整历史：[Releases](https://github.com/Clauder-help-Clauder/Claude-MacAudit/releases) · [CHANGELOG](CHANGELOG.md)。

| 版本 | 日期 | 要点 | Release |
|------|------|------|---------|
| **v0.3.1** | 2026-05-12 | Codex / OpenAI 账号保护（3 项新 A0 检测）、AIBrands 可扩展架构、iCloud 订阅建议 | [→ v0.3.1](https://github.com/Clauder-help-Clauder/Claude-MacAudit/releases/tag/v0.3.1) |
| v0.3.0 | 2026-05-11 | 稳定版发布 — 幂等修复（sed 先删后加）、执行校验、安全加固、10 轮 VM 稳定性验证 | [→ v0.3.0](https://github.com/Clauder-help-Clauder/Claude-MacAudit/releases/tag/v0.3.0) |

---

## 目录

- [为什么选择 MacAudit？](#为什么选择-macaudit)
- [CLI 与 GUI 对比](#cli-与-gui-对比)
- [审计模块](#审计模块)
- [快速开始](#快速开始)
- [架构](#架构)
- [优先级体系](#优先级体系)
- [测试](#测试)
- [开发历程](#开发历程)
- [专家审计与代码评审](#专家审计与代码评审)
- [研究与参考资料](#研究与参考资料)
- [兼容性](#兼容性)
- [路线图](#路线图)
- [致谢](#致谢)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

---

## 界面截图

### GUI 图形界面

<p>
<img src="docs/image/screenshot-GUI01.png" alt="MacAudit GUI - 仪表盘" width="800">
</p>

<p>
<img src="docs/image/screenshot-GUI02.png" alt="MacAudit GUI - 安全检测结果" width="800">
</p>

### CLI 命令行

<p>
<img src="docs/image/screenshot-CLI.png" alt="MacAudit CLI - 交互式菜单" width="600">
</p>

---

## 为什么选择 MacAudit？

- **全面覆盖** — 12 模块 400+ 检测项，从内核 sysctl 调优到浏览器策略检查
- **安全优先** — 每条修复命令均经过 `UndoValidator` 白名单验证；自动生成 `0o700` 权限的回滚脚本
- **macOS 版本感知** — 处理 Sequoia (15.x) 与 Tahoe (26.x) 的格式差异，包括 `defaults -bool` 归一化
- **双界面** — CLI 全量检测工作流；GUI 核心检测仪表盘
- **零依赖** — 完全基于 Apple SDK 和 Swift Package Manager 构建；无需 Homebrew、CocoaPods、Carthage
- **实战检验** — 在 Apple Silicon 和 Intel 真机及 VM 上验证，覆盖对抗测试、突变测试、混沌测试和并发测试

> **MacAudit 是 GitHub 上唯一的 Swift 原生 macOS 安全审计工具**，也是唯一同时覆盖 macOS 系统审计和 AI 服务保护的工具。没有其他工具覆盖这个交叉领域。

> 💡 **账号防护建议** — 全新安装 macOS + 通过 iCloud 订阅 Claude / Codex（App Store 内购）能彻底脱离信用卡。Apple 加收约 30% 平台费，但换来无信用卡盗刷、无银行风控标签、订阅可一键取消。详细说明见 [`docs/proxy_rules.md`](docs/proxy_rules.md#账号注册最佳实践账号层防护)。

## CLI 与 GUI 对比

| | CLI (`macaudit`) | GUI (`MacAuditApp`) |
|---|---|---|
| **范围** | **全量检测** — 12 模块全部 400+ 检测项 | **核心检测** — A0 优先级关键项（约 85 项，覆盖 6 个模块） |
| **界面** | 终端（ANSI 彩色、交互式菜单） | 原生 SwiftUI 窗口，赛博朋克设计风格 |
| **使用场景** | 高级用户、自动化、CI/CD、脚本 | 快速健康检查、可视化概览 |
| **修复支持** | `--fix` / `--undo` 带回滚脚本 | 仅查看（修复通过 CLI 执行） |
| **导出** | JSON、Markdown、基线对比 | 应用内仪表盘 |
| **默认运行** | 仅 A0 优先级；`--all` 全量扫描 | 自动执行 A0 关键检测 |

## 审计模块

| # | 模块 | 检测项 | 说明 |
|---|------|--------|------|
| 1 | SystemInfo | 12 | 硬件、系统版本、架构、运行时间 |
| 2 | NetworkSecurity | 44 | 防火墙、DNS、sysctl 调优、套接字过滤 |
| 3 | Privacy | 17 | 遥测、分析、数据收集选项 |
| 4 | Animation | 43 | UI 动画开关（性能/响应优化） |
| 5 | Services | 70+ | 守护进程状态、启动代理、系统服务 |
| 6 | Power | 21+ | 睡眠、Power Nap、电池优化 |
| 7 | Shell | 19 | 终端环境、PATH、Shell 配置 |
| 8 | ClaudeProtection | 53 | AI 服务兼容性（Claude Code、Codex 等） |
| 9 | DevEnvironment | 66 | Xcode、Homebrew、Git、语言运行时 |
| 10 | IPQuality | 23 | DNSBL 信誉、GeoIP、邮件黑名单 |
| 11 | Chrome | 13 | Chrome 策略、更新、遥测 |
| 12 | Safari | 14 | Safari 安全、隐私、自动填充策略 |

## 快速开始

### 前置条件

- macOS 15.0 (Sequoia) 或更高版本
- Xcode 16.0+ 及 Swift 6.0 工具链
- Apple Silicon (M 系列) 或 Intel x86_64

### 从源码构建

```bash
git clone https://github.com/Clauder-help-Clauder/Claude-MacAudit.git
cd Claude-MacAudit/MacAudit
swift build -c release
```

### 运行 CLI（全量检测）

```bash
# 交互式菜单（默认：仅 A0 优先级）
.build/release/MacAudit

# 全量检测：12 模块全部优先级
.build/release/MacAudit --all

# 审计指定模块
.build/release/MacAudit --module privacy

# 导出 JSON 结果
.build/release/MacAudit --all --json --export report.json

# 保存基线并后续对比
.build/release/MacAudit --all --save baseline.json
.build/release/MacAudit --all --diff baseline.json

# 应用修复（自动生成回滚脚本）
.build/release/MacAudit --all --fix

# 撤销之前的修复
.build/release/MacAudit --undo

# 自检（验证所有模块正确加载）
.build/release/MacAudit --self-test
```

### 构建 GUI 应用（核心检测）

```bash
cd MacAudit
bash scripts/build_app.sh
# 输出：release/MacAuditApp-v0.x.x.app（通用二进制）
```

## 架构

```
MacAudit/
├── Package.swift                    # SPM 清单（Swift 6，macOS 15+）
├── Sources/
│   ├── MacAudit/                    # CLI 可执行目标（全量检测，400+ 检测项）
│   │   ├── MacAudit.swift           # @main 入口 + ArgumentParser
│   │   ├── CLI/                     # 菜单、报告、修复引擎、基线管理
│   │   ├── Models/                  # AuditCheck、AuditResult、RiskLevel...
│   │   ├── Modules/                 # 12 个审计模块（internal 访问级别）
│   │   ├── IPQuality/               # DNSBL、GeoIP、IP 信誉（CLI 副本）
│   │   └── Utils/                   # Shell 执行、ANSI 颜色、归一化
│   ├── MacAuditCore/                # 共享框架（public API）
│   │   ├── Models/                  # Public 模型副本
│   │   ├── Modules/                 # 12 个审计模块（public 访问级别）
│   │   ├── IPQuality/               # 完整 IP 质量套件（7 文件）
│   │   └── ShellExecutor.swift      # Actor 模式的 Shell 命令执行器
│   ├── MacAuditUI/                  # SwiftUI 界面（核心检测，约 85 项 A0 检测）
│   │   ├── App/                     # 入口工厂
│   │   ├── Views/                   # 仪表盘、扫描、结果、详情
│   │   ├── ViewModels/              # 可观察审计状态 + 通知中心
│   │   ├── DesignSystem/            # 设计令牌 + 可复用组件
│   │   └── Resources/               # 字体（Space Grotesk、JetBrains Mono）
│   └── MacAuditApp/                 # 薄启动器 → MacAuditUI
└── Tests/
    └── MacAuditTests/               # 38 个测试文件，720+ 测试用例
```

### 核心组件

| 组件 | 说明 |
|------|------|
| **ShellExecutor** | `actor` 模式的子进程执行器，带超时、`readabilityHandler` 管道管理和 Swift 并发安全 |
| **FixEngine** | 生成、验证并应用修复命令；生成 `0o700` 权限的撤销脚本；`shellEscape` 注入防御 |
| **UndoValidator** | 白名单安全门：仅允许 `defaults/networksetup/sysctl/pmset/launchctl/PlistBuddy` 前缀；`chainingChars` 拒绝 `&\|;$` 注入 |
| **DefaultsNormalizer** | 处理 `defaults -bool` 格式差异（Tahoe 返回 `YES/NO` vs Sequoia 返回 `1/0`） |
| **IPCache** | `@unchecked Sendable class` + `OSAllocatedUnfairLock` 线程安全 TTL 缓存；消除 60%+ 冗余网络调用 |
| **BaselineManager** | 保存审计快照，对比历史运行追踪配置漂移 |
| **AuditNotificationCenter** | `@MainActor @Observable` 通知系统，三级严重度（info/warning/critical），50 条上限，O(1) 未读计数缓存 |

## 优先级体系

每条检测项基于 9 份调研文档交叉验证和 49 条跨文档发现进行优先级分级：

| 优先级 | 标签 | 数量 | 说明 |
|--------|------|------|------|
| A0 | 关键 | ~83 | 安全漏洞、数据泄露、AI 服务安全 — 始终包含 |
| A1 | 高 | ~43 | 性能影响、明显配置异常 |
| A2 | 中 | ~115 | 外观偏好、轻微优化 |
| A3 | 低 | ~155 | 小众设置、高级调优、纯信息 |

- **CLI 默认运行** (`macaudit`) 仅执行 A0 检测
- **CLI 全量运行** (`macaudit --all`) 覆盖 A0–A3 全部 12 模块（400+ 检测项）
- **GUI** 聚焦 A0 关键检测，提供快速健康概览（约 85 项，覆盖 6 个模块）

## 测试

### 测试套件概览

| 类别 | 数量 | 说明 |
|------|------|------|
| **单元测试** | 720+ | 全部 12 模块、FixEngine、UndoValidator、ShellExecutor、IPCache、AppViewModel、AuditNotificationCenter |
| **集成测试** | 400-check × 3 轮 | 真实 macOS 跨模块一致性 |
| **修复闭环** | 10/10 PASS | 破坏→检测→修复→验证 闭环 |
| **对抗测试** | 17/20 检出 (85%) | 故意破坏 20 个安全配置 |
| **突变测试** | 15/15 (0 崩溃) | 15 种异常值注入 |
| **幂等性** | 3/3 PASS | 同一修复命令执行两次结果不变 |
| **混沌工程** | 5/5 PASS | locale、PATH、HOME、并发、一致性 |
| **基线恢复** | 0 diff | 所有测试结束系统完全恢复 |

### 测试方法论

我们研究并适配了行业最佳实践中的 **7 种创新测试方法**：

| 方法 | 来源灵感 | 实现 | 测试点 |
|------|---------|------|--------|
| 对抗测试 | [Lynis](https://github.com/CISOfy/lynis) + [claudit](https://github.com/nicholasaleks/claudit) | T2：故意破坏 20 个安全配置 | 20 |
| 修复闭环 | [NIST mSCP](https://github.com/usnistgov/macos_security) 原子操作 | T3：破坏→检测→修复→验证 | 10 |
| 突变测试 | [Google Santa](https://github.com/google/santa) 配置覆盖 | T4：15 种异常值注入 | 15 |
| 幂等性测试 | [osquery](https://github.com/osquery/osquery) 基于属性 | T5：同一修复执行两次 | 3 |
| 混沌工程 | Netflix Chaos Monkey | T6：locale/PATH/HOME/并发 | 5 |
| 快照对比 | [swift-argument-parser](https://github.com/apple/swift-argument-parser) | T1+T7：3 轮一致性 + 恢复 | 6 |
| 并发测试 | [osquery](https://github.com/osquery/osquery) 并发查询 | T6-4/5：多实例并行 | 2 |

### 真机测试 — macOS 26.4.1 Tahoe (Intel x86_64)

**环境**：`<testuser>@<test-machine>`，Darwin 25.4.0，x86_64，MacAudit v0.1.5

| 测试类别 | 结果 |
|----------|------|
| T1：397-check × 3 轮 | **0 diff**（完全一致） |
| T2：对抗测试（20 项破坏） | **17/20 检出**（排除 Chrome MDM 限制后 100%） |
| T3：修复闭环 | **10/10 PASS** |
| T4：突变测试（15 种异常值） | **15/15 OK**（0 崩溃） |
| T5：幂等性 | **3/3 PASS** |
| T6：混沌测试（5 个场景） | **5/5 PASS** |
| T7：最终基线恢复 | **0 diff**（完全恢复） |
| **合计** | **7 类测试，70 个测试点，100% 通过率** |

对抗测试关键发现：
- **跨模块交叉检测**：Privacy 模块的 SubmitDiagInfo/CrashReporter 变更同时被 Claude 模块的 `telemetry_*` 检测项捕获
- **连带效应**：Safari UniversalSearchEnabled 变更触发了 Privacy `safari_search` 检测
- **Chrome 架构限制**：非 MDM 环境下无法影响 Chrome 审计结果（预期行为，已文档化）

## 开发历程

MacAudit 从一个简单的 Python 审计脚本，历经约一个月演变为全功能原生 macOS 应用。

### 时间线

```
2026-04-06  项目启动 — Python 审计脚本 + 优化指南
            ├── mac_audit.sh（Shell 审计采集脚本）
            ├── Mac_System_Optimization_Guide.md（安全加固）
            └── Surge_Optimization_Guide.md（代理配置）

2026-04-07  Claude 防护研究 — 六层纵深防护指南 v1.0→v1.1
            ├── Claude_Protection_Guide.md
            ├── Claude_Protection_Audit.md（8 维度 40+ 项审计）
            └── Claude_Protection_Research.md（GitHub Issues + 社区深度调研）

2026-04-13  理念转变 v0.1.3→v0.1.4
            ├── "消失策略" → "融入策略"
            ├── 关闭遥测 = 极高封号风险 + 付费功能失效
            └── hosts 屏蔽被 API 级 Attribution Headers 绕过

2026-04-19  Swift 重写启动 — MacAudit 1.0
            ├── Package.swift 4 个 SPM 目标
            ├── 12 个审计模块遵循 AuditModule 协议
            └── 双副本架构（CLI + Core 框架）

2026-04-20  三专家审计第二轮 — 3 个新专家人设
            ├── 专家 A：密码学家（数据完整性）
            ├── 专家 B：系统工程师（资源生命周期）
            └── 专家 C：UX 人类学家（用户侧正确性）

2026-04-22  M1：macOS 15 VM 全面测试
            ├── 400-check × 3 轮一致性
            ├── 573 fixCommand 验证
            └── 首个综合测试基线

2026-04-23  M2：Tahoe 26 VM 全面测试
            ├── 400-check × 3 轮（100% 一致）
            ├── 336 fixCommand × 3 轮
            ├── 492 XCTest 全通过
            └── 发现 3 个 macOS 26 破坏性变更

2026-04-23  M3：Tahoe 26 补充测试
            └── 169 项补充测试

2026-04-24  M4：Tahoe 26 兼容性修复（9 次提交，89 文件，+3,190/-889 行）
            ├── DefaultsNormalizer — 修复 93 个 Animation 误报
            ├── FixEngine undo 增强 — PlistBuddy + 复合命令
            ├── Safari popup_block 拆分 — undo 正确性
            └── PrivacyModule 双副本统一
            结果：Safari 0%→93%，Animation 0%→93%，Privacy 29%→94%

2026-04-24  真机验证 — macOS 26.4.1 Tahoe (Intel)
            └── 7 类测试，70 个测试点，100% 通过率

2026-04-29  M5：GUI 改进 + A0 安全 TDD 迭代
            ├── AppViewModel 测试覆盖（38 测试）
            ├── AuditNotificationCenter（严重度分级 + 50 条上限）
            ├── IPCache 优化（OSAllocatedUnfairLock，6-11% 加速）
            ├── 6 项 A0 安全缺陷 TDD 修复
            │   ├── FixEngine Shell 注入防御
            │   ├── UndoValidator 白名单机制
            │   ├── ShellExecutor 管道死锁修复
            │   ├── FixHistory 非原子写入修复
            │   ├── IPv4Validator 统一（八进制歧义防御）
            │   └── AppViewModel executeCommand 结果追踪
            └── 3 轮代码评审：修复 3 CRITICAL + 5 WARNING

2026-05-01  全量优先级漂移修复 + AuditCheck 默认值安全化
            ├── 12 模块 MacAudit↔MacAuditCore 优先级同步（183 AuditCheck）
            ├── AuditCheck.init 默认值 .a0→.a3（防止静默 A0 提升）
            ├── GeoIP 数据中心检测增强（双 API OR 逻辑）
            ├── 10 个新 ModulePriorityConsistencyTests
            └── 3 轮评审：R1(4 CR)，R2(2 CR)，R3(全 PASS)

2026-05-05  双平台性能基准测试
            ├── macOS 15 VM：全量 ~10s，ip_quality 缓存 7.4s→6.6s (11%)
            └── macOS 26 VM：全量 ~10.4s，ip_quality 缓存 6.9s→6.5s (6%)
```

### 数字概览

| 指标 | 数值 |
|------|------|
| 开发周期 | ~30 天（2026 年 4 月 6 日 – 5 月 5 日） |
| 使用语言 | Python (v1.0) → Swift 6 (v0.1.x) |
| 总里程碑 | 5 个（M1–M5） |
| 审计模块数 | 12 个 |
| 总检测项 | 400+ |
| 单元测试 | 720+ |
| 专家审计轮次 | 15+（5 专家 × 5 轮 + 3 专家 × 2 轮 + 5 专家 × 3 轮） |
| 专家发现总数 | 180+（跨所有审计轮次） |
| M4 单里程碑提交 | 9 次（89 文件，+3,190/-889 行） |
| 真机测试点 | 70（100% 通过） |
| 修复闭环验证 | 10/10 PASS |
| 突变测试用例 | 15（0 崩溃） |
| 对抗检测率 | 85%（排除 Chrome MDM 限制后 100%） |
| 跨平台验证 | macOS 15 (arm64 + x86_64 VM) + macOS 26 (arm64 VM + x86_64 真机) |

### 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| AuditCheck.init 默认优先级 | `.a3`（非 `.a0`） | 防止 104+ 检测项因遗漏 `priority:` 字段而静默成为 A0 关键项 |
| shellEscape 策略 | 拒绝（非过滤） | 过滤清单难以穷举；macOS 有多种 Shell 变体；注释方案零风险 |
| ShellExecutor 管道读取 | `readabilityHandler` + 累加器 | `readDataToEndOfFile` 阻塞线程、忽略 Task 取消、超时可能死锁 |
| IPv4 校验 | 统一 `IPv4Validator` 枚举 | 分散逻辑易漂移不一致；前导零在 DNSBL 反向查询中造成八进制歧义 |
| IPCache 并发模型 | `@unchecked Sendable class` + 锁（非 actor） | actor 每次访问需 `await`；~100ns 读取的锁竞争概率极低 |
| ip_quality Phase B/C/D | 三路 `async let` 并行 | Phase C (DNSBL) 和 D (邮件端口) 不依赖 B 的结果；走不同 I/O 通道 |
| Claude 防护理念 | 融入策略，非消失策略 | 关闭遥测触发贝叶斯风控评分；hosts 屏蔽被 API 级 Attribution Headers 绕过 |

## 专家审计与代码评审

MacAudit 经历了多轮专家级代码评审，是同类工具中审计最彻底的项目之一。

### 五专家审计（5 专家 × 5 轮）

| 专家 | 人设 | 关注领域 |
|------|------|----------|
| 专家 1 | Steve Krug (UX) | 《别让我思考》— 可用性、可发现性、错误恢复 |
| 专家 2 | Robert C. Martin (整洁代码) | 《代码整洁之道》— 命名、函数、SRP、DRY、错误处理 |
| 专家 3 | Don Norman (设计) | 《设计心理学》— 示能性、意符、反馈、映射 |
| 专家 4 | Edsger Dijkstra (逻辑) | 结构化编程 — 正确性证明、不变量维护、边界情况 |
| 专家 5 | Kent Beck (TDD) | 测试驱动开发 — 红-绿-重构、测试覆盖、回归安全 |

**25 份个人评审 + 4 份综合报告 = 共 29 份文档**

### 三专家审计第二轮（3 专家 × 多轮循环）

| 专家 | 人设 | 关注领域 |
|------|------|----------|
| 专家 A | 密码学家 | 数据完整性、边界条件、编码、JSON 边界情况、正则正确性 |
| 专家 B | 系统工程师 | 资源生命周期、异步正确性、文件描述符泄漏、Task 取消 |
| 专家 C | UX 人类学家 | 用户侧正确性、locale 行为、无障碍、错误消息清晰度 |

**退出条件**：3 位专家连续 3 轮零发现。

### M4 工作计划评审（5 专家 × 3 轮）

| 专家 | 关注点 |
|------|--------|
| Dr. Elena (安全) | 注入风险、数据完整性 |
| Kenji (兼容性) | 跨版本行为、格式差异 |
| Sarah (架构) | 双副本一致性、比较引擎 |
| Raj (覆盖度) | 测试缺口、零覆盖模块 |
| Marcus (可靠性) | Undo 安全、超时处理 |

**21 条发现**（6 CRITICAL、9 HIGH、4 MEDIUM、2 LOW）— M4 执行前全部修复。

### 迭代 TDD 评审周期

每个主要功能经历 3 轮代码评审：

| 轮次 | 关注点 |
|------|--------|
| 第 1 轮 | 架构、安全、正确性 |
| 第 2 轮 | 边界情况、双副本一致性、回归 |
| 第 3 轮 | 最终验证、零缺陷确认 |

## 多模型 AI 协作

> **MacAudit 是一个 AI 原生项目 — 整个软件，从第一行 Python 到 720+ Swift 测试，全部由 AI 消耗 tokens 在数百个会话中、历时约 30 天构建完成。没有人类直接编写生产代码。**

六个前沿 AI 模型在全开发生命周期中协作，各自贡献独特优势：

| 模型 | 提供方 | 在 MacAudit 开发中的角色 |
|------|--------|--------------------------|
| **Claude Opus 4.7** | Anthropic | 主架构师 & 实现者 — 代码编写、TDD 迭代、3 轮代码评审 |
| **Claude Opus 4.6** | Anthropic | 架构规划、复杂重构（双副本同步、优先级漂移修复） |
| **Claude Sonnet 4.6** | Anthropic | 快速迭代循环、测试编写、快速验证 |
| **GPT 5.5** | OpenAI (Codex) | 交叉验证评审 — 通过 Rubrics 对计划和代码评审打分 |
| **Gemini 3.1 Pro** | Google | 创意头脑风暴、设计灵感、替代方案探索 |
| **GLM 5.1** | 智谱 AI | VM 环境测试与验证（GLM_VM_Audit），macOS 15 + Tahoe 26 跨平台验证 |

### AI 开发数字概览

| 指标 | 数值 |
|------|------|
| 总开发周期 | ~30 天 |
| 使用的 AI 模型 | 6+ |
| 估算总 tokens 消耗 | **约 26 亿+** 输入/输出 + **约 160 亿+** 缓存（跨所有模型和会话） |
| AI 生成代码行数 | 10,000+（生产代码 + 测试） |
| AI 生成测试用例 | 720+ |
| AI 执行专家审计轮次 | 15+ |
| AI 发现的 bug 和问题 | 180+ |

这种多模型方法提供了天然的交叉验证：每个模型独立发现其他模型遗漏的问题。`PENTA_EXPERT_AUDIT/` 和 `TRIPLE_EXPERT_AUDIT_R2.md` 文档记录了这种协作评审过程。模型之间也互为质量门控 — Codex 通过 Rubrics 对 Claude 的计划打分，Gemini 提供创意替代方案，GLM 在真实 VM 上验证结果。

## 研究与参考资料

所有参考资料已整理至 [`docs/references/`](docs/references/)，全部为 Markdown 格式。以下为完整目录。

### 内部研究文档

| # | 类别 | 文档 | 说明 |
|---|------|------|------|
| 1 | 安全 | Mac_System_Optimization_Guide.md | 系统安全加固指南（第 3 版终版） |
| 2 | 安全 | Surge_Optimization_Guide.md | Surge 代理配置优化指南（第 2 版） |
| 3 | 安全 | Surge_Config_Checklist.md | 完整 Surge 代理配置检查清单（含 .conf 模板和验证脚本） |
| 4 | Claude | Claude_Protection_Guide.md | 六层纵深防护指南 v1.1（L1 Surge→L6 沙盒） |
| 5 | Claude | Claude_Protection_Audit.md | 8 维度 40+ 项审计（P0/P1/P2 分级） |
| 6 | Claude | Claude_Protection_Research.md | GitHub Issues + 社区深度调研 |
| 7 | Claude | 2026-04-25_Claude_Protection_Analysis.md | 分析：34/397 检测项 (8.6%) 有直接 Claude 价值 |
| 8 | Claude | MacAudit_调优方案变更说明.md | v0.1.3→v0.1.4 理念转变："消失策略"→"融入策略" |
| 9 | 性能 | Mac_Perf_Optimize_Tahoe_26.md | Tahoe M4 Max 性能指南 |
| 10 | 性能 | Mac_Perf_Optimize_Sequoia_15.md | Sequoia M4 Max 性能指南 |
| 11 | 性能 | Mac_Perf_Optimize_Ventura_13.md | Ventura Intel i9 性能指南 |
| 12 | 性能 | Mac_Performance_Optimization_Guide.md | 通用 macOS 性能指南 |
| 13 | 开发环境 | Dev_Environment_Tahoe_26.md | Tahoe 开发环境搭建（10 章节 + Brewfile） |
| 14 | 开发环境 | Dev_Environment_Sequoia_15.md | Sequoia 开发环境搭建（含兼容性说明） |
| 15 | 开发环境 | Dev_Environment_Ventura_13.md | Ventura 开发环境搭建 |
| 16 | 审计 | Mac_Audit_Report.md | 系统审计报告 |
| 17 | 审计 | Sequoia分析.md | Sequoia vs Tahoe 差异分析 |

### 外部研究文章

| # | 文章 | 来源 | 核心洞察 |
|---|------|------|----------|
| 1 | Claude Code Account Ban Mechanism Exploration | 社区逆向工程 | Claude Code 封号机制：Attribution Headers、贝叶斯风控评分、cch Attestation |
| 2 | Claude-Ban-Experience | 用户报告 | 封号经历文档和恢复流程 |
| 3 | CODEX Claude Code Risk Research | Codex 分析 | AI 服务账号综合风险因素 |
| 4 | CODEX Claude Compliance Addon Checklist | Codex 审计 | Claude Code 合规验证清单 |
| 5 | CODEX Claude Compliance Addon Implementation Plan | Codex 规划 | 合规实现步骤指南 |

### 测试与审计报告

| # | 报告 | 范围 | 日期 |
|---|------|------|------|
| 1 | M4 完成总结 | Tahoe 兼容性修复：9 次提交，89 文件 | 2026-04-24 |
| 2 | M4 评审报告 | 5 专家 × 3 轮评审：21 条发现 | 2026-04-23 |
| 3 | Tahoe 真机测试报告 | 7 类测试，70 个测试点，100% 通过 | 2026-04-24 |
| 4 | Tahoe 26 物理测试计划 | 26 条历史翻车教训作为约束 | 2026-04-24 |
| 5 | Claude 防护分析 | 34/397 检测项 (8.6%) 有 Claude 价值 | 2026-04-25 |
| 6 | 发版检查清单 v0.2.0 | MVP 范围：约 85 项 A0 检测，6 个模块 | — |
| 7 | GLM VM 审计 — macOS 15 | 400-check × 3 轮，573 fixCommand | 2026-04-22 |
| 8 | GLM VM 审计 — Tahoe 26 | 400-check × 3 轮，336 fixCommand | 2026-04-23 |
| 9 | Tahoe 26 补充报告 | 169 项补充测试 | 2026-04-23 |
| 10 | macOS 15 vs 26 对比 | 跨版本行为差异 | 2026-04-23 |

### 引用的开源项目

| 项目 | 地址 | 用途 |
|------|------|------|
| **Lynis** | [github.com/CISOfy/lynis](https://github.com/CISOfy/lynis) | 对抗安全测试方法论；多类别审计模块设计 |
| **Google Santa** | [github.com/google/santa](https://github.com/google/santa) | 配置覆盖/突变测试模式（注：2025 年 2 月已归档，分支为 [northpolesec/santa](https://github.com/northpolesec/santa)） |
| **NIST macOS Security Configuration** | [github.com/usnistgov/macos_security](https://github.com/usnistgov/macos_security) | 原子修复闭环验证；CIS 基准映射（最新：Tahoe Guidance Rev 2.0） |
| **osquery** | [github.com/osquery/osquery](https://github.com/osquery/osquery) | 基于属性的幂等性测试；并发查询安全模式 |
| **swift-argument-parser** | [github.com/apple/swift-argument-parser](https://github.com/apple/swift-argument-parser) | 快照对比测试；CLI 架构模式 |
| **claudit** | [github.com/nicholasaleks/claudit](https://github.com/nicholasaleks/claudit) | Claude Code 安全审计方法论；对抗测试模式 |
| **Claude Code Ban Research (instructkr)** | [github.com/instructkr/claude-code](https://github.com/instructkr/claude-code) | 网络流量分析；Attribution Header / cch Attestation 逆向工程；封号机制研究 |
| **cc-shield** | [github.com/waltertech/cc-shield](https://github.com/waltertech/cc-shield) | Claude Code 账号保护（遥测禁用、设备指纹清理）；MacAudit 53 项检测模块提供全面超集 |

### 泄露源码逆向分析

Claude 防护模块基于 **对 5 个版本的 Claude Code 泄露源码的深度逆向工程**，提供了对 Anthropic 客户端遥测、风控评分和封号机制的无与伦比的洞察：

| 分析维度 | 发现内容 |
|----------|----------|
| **3 个数据上报通道** | Datadog（80+ 事件类型）、1P BigQuery（完整遥测 + OAuth 认证）、GrowthBook（特性开关 + A/B 测试） |
| **Attribution Header** | 每个 API 请求携带 `x-anthropic-billing-header`，含版本指纹 + 入口点 + cch 证明 |
| **cch Attestation** | 原生客户端证明 — 核心反作弊机制；修改过的客户端无法生成有效 token |
| **指纹算法** | `SHA256(SALT + msg[4] + msg[7] + msg[20] + version)[:3]` — 硬编码盐值 `59cf53e54c78` |
| **Device ID** | 跨账号永久设备指纹，存储在 `~/.claude.json` |
| **服务端检查** | `ANTHROPIC_BASE_URL` 和 `NODE_TLS_REJECT_UNAUTHORIZED` 被明确标记为危险变量 |
| **贝叶斯风控评分** | 关闭遥测触发风险标签；GrowthBook 特性开关对被标记账号静默禁用 Opus/Fast Mode |

这些分析直接催生了 53 项 Claude 防护检测模块和 v0.1.4 的理念转变。所有发现记录在 [`docs/references/articles/`](docs/references/articles/)。

## 兼容性

| macOS 版本 | 代号 | 架构 | 状态 |
|------------|------|------|------|
| macOS 15.x | Sequoia | Apple Silicon (arm64) | 完全支持 & 已测试 |
| macOS 15.x | Sequoia | Intel (x86_64) | 完全支持 & 已测试 |
| macOS 26.x | Tahoe | Apple Silicon (arm64) | 完全支持 & 已测试 |
| macOS 26.x | Tahoe | Intel (x86_64) | 完全支持 & 真机已测试 |
| macOS 13.x | Ventura | 任意 | 仅参考（有优化指南可用） |

所有二进制均为**通用二进制**（arm64 + x86_64）— 单一构建即可在两种架构上运行。

## 路线图

- [ ] **v0.2.0 MVP** — `--mvp` 标志仅 A0 CLI、CheckPriority 标记、报告中延迟检测项
- [ ] **v0.3.0** — 本地化（English + 中文）、VoiceOver 无障碍
- [ ] **v0.4.0** — 统一模块架构（消除双副本模式）
- [ ] **v0.5.0** — `macaudit daemon` 守护进程模式，定时审计
- [ ] **v1.0.0** — 稳定 API、完善文档、Homebrew formula

> **最新测试结果、兼容性更新和发版说明发布在 [GitHub](https://github.com/Clauder-help-Clauder/Claude-MacAudit)。**

## 致谢

MacAudit 站在开源安全社区的肩膀上。特别感谢：

- **[Lynis](https://github.com/CISOfy/lynis)** — Unix 安全审计的金标准；MacAudit 的对抗测试方法论和模块化架构直接受 Lynis 启发
- **[Google Santa](https://github.com/google/santa)** — 配置覆盖测试模式；突变测试方法改编自 Santa 的策略验证
- **[osquery](https://github.com/osquery/osquery)** — 基于 SQL 的系统监控模式；基于属性的幂等性测试和并发查询安全测试
- **[NIST macOS Security Configuration (mSCP)](https://github.com/usnistgov/macos_security)** — CIS 基准覆盖度分析；原子修复闭环验证方法论
- **[swift-argument-parser](https://github.com/apple/swift-argument-parser)** — CLI 架构模式；快照对比测试方法
- **[claudit](https://github.com/nicholasaleks/claudit)** — Claude Code 安全审计框架；AI 服务配置的对抗测试模式
- **[Claude Code Ban Research (instructkr)](https://github.com/instructkr/claude-code)** — **关键网络流量分析**，推动了我们从"消失策略"到"融入策略"的理念转变；Attribution Headers、cch Attestation 和贝叶斯风控评分机制的逆向工程
- **Netflix Chaos Monkey** — 适配于本地 macOS 测试的混沌工程原则
- **Surge Pro** ([nssurge.com](https://nssurge.com/)) — 贯穿开发和测试的代理与网络分析工具
- **Apple Swift 团队** — Swift 6 严格并发模型使 MacAudit 的 Actor 架构成为可能
- **[wstormai](https://wstormai.store/)** — 在整个开发和测试期间提供稳定可靠的订阅充值渠道

## 贡献指南

详见 [CONTRIBUTING_CN.md](CONTRIBUTING_CN.md)，包含代码风格、测试要求、PR 流程等。

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

---

<div align="center">

**[Clauder-help-Clauder](https://github.com/Clauder-help-Clauder)**

Swift 6 构建 · 零运行时依赖 · 为 macOS 设计

从 Python 脚本到原生应用 — 2 个操作系统世代、2 种架构、70+ 测试点验证

**最新更新：[github.com/Clauder-help-Clauder/Claude-MacAudit](https://github.com/Clauder-help-Clauder/Claude-MacAudit)**

</div>
