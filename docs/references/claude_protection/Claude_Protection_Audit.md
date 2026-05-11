# Claude 综合防护指南 — 审计报告

> 审计日期：2026-04-07
> 审计对象：Claude_Protection_Guide.md v1.0
> 对照配置：OVERSEA-CA-CLAUDE.conf（托管配置）
> 验证来源：code.claude.com 官方文档、GitHub Issues、社区调研
> 适用系统：Tahoe 26.4 / Ventura 13.7.8 / Sequoia 15.7.5

---

## 审计摘要

| 类别 | 发现数 | 需修正 | 需补充 | 确认正确 |
|------|:------:|:------:|:------:|:--------:|
| 环境变量 | 5 | 0 | 3 | 2 |
| Surge 配置 | 6 | 1 | 2 | 3 |
| 本地防护 | 4 | 0 | 1 | 3 |
| DNS/网络 | 3 | 1 | 0 | 2 |
| 已知 Bug | 7 | 0 | 2 | 5 |
| 三系统兼容 | 15 | 0 | 5 | 10 |
| 深度调研新发现 | 6 | — | 6 | — |

---

## 一、环境变量审计

### ✅ 确认正确

| 变量 | 指南描述 | 官方文档 | 状态 |
|------|---------|---------|:----:|
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` | 一键禁用遥测+错误报告+自动更新+反馈 | ✅ 等同于 `DISABLE_AUTOUPDATER` + `DISABLE_FEEDBACK_COMMAND` + `DISABLE_ERROR_REPORTING` + `DISABLE_TELEMETRY` | ✅ |
| `CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1` | 代理执行 DNS 解析 | ✅ 允许代理执行 DNS 解析而非调用者 | ✅ |
| `CLAUDE_ENABLE_STREAM_WATCHDOG=1` | 90 秒中止失速流 | ✅ 中止 90 秒内无数据的 API 响应流 | ✅ |

### ⚠️ 需补充

| # | 发现 | 严重性 | 说明 |
|:-:|------|:------:|------|
| E1 | `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1` 未收录 | LOW | 禁用 "How is Claude doing?" 会话质量调查，属于遥测类，建议加入 |
| E2 | `DISABLE_UPGRADE_COMMAND=1` 未收录 | LOW | 隐藏 `/upgrade` 命令，配合 `DISABLE_AUTOUPDATER` 更完整 |

### ❌ 需修正

| # | 发现 | 严重性 | 说明 |
|:-:|------|:------:|------|
| E3 | 指南声称 "ALL_PROXY=socks5:// — Claude Code 官方不支持 SOCKS 代理" | MEDIUM | ✅ 结论正确，但应明确引用官方文档原文："Claude Code does not support SOCKS proxies." |

### ℹ️ 信息性补充

| # | 发现 | 说明 |
|:-:|------|------|
| E4 | `NO_PROXY` 格式支持空格分隔和逗号分隔两种 | 官方文档示例同时展示了两种格式，指南中的逗号格式正确 |
| E5 | `CLAUDE_CODE_ENABLE_TELEMETRY` 为 OpenTelemetry 变量 | 与 `DISABLE_TELEMETRY`（Statsig）是不同系统，互不冲突 |

---

## 二、Surge 配置审计（OVERSEA-CA-CLAUDE.conf 对照）

### ✅ 确认一致

| 项目 | 指南 | OVERSEA 配置 | 状态 |
|------|------|-------------|:----:|
| `dns-server = system` | ✅ | ✅ 第 7 行 | 一致 |
| `ipv6 = false` | ✅ | ✅ 第 10 行 | 一致 |
| `proxy-test-url` 通用化 | `cp.cloudflare.com` | ✅ 第 11 行 | 一致 |
| WebRTC STUN REJECT | 完整规则 | ✅ 第 52 行 | 一致 |
| DOMAIN-KEYWORD 兜底 | anthropic + claude | ✅ 第 55-56 行 | 一致 |
| FINAL,DIRECT | 直连设计 | ✅ 第 59 行 | 一致 |

### ❌ 需修正

| # | 发现 | 严重性 | 详情 |
|:-:|------|:------:|------|
| S1 | **`encrypted-dns-follow-outbound-mode` 建议需细化** | HIGH | 指南 §2.1 原推荐启用，OVERSEA 配置说"不启用"。<br>**深度调研结论**：循环依赖仅在 DoH 用域名时发生。若 DoH 改用 IP 形式（如 `https://8.8.8.8/dns-query`）则可安全启用。当前 OVERSEA 使用 `dns.google`（域名），因此**当前配置下不应启用**。<br>**修正**：指南已改为条件性建议，解释两种场景 |
| S2 | **`Claude-Reach` 测试 URL 仍为 `docs.anthropic.com`** | MEDIUM | 指南 §3.3 建议改为 `cp.cloudflare.com`，但 OVERSEA 第 26 行故意保留并注释："故意用 docs.anthropic.com 测试 Anthropic 可达性（返回 301，轻量）"。<br>**分析**：两种方案各有优劣。`docs.anthropic.com` 能验证 Anthropic 真实可达，但可能暴露意图；`cp.cloudflare.com` 更隐蔽但只测线路通畅不测目标可达。由于请求走代理，意图暴露风险较低。<br>**修正**：指南应保留两种方案并解释各自利弊，不强制修改 |

