# Mac System Audit

> 三台 Mac 的系统审计、安全加固、效能优化与开发环境配置

 Claude_Protection_Guide.md v1.1 — 已完成全部修订：
  - 六层纵深防护架构（新增 L6 沙盒隔离）
  - 11 项深度调研发现已整合
  - 三系统兼容性差异表
  - 条件性 encrypted-dns-follow-outbound-mode 建议

  Claude_Protection_Audit.md — 正式审计报告：
  - 8 大审计维度，40+ 项逐条验证
  - P0/P1/P2 分级修正建议
  - GitHub Issues 调研（#39862, #33642, #43954, #44395）
  - 新发现：SUBPROCESS_ENV_SCRUB、沙盒网络隔离、TLS 指纹修复

  可选后续操作：
  1. 在三台机器上执行验证脚本，确认当前配置状态
  2. OVERSEA DoH 改用 IP 形式（dns.google → https://8.8.8.8/dns-query）以安全启用 encrypted-dns-follow-outbound-mode
  3. 部署 pf Kill Switch（可选加固）



## 适用系统

| 机器 | 系统 | 芯片 | 架构 |
|------|------|------|------|
| Mac Studio | macOS Tahoe 26.4 | M4 Max | arm64 |
| MacBook Pro | macOS Sequoia 15.7.5 | M4 Max | arm64 |
| iMac | macOS Ventura 13.7.8 | Intel i9 | x86_64 |

## 文档索引

### 安全加固

| 文档 | 说明 |
|------|------|
| [Mac_System_Optimization_Guide.md](Mac_System_Optimization_Guide.md) | macOS 系统级安全加固（防火墙、隐私、网络） |
| [Surge_Optimization_Guide.md](Surge_Optimization_Guide.md) | Surge Pro 代理配置优化 |
| [OVERSEA-CA-CLAUDE.conf](OVERSEA-CA-CLAUDE.conf) | Surge 托管配置（生产环境终版） |

### Claude 防护

| 文档 | 说明 |
|------|------|
| [Claude_Protection_Guide.md](Claude_Protection_Guide.md) | Claude Code 综合防护指南 v1.1 — 六层纵深防护架构 |
| [Claude_Protection_Audit.md](Claude_Protection_Audit.md) | 防护指南审计报告 — 对照 OVERSEA 配置 + 三系统兼容性 + 深度调研 |
| [Claude_Protection_Research.md](Claude_Protection_Research.md) | 深度调研原始数据（GitHub Issues、社区、官方文档） |

### 效能优化（按系统）

| 文档 | 说明 |
|------|------|
| [Mac_Perf_Optimize_Tahoe_26.md](Mac_Perf_Optimize_Tahoe_26.md) | Tahoe 26.4 效能优化（含 Claude 防护段） |
| [Mac_Perf_Optimize_Sequoia_15.md](Mac_Perf_Optimize_Sequoia_15.md) | Sequoia 15.7.5 效能优化 |
| [Mac_Perf_Optimize_Ventura_13.md](Mac_Perf_Optimize_Ventura_13.md) | Ventura 13.7.8 效能优化 |
| [Mac_Performance_Optimization_Guide.md](Mac_Performance_Optimization_Guide.md) | 效能优化通用指南 |

### 开发环境

| 文档 | 说明 |
|------|------|
| [Dev_Environment_Tahoe_26.md](Dev_Environment_Tahoe_26.md) | Tahoe 开发环境配置 |
| [Dev_Environment_Sequoia_15.md](Dev_Environment_Sequoia_15.md) | Sequoia 开发环境配置 |
| [Dev_Environment_Ventura_13.md](Dev_Environment_Ventura_13.md) | Ventura 开发环境配置 |

### 审计与分析

| 文档 | 说明 |
|------|------|
| [Mac_Audit_Report.md](Mac_Audit_Report.md) | 系统审计报告 |
| [Sequoia分析.md](Sequoia分析.md) | Sequoia 差异分析（基础材料） |
| [mac_audit.sh](mac_audit.sh) | 审计采集脚本 |

### 原始数据

`*_audit.txt` / `*.list` — 审计脚本采集的原始输出（dns、env、git、hosts、zshrc 等）
