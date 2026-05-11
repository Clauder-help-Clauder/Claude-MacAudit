# MacAudit 各模块对 Claude 防护的价值分析

**日期**: 2026-04-25
**分析依据**: MacAudit v0.1.5 全部源码 + macOS 26.4.1 Tahoe 真机测试 (397 checks)
**背景**: 评估 397 个 check 中哪些对 Claude Code / Claude Desktop 用户有实际防护价值

---

## 一、评估框架

Claude 用户的威胁模型:

| 威胁 | 严重性 | 说明 |
|------|--------|------|
| 封号 (风控触发) | 致命 | 关闭遥测/地区暴露 → GrowthBook 禁用 → 账号异常标记 |
| IP 地理泄露 | 致命 | IPv6 直连/DNS 泄露/WebRTC → 暴露真实地区 |
| API Key 泄露 | 高 | 子进程继承环境变量 → 凭据外泄 |
| 对话训练 | 中 | enableTraining=true → 对话内容保留 5 年 |
| 系统遥测暴露地区 | 低 | Apple 遥测本身不影响 Claude，但与 Privacy 模块重复检测 |

评判标准:
- **直接价值**: 该 check 检测的配置直接影响 Claude 风控/安全
- **间接价值**: 通用安全加固，对 Claude 有边际帮助
- **零价值**: 与 Claude 威胁模型无关

---

## 二、ClaudeProtectionModule (m10) — 52 checks

### 直接价值 (34 checks)

**B 组: 风控风险变量 (7 checks)** — 核心中的核心

| checkId | 检测内容 | 为什么对 Claude 重要 |
|---------|---------|---------------------|
| m10.env_no_disable_traffic | DISABLE_NONESSENTIAL_TRAFFIC | 关闭后 GrowthBook 禁用 → Opus 4.6 消失、Fast Mode 不可用、且成为风控异常用户 |
| m10.env_no_disable_survey | DISABLE_FEEDBACK_SURVEY | 遥测关闭链路一环，增加地域风险标签 |
| m10.env_no_disable_telemetry | DISABLE_TELEMETRY | 最危险设置之一，与上面效果相同 |
| m10.env_no_custom_api | ANTHROPIC_BASE_URL | 服务端标记为「危险环境变量」，设置后被特别关注 |
| m10.env_no_tls_skip | NODE_TLS_REJECT_UNAUTHORIZED | 跳过 TLS 验证，服务端危险变量 |
| m10.env_no_otel_prompts | OTEL_LOG_USER_PROMPTS | 将用户 Prompt 文本上传遥测 (极高隐私风险) |
| m10.env_no_otel_tools | OTEL_LOG_TOOL_CONTENT | 将所有工具调用内容上传遥测 |

**A 组: 安全环境变量 (5 checks)**

| checkId | 价值 |
|---------|------|
| m10.env_claude_code_proxy_re | 代理 DNS 解析，防止 IP 泄露 |
| m10.env_claude_enable_stream | 流监控看门狗，提升 Claude Code 稳定性 |
| m10.env_claude_code_subproce | 子进程凭据清洗，防止 API Key 泄露 |
| m10.env_claude_stream_idle_t | 流空闲超时，防止连接挂死 |

**地理/身份信号 (7 checks)**

| checkId | 价值 |
|---------|------|
| m10.device_id | deviceId 是跨账号永久指纹，封号后关联新账号 |
| m10.git_email_leak | git email 被 GrowthBook 采集为身份信号 |
| m10.npm_registry | npmmirror/tuna 是强地理位置信号 |
| m10.tz_info | TZ 与代理 IP 地区不一致 = 穿帮 |
| m10.lang_check | LANG=zh_CN 暴露中文地区特征 |
| m10.lc_all_check | LC_ALL 覆盖 LANG 暴露地区 |
| m10.macos_lang | 系统语言首选项为中文暴露地区 |

**网络防护 (8 checks)**

| checkId | 价值 |
|---------|------|
| m10.proxy_https | HTTPS_PROXY 强制出口代理 |
| m10.ipv6_global | IPv6 全局地址可绕过代理直连 |
| m10.wifi_ipv6 | Wi-Fi IPv6 同上 |
| m10.ipv6_rtadv | IPv6 路由通告 |
| m10.ipv6_fwd | IPv6 转发 |
| m10.surge_stun_reject | Surge STUN 拦截防止 WebRTC IP 泄露 |
| m10.sandbox_proxy | 沙盒代理端口限制 Claude 网络范围 |
| m10.sandbox_domains | 沙盒域名白名单 |

### 间接价值 (13 checks)

**防火墙/安全工具 (5 checks)**

| checkId | 价值 | 说明 |
|---------|------|------|
| m10.fw_global | 防火墙开启 | 防止未授权入站连接，但 Claude Code 本身需要出站 |
| m10.fw_stealth | 防火墙隐身 | 防止端口探测，与 Claude 无直接关系 |
| m10.fw_signed | 防火墙签名 | 避免误阻断 Claude Code |
| m10.lulu | LuLu 安装 | 出站防火墙，可监控 Claude Code 网络行为 |
| m10.knockknock | KnockKnock 安装 | 持久化检测，通用安全工具 |

**Surge/代理辅助 (3 checks)**

| checkId | 价值 |
|---------|------|
| m10.surge_dns | Surge Fake IP DNS，前提是用 Surge |
| m10.surge_tun | Surge TUN 接口，前提是用 Surge |
| m10.surge_dashboard | Surge Dashboard，前提是用 Surge |