### ⚠️ 需补充

| # | 发现 | 严重性 | 详情 |
|:-:|------|:------:|------|
| S3 | **更新域名规则缺失** | MEDIUM | OVERSEA 不含 `storage.googleapis.com` 和 `downloads.claude.ai` 规则。官方文档确认这两个域名是安装/更新所必需的。由于 `FINAL,DIRECT` 设计，这些域名走直连。<br>**建议**：安装/更新时临时添加规则，或保持直连（更新流量不含敏感信息） |
| S4 | **RustDesk 端口静默丢弃** | LOW | OVERSEA 第 31 行 `DEST-PORT,21114,REJECT-DROP` 未在指南提及。属于项目特定配置，可选择性添加 |
| S5 | **第三方服务规则设计差异** | INFO | 指南列出 sentry/stripe/launchdarkly/statsig 独立 DOMAIN-SUFFIX 规则，OVERSEA 依赖 KEYWORD 兜底（第 58 行注释说明）。两种方案等效，KEYWORD 兜底更简洁但不够精确。<br>**建议**：指南标注"独立规则为完整版，KEYWORD 兜底为精简版" |

### 📋 OVERSEA [Host] 段覆盖度检查

OVERSEA 配置的 `[Host]` 段（第 62-73 行）为以下域名指定 DoH：

| 域名 | 通配符 | 裸域 | 状态 |
|------|:------:|:----:|:----:|
| anthropic.com | ✅ | ✅ | 完整 |
| claude.ai | ✅ | ✅ | 完整 |
| claude.com | ✅ | ✅ | 完整 |
| claude.dev | ✅ | ✅ | 完整 |
| claudeusercontent.com | ✅ | ✅ | 完整 |
| anthropic.ai | ❌ | ❌ | **缺失** |
| anthropic-ai.com | ❌ | ❌ | **缺失** |
| claudeai.com | ❌ | ❌ | **缺失** |

> **S6**（LOW）：`[Host]` 段缺少 `anthropic.ai`、`anthropic-ai.com`、`claudeai.com` 的 DoH 指定。这些是品牌保护域名，实际请求量极少，但为完整性建议补充。

---

## 三、本地防护审计

### ✅ 确认正确

| 项目 | 状态 | 说明 |
|------|:----:|------|
| hosts 22 条域名屏蔽 | ✅ | 覆盖所有官方必需域名 |
| macOS 防火墙 + 隐身模式 | ✅ | 命令正确，三系统通用 |
| LuLu 出站防火墙 | ✅ | brew 安装方式正确 |

### ⚠️ 需补充

| # | 发现 | 严重性 | 详情 |
|:-:|------|:------:|------|
| L1 | **hosts 刷新命令缺失** | MEDIUM | 修改 `/etc/hosts` 后需要刷新 DNS 缓存才能生效。指南未提及刷新命令。<br>**补充**：`sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` |

---

## 四、DNS/网络审计

### ✅ 确认正确

| 项目 | 状态 | 说明 |
|------|:----:|------|
| Surge Fake IP 198.18.0.2 | ✅ | 增强模式下接管系统 DNS |
| 代理开关函数 proxy_on/proxy_off | ✅ | 环境变量设置正确 |

### ❌ 需修正

| # | 发现 | 严重性 | 详情 |
|:-:|------|:------:|------|
| D1 | **CN 配置不存在** | MEDIUM | 指南 §2.1 提到"CN 配置修改：找到 `dns-server = 119.29.29.29, 223.5.5.5, system` 替换为 `dns-server = system`"，但项目中无 CN 配置文件。<br>**修正**：标注此建议仅适用于有 CN 配置的场景，或移除 CN 特定内容 |

---

## 五、已知 Bug 审计

指南列出 5 个 Bug，验证状态：