**代理辅助 (3 checks)**

| checkId | 价值 |
|---------|------|
| m10.all_proxy_on_func | all_proxy_on 函数定义 |
| m10.all_proxy_off_func | all_proxy_off 函数定义 |
| m10.env_no_proxy | NO_PROXY 排除规则 |

**其他 (2 checks)**

| checkId | 价值 |
|---------|------|
| m10.claude_improve | enableTraining 对话训练开关 |
| m10.claude_version | Claude Code 版本 |

### 零价值 — Apple 遥测重复检测 (5 checks)

代码注释自己写了: `macOS 遥测禁用（Apple 遥测，与 Claude 风控无关）`

| checkId | 重复自 | 说明 |
|---------|--------|------|
| m10.telemetry_diaginfo | m4.diagnostics | com.apple.SubmitDiagInfo AutoSubmit |
| m10.telemetry_crashreporter | m4.crash_reporter | com.apple.CrashReporter DialogType |
| m10.telemetry_adlib | m4.ad_tracking | com.apple.AdLib |
| m10.telemetry_usage1 | — | com.apple.UsageTracking，Claude 不采集 |
| m10.telemetry_usage2 | — | com.apple.UsageTracking，Claude 不采集 |

T2 对抗测试已证实: 修改 Privacy 模块的 key，Claude 模块的 telemetry check 同时变化。这不是"防御纵深"，是纯重复。

---

## 三、Chrome 模块 (m14) — 13 checks — 零价值

Chrome 浏览器策略检测对 Claude 防护**完全没有帮助**:

| 事实 | 说明 |
|------|------|
| Claude Code 是 CLI 工具 | 不使用任何浏览器 |
| Claude Desktop 是 Electron 应用 | 内嵌 Chromium，但不受 Chrome 企业策略控制 |
| Chrome 策略只影响 Chrome 浏览器 | WebRTC/DNS/遥测设置对 Claude 进程无影响 |

根据 Chrome 官方文档 (support.google.com/chrome/a/answer/9037717):
- Chrome 策略通过 macOS Managed Preferences 推送
- 优先级: Platform > Machine Cloud > OS User > Chrome Profile
- 个人机器无 Managed Preferences → 所有策略 check = fail
- 这 12 个 fail 是真实的 (Chrome 默认行为确实不安全)，但与 Claude 无关

**真机测试结果**: Chrome 13 checks = 1 pass (installed) + 12 fail (无策略)

---

## 四、其他模块价值速览

| 模块 | checks | 对 Claude 的价值 | 说明 |
|------|--------|-----------------|------|
| Privacy (m4) | 17 | 低 | Apple 隐私设置，与 Claude 风控无关。部分与 m10 重复 |
| NetworkSecurity (m8) | 44 | 低 | 通用网络加固。sysctl/防火墙对 Claude 无直接影响 |
| Safari (m15) | 14 | 零 | Safari 浏览器设置，与 Claude 无关 |
| Animation (m5) | 43 | 零 | UI 动画/文件扩展名显示，纯视觉偏好 |
| Power (m7) | 26 | 零 | 电源管理，与 Claude 无关 |
| Services (m3) | 70 | 零 | 系统服务开关，通用加固 |
| Shell (m9) | 19 | 低 | Shell 环境配置，代理函数有间接价值 |
| Dev (m11) | 64 | 零 | 开发工具检测，信息展示 |
| SystemInfo (m1) | 12 | 零 | 硬件信息，纯展示 |
| IPQuality (m6) | 23 | 低 | IP 信誉/DNS 黑名单，有间接参考价值 |

---

## 五、总结

### 价值分布

```
直接价值 (Claude 风控/安全直接相关)    34 checks  ( 8.6%)
间接价值 (通用安全，对 Claude 有边际帮助)  13 checks  ( 3.3%)
零价值 — Apple 遥测重复                 5 checks  ( 1.3%)
零价值 — 其他模块                     345 checks ( 86.9%)
─────────────────────────────────────────────────
总计                                  397 checks (100%)
```

### 核心发现

1. **397 个 check 中只有 34 个 (8.6%) 对 Claude 防护有直接价值**，全部集中在 ClaudeProtectionModule 的 B 组风控检测、A 组安全变量、地理信号和网络防护四个区域

2. **Chrome 模块 13 个 check 对 Claude 零价值**。Chrome 官方文档确认策略只影响 Chrome 浏览器，不影响 Claude Code (CLI) 或 Claude Desktop (Electron)

3. **Apple 遥测 5 个 check 是纯重复**。代码注释已承认"与 Claude 风控无关"，且与 PrivacyModule 读完全相同的 defaults key

4. **信号被噪音淹没**: 真正致命的风控风险 (如 DISABLE_TELEMETRY) 在 55 fail + 60 warn 的报告中只是一行，用户很难注意到

### 建议优化

| 优先级 | 建议 | 影响 |
|--------|------|------|
| P0 | ClaudeProtectionModule 独立输出「风控风险评分」| 让用户一眼看到 Claude 专属风险 |
| P1 | 删除 m10.telemetry_* 5 条重复 check | 减少 5 个噪音项 |
| P2 | Chrome 模块在非 MDM 环境标 info 而非 fail | 减少 12 个误导性 fail |
| P3 | 报告中按「Claude 相关」/「通用加固」分区 | 改善信息架构 |