| Bug | Issue | 当前状态 | 指南准确性 |
|-----|-------|---------|:----------:|
| NO_PROXY 被忽略 | #39862 | 需验证是否在新版本修复 | ⚠️ 待确认 |
| OAuth 不走 CONNECT | #33642 | 需验证 | ⚠️ 待确认 |
| CONNECT 隧道挂起 | #43954 | Linux 问题，macOS 未报告 | ✅ 标注正确 |
| SOCKS 不支持 | — | 官方文档确认 | ✅ |
| 遥测残留 Google | #10494 | Anthropic 标记 Not Planned | ✅ |

---

## 六、三系统兼容性审计

### macOS 版本概况

| 项目 | Tahoe 26.4 | Sequoia 15.7.5 | Ventura 13.7.8 |
|------|:----------:|:--------------:|:--------------:|
| 芯片 | M4 Max | M4 Max | Intel i9 |
| 架构 | arm64 | arm64 | x86_64 |
| Homebrew 路径 | `/opt/homebrew/bin` | `/opt/homebrew/bin` | `/usr/local/bin` |
| Intel 支持 | ✅（最后一版） | ❌ 不适用 | ✅ 原生 |
| Liquid Glass UI | ✅ 全新设计 | ❌ | ❌ |

> **关键发现**：macOS Tahoe 26 是**最后一个支持 Intel 处理器的 macOS 版本**（Wikipedia 确认）。Ventura 13.7.8 的 Intel i9 仍在支持范围内，但未来升级路径有限。

### 命令兼容性详表

| 命令/操作 | Tahoe 26.4 | Sequoia 15.7.5 | Ventura 13.7.8 | 风险 | 备注 |
|----------|:----------:|:--------------:|:--------------:|:----:|------|
| **防火墙** | | | | | |
| `socketfilterfw --setglobalstate on` | ✅ | ✅ | ✅ | 无 | 路径三版本一致 |
| `socketfilterfw --setstealthmode on` | ✅ | ✅ | ✅ | 无 | |
| `socketfilterfw --setallowsigned on` | ⚠️ | ✅ | ✅ | 低 | Tahoe Liquid Glass UI 变化，CLI 未变，建议验证 |
| **IPv6 禁用** | | | | | |
| `networksetup -setv6off "Wi-Fi"` | ⚠️ | ✅ | ✅ | **高** | **必须先动态获取服务名** |
| `networksetup -setv6off "Ethernet"` | ⚠️ | ⚠️ | ✅ | 中 | M4 Max 可能无内建以太网 |
| `networksetup -setv6off "Thunderbolt Bridge"` | ⚠️ | ⚠️ | ✅ | 中 | 仅 Intel 有 |
| **sysctl IPv6** | | | | | |
| `sysctl -w net.inet6.ip6.accept_rtadv=0` | ✅ | ✅ | ✅ | 无 | XNU 内核，ARM/x86 一致 |
| `sysctl -w net.inet6.ip6.forwarding=0` | ✅ | ✅ | ✅ | 无 | |
| **defaults 遥测** | | | | | |
| `com.apple.SubmitDiagInfo AutoSubmit` | ✅ | ✅ | ✅ | 无 | |
| `com.apple.CrashReporter DialogType` | ✅ | ✅ | ✅ | 无 | |
| `com.apple.assistant.support Siri*` | ⚠️ | ✅ | ✅ | 低 | Tahoe Siri+Apple Intelligence 深度整合，键有效但建议 UI 验证 |
| `com.apple.AdLib` | ⚠️ | ✅ | ✅ | 中 | Tahoe AdLib 框架可能调整 |
| `com.apple.UsageTracking` | ✅ | ✅ | ⚠️ | 中 | Ventura 早期引入，13.7.x 应存在但需确认 |
| `CaptiveNetworkSupport Active` | ⚠️ | ✅ | ✅ | 中 | Tahoe 路径可能有细微变化 |
| `mDNSResponder NoMulticastAdvertisements` | ✅ | ✅ | ✅ | 无 | |
| **DNS/网络** | | | | | |
| `scutil --dns` | ✅ | ✅ | ✅ | 无 | |
| `dscacheutil -flushcache` | ✅ | ✅ | ✅ | 无 | |
| `killall -HUP mDNSResponder` | ✅ | ✅ | ✅ | 无 | |
| **第三方工具** | | | | | |
| LuLu 4.3.1 (brew) | ✅ | ✅ | ✅ | 无 | **v4.0.0 明确标注 "macOS 26 Compatibility"** |
| Surge Pro | ✅ | ✅ | ✅ | 无 | |
| `/etc/hosts` 修改 | ✅ | ✅ | ✅ | 无 | |
| **pf 防火墙** | ✅ | ✅ | ✅ | 无 | SIP 不限制 pf |

### 风险矩阵

| 风险 | 涉及项 | 建议 |
|:----:|--------|------|
| **高** | `networksetup -setv6off` 写死服务名 | 改用脚本动态读取 |
| **中** | `UsageTracking`(Ventura)、`AdLib`/`CaptiveNetworkSupport`(Tahoe) | `defaults read` 验证 |
| **低** | `socketfilterfw`(Tahoe)、Siri plist(Tahoe) | UI 二次确认 |
| **无** | sysctl、pf、hosts、LuLu、scutil | 三版本一致 |

### 特别注意事项

#### Ventura 13.7.8 Intel i9 升级路径

> **关键**：Tahoe 26 仅支持特定 Intel 型号（Mac Pro 2019、MacBook Pro 16" 2019、iMac 2020 等）。需核实 Ventura i9 具体型号是否在列表内，否则该机器"最终版本"为 Sequoia 15.x。

#### 部署脚本建议

```bash
# 动态获取所有网络服务并禁用 IPv6
for service in $(networksetup -listallnetworkservices | tail -n +2); do
  sudo networksetup -setv6off "$service" 2>/dev/null
done
```

---

## 七、修正建议汇总（按优先级）

### P0 — 必须修正

| # | 项目 | 修正内容 |
|:-:|------|---------|
| S1 | `encrypted-dns-follow-outbound-mode` | 改为条件性建议：域名 DoH 不启用，IP DoH 可安全启用 |
| R7 | `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` | 新增到环境变量清单（强烈推荐） |
| R8 | 沙盒网络隔离 | 新增配置段，`httpProxyPort=6152` 强制走 Surge |

### P1 — 重要补充

| # | 项目 | 修正内容 |
|:-:|------|---------|
| L1 | hosts 刷新命令 | 添加 `dscacheutil -flushcache && killall -HUP mDNSResponder` |
| E1 | 新增环境变量 | 添加 `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1` |
| S3 | 更新域名说明 | 说明 `storage.googleapis.com` 和 `downloads.claude.ai` 走直连的安全性 |
| D1 | CN 配置标注 | 标注 CN 相关内容为"仅适用于有 CN 配置的场景" |

### P2 — 建议优化

| # | 项目 | 修正内容 |
|:-:|------|---------|
| S2 | Claude-Reach URL | 保留两种方案，说明各自利弊 |
| S5 | 第三方规则标注 | 标注"完整版 vs 精简版" |
| S6 | [Host] 段补全 | 建议补充 anthropic.ai 等品牌域名 |
| E2 | 新增环境变量 | 添加 `DISABLE_UPGRADE_COMMAND=1` |

---

## 八、深度调研发现

### 8.1 GitHub Issues 调研

#### 🔴 #39862 — NO_PROXY 完全被忽略（v2.1.83 回归）

**可信度：高** | 来源：github.com/anthropics/claude-code/issues/39862

- Claude Code v2.1.83 **完全忽略 `NO_PROXY` 环境变量**
- 设置代理变量后，即使 `NO_PROXY="*"` 也不生效
- **回归 Bug**：原在 v2.1.38 修复（#22004），v2.1.83 重新出现
- **Workaround**：启动时临时清空代理变量 `HTTP_PROXY="" HTTPS_PROXY="" claude -p "hello"`
- **影响评估**：我们的场景中 Claude 流量本就需要走代理，NO_PROXY 用于排除本地地址。如果本地无需走代理的服务（如本地 API），此 Bug 会导致它们也被代理

#### 🟡 #33642 — OAuth 不走 CONNECT 隧道（仍未修复）

**可信度：高** | 来源：github.com/anthropics/claude-code/issues/33642

- OAuth 刷新请求使用明文 HTTP GET 而非 CONNECT 隧道
- 推理 API 正确使用 CONNECT ✅，但 OAuth 端点不走隧道 ❌
- Token 过期后连续 224 次 OAuth 刷新失败
- **可能原因**：初始化顺序竞争 / 拦截器被移除 / 推理 API 和 OAuth 使用不同 axios 实例
- **Workaround**：将 `api.anthropic.com` 加入 `NO_PROXY`（但与上面的 Bug 冲突）
- **影响评估**：在 Surge TUN 模式下，所有流量已通过 Surge 代理，此问题影响较小

#### 🟢 v2.1.80 — TLS 指纹修复

**可信度：高** | 来源：CHANGELOG.md

- 修复了语音模式 WebSocket 被 Cloudflare Bot 检测拦截的问题
- 原因：Claude Code 的 TLS 指纹不匹配浏览器指纹
- **启示**：Cloudflare 的 DPI 和 Bot 检测可能影响代理连接，Surge 的 TLS 指纹应与浏览器一致

#### 🟡 #44395 — SNI-based DPI 阻断插件流量

**可信度：中** | 来源：github.com/anthropics/claude-code/issues/44395

- 机构网络通过 SNI（Server Name Indication）深度包检测阻断 Telegram Bot 流量
- 静默失败，无明确错误信息
- **启示**：如果 ISP 部署 SNI 嗅探，Surge 的 `skip-cert-verify=false` 和 TLS 配置很重要

#### ℹ️ v2.1.84 — 新增 `CLAUDE_STREAM_IDLE_TIMEOUT_MS`

**可信度：高** | 来源：CHANGELOG.md

- 可配置流式传输空闲超时（默认 90 秒）
- 替代指南中推荐的 `CLAUDE_ENABLE_STREAM_WATCHDOG=1`（watchdog 仍是开关，此变量允许自定义超时值）
- **建议**：指南可补充此变量作为高级选项

### 8.2 社区调研

#### Surge 规则配置

- GitHub 上未找到专门的 Surge + Claude 规则仓库
- Surge 社区论坛（nssurge.com）返回 403，无法直接访问
- **结论**：当前 OVERSEA 配置的 DOMAIN-SUFFIX + KEYWORD 兜底方案是实用且有效的，无需参考第三方模板

#### `encrypted-dns-follow-outbound-mode` 循环依赖

- Surge 官方手册（manual.nssurge.com）部分页面返回 404
- **结论**：基于 OVERSEA 配置注释和技术分析，不启用此选项的决策正确。`[Host]` 段的 DoH 指定已足够保护 DNS 查询

#### macOS 防火墙工具

- Little Snitch 和 LuLu 在 Claude Code 社区无专门讨论
- 1Hosts 等域名屏蔽列表可能误杀 Claude 域名（需注意白名单）
- **建议**：使用 LuLu 时确保 Claude 相关进程（Node.js）已允许出站

### 8.3 新发现 — 可操作建议

| # | 发现 | 可信度 | 建议 |
|:-:|------|:------:|------|
| R1 | `CLAUDE_STREAM_IDLE_TIMEOUT_MS` 可自定义超时 | 高 | 补充到环境变量清单作为高级选项 |
| R2 | NO_PROXY Bug 仍存在（v2.1.83+） | 高 | 更新已知 Bug 表，注明回归版本 |
| R3 | OAuth 不走 CONNECT 隧道 | 高 | 在 Surge TUN 模式下影响小，但记录在案 |
| R4 | Cloudflare TLS 指纹检测 | 高 | 确保 Surge VMess 节点的 TLS 配置正确 |
| R5 | SNI 嗅探风险 | 中 | OVERSEA 环境无 GFW，风险较低 |
| R6 | 1Hosts 等屏蔽列表可能误杀 | 中 | 如使用第三方 DNS 屏蔽，需白名单 Claude 域名 |
| R7 | `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` 凭据清洗 | 高 | v2.1.83 新增，剥离子进程中的 API 密钥和云服务凭据，强烈建议启用 |
| R8 | Claude Code 内置沙盒网络隔离 | 高 | 可配置 `sandbox.network.httpProxyPort=6152` 强制沙盒流量走 Surge |
| R9 | `encrypted-dns-follow-outbound-mode` 可安全使用 | 高 | 条件：DoH 用 IP 地址（如 `https://1.1.1.1/dns-query`）而非域名，避免循环 |
| R10 | Issue #43954 CONNECT 挂起已修复 | 高 | v2.1.93 修复，确保更新到此版本以上 |
| R11 | `X-Claude-Code-Session-Id` 请求头 | 中 | v2.1.86 新增，可用于 Surge 识别 Claude Code 流量 |

---

## 来源

| 来源 | URL / 路径 |
|------|-----------|
| 官方网络配置 | code.claude.com/docs/en/network-config |
| 官方环境变量 | code.claude.com/docs/en/env-vars |
| OVERSEA 配置 | OVERSEA-CA-CLAUDE.conf（本项目） |
| Claude 防护指南 | Claude_Protection_Guide.md v1.0（本项目） |
| GitHub Issues | github.com/anthropics/claude-code/issues |
