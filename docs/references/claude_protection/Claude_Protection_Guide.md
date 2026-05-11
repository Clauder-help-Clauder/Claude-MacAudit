# Claude 综合防护指南

> 版本：1.1 | 日期：2026-04-07 | 审计修订
> 适用：三台 Mac 工作站统一部署
> - Tahoe 26.4（M4 Max 64GB）
> - Ventura 13.7.8（Intel i9）
> - Sequoia 15.7.5（M4 Max 64GB）

---

## 防护架构总览

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Claude 综合防护架构（六层纵深）                      │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  L1  Surge 规则层（主力防护）                                         │
│  ├── DOMAIN-SUFFIX 精确匹配全域名                                     │
│  ├── DOMAIN-KEYWORD 兜底捕获未知新域名                                │
│  ├── WebRTC STUN REJECT（防 WebRTC 泄露真实 IP）                     │
│  ├── Host 段 DoH 保护 Claude 域名 DNS 解析                          │
│  └── 增强模式 TUN 全局接管（L3 网络层拦截）                           │
│                                                                      │
│  L2  DNS 防泄漏层                                                    │
│  ├── Surge Fake IP（198.18.0.2）接管系统 DNS                         │
│  ├── 加密 DNS（DoH）防 ISP 窥探                                     │
│  └── 移除明文 DNS（防竞速泄漏）                                      │
│                                                                      │
│  L3  本地防护层                                                       │
│  ├── hosts 22 条域名屏蔽（Surge 关闭时最后防线）                      │
│  ├── Claude Code 环境变量（禁用遥测/错误报告/自动更新）               │
│  ├── 代理开关函数（proxy_on/proxy_off）                              │
│  └── macOS 防火墙 + 隐身模式                                        │
│                                                                      │
│  L4  协议防泄漏层                                                    │
│  ├── IPv6 禁用（Surge ipv6=false）                                   │
│  ├── WebRTC STUN 全局 REJECT                                        │
│  ├── mDNS 多播广告禁用                                               │
│  └── Captive Portal 检测禁用                                         │
│                                                                      │
│  L5  行为防追踪层                                                    │
│  ├── IP 出口一致性（仅 VMess，不用 Hysteria2 做 Claude 出口）        │
│  ├── 遥测全禁用（Statsig + Sentry + Apple Analytics）                │
│  ├── 子进程凭据清洗（SUBPROCESS_ENV_SCRUB）                          │
│  └── LuLu 出站防火墙（监控异常出站）                                 │
│                                                                      │
│  L6  沙盒隔离层（新增，推荐）                                        │
│  ├── Claude Code 内置 Sandbox 网络白名单                             │
│  ├── httpProxyPort=6152 强制沙盒流量走 Surge                         │
│  └── allowManagedDomainsOnly 防止项目级越权                          │
│                                                                      │
│  [可选] pf Kill Switch                                               │
│  └── Surge 进程消失时阻断所有非本地出站                               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 一、本地防护

### 1.1 hosts 域名屏蔽（Surge 关闭时的最后防线）

Surge 配置 `FINAL,DIRECT`（代理有流量限制），Surge 关闭后所有流量直连。
hosts 将 Claude/Anthropic 全域名指向 `0.0.0.0`，阻断直连泄露。

```
# /etc/hosts — Claude / Anthropic 域名屏蔽（22 条）
0.0.0.0 anthropic.com
0.0.0.0 www.anthropic.com
0.0.0.0 api.anthropic.com
0.0.0.0 cdn.anthropic.com
0.0.0.0 console.anthropic.com
0.0.0.0 docs.anthropic.com
0.0.0.0 status.anthropic.com
0.0.0.0 claude.ai
0.0.0.0 www.claude.ai
0.0.0.0 claude.com
0.0.0.0 www.claude.com
0.0.0.0 claude.dev
0.0.0.0 www.claude.dev
0.0.0.0 code.claude.com
0.0.0.0 platform.claude.com
0.0.0.0 a-api.anthropic.com
0.0.0.0 api.console.anthropic.com
0.0.0.0 a-cdn.anthropic.com
0.0.0.0 s-cdn.anthropic.com
0.0.0.0 claudeusercontent.com
0.0.0.0 statsig.anthropic.com
0.0.0.0 auth.anthropic.com
```

**可选补充**（来自研究报告新发现的域名）：
```
0.0.0.0 downloads.claude.ai
0.0.0.0 code.claude.com
```

**修改 hosts 后必须刷新 DNS 缓存**：
```bash
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

**验证**：
```bash
# Surge 关闭后
ping -c 1 api.anthropic.com
# 预期：cannot resolve — 被 hosts 阻断

# Surge 开启后
ping -c 1 api.anthropic.com
# 预期：198.18.x.x — Surge Fake IP 接管
```

### 1.2 macOS 防火墙 + 隐身模式

```bash
# 开启防火墙
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
# 开启隐身模式（不响应 ping 和端口扫描）
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
# 已签名应用自动允许
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
```

### 1.3 LuLu 出站防火墙（推荐）

macOS 内置防火墙只管入站，LuLu 补全出站监控：

```bash
brew install --cask lulu
```

任何应用尝试出站连接时 LuLu 弹窗询问，可精确控制 Claude 相关进程的网络行为。

### 1.4 pf Kill Switch（可选加固）

> ⚠️ 配置复杂，配错会完全断网，需谨慎测试。

当 Surge 崩溃或退出时，pf 规则阻断所有非本地出站，防止 Claude 流量裸连。

---

## 二、地址防泄漏

### 2.1 DNS 防泄漏

**威胁**：明文 DNS 查询让 ISP 看到你在解析 `api.anthropic.com`，即使数据本身走代理加密。

**三层 DNS 防护**：

| 层级 | 措施 | 状态 |
|------|------|:----:|
| Surge Fake IP | 198.18.0.2 接管系统 DNS，域名不做真实解析 | ✅ |
| 加密 DNS（DoH） | `[Host]` 段为 Claude 域名指定 DoH 解析 | ✅ |
| 移除明文 DNS | CN 配置移除 `119.29.29.29, 223.5.5.5`，仅保留 `system` | ⚠️ 仅 CN 配置 |

**CN 配置修改**（仅适用于有 CN 配置的场景，OVERSEA 配置已是 `dns-server = system`）：
```ini
# [General] 段
# 找到：
dns-server = 119.29.29.29, 223.5.5.5, system
# 替换为：
dns-server = system
```

**⚠️ `encrypted-dns-follow-outbound-mode` — 视配置而定**：

```ini
# 当前 OVERSEA 配置使用域名形式 DoH → 不要启用（循环依赖）
# encrypted-dns-server = https://dns.google/dns-query  ← 域名形式
# encrypted-dns-follow-outbound-mode = true  ← 会循环：DoH→代理→DNS→DoH

# 如果改用 IP 形式 DoH → 可以安全启用
# encrypted-dns-server = https://8.8.8.8/dns-query, https://1.1.1.1/dns-query
# encrypted-dns-follow-outbound-mode = true  ← 安全：DoH 直接连 IP，无需 DNS
# 同时需要在 [Rule] 中添加：
# IP-CIDR,8.8.8.8/32,DIRECT
# IP-CIDR,1.1.1.1/32,DIRECT
```

**原因**：循环依赖仅在 DoH 用域名（如 `dns.google`）时发生——Surge 需要先 DNS 解析域名才能建立 DoH 连接。改用 IP 地址直连即可避免。当前 OVERSEA 配置使用 `https://dns.google/dns-query`（域名形式），因此**不应启用**。

**验证**：
```bash
# 在 Surge Dashboard → DNS 页面检查
# 确认 DoH 解析正常工作，没有循环依赖错误
```

### 2.2 Surge 增强模式（TUN）— 全局 DNS 接管

增强模式在网络层（L3）拦截**所有**流量，包括不走系统代理的应用（如部分 Electron 应用）。

**验证**：
```bash
# 检查 utun 接口存在
ifconfig | grep utun

# 检查默认路由指向 utun
netstat -rn | grep default | head -3

# 检查 Fake IP 接管
scutil --dns | grep '198.18.0.2'
```

### 2.3 Surge 域名白名单（必须走代理的域名）

| 域名 | 用途 | 必须走代理 |
|------|------|:---------:|
| `api.anthropic.com` | Claude API + OAuth | ✅ |
| `claude.ai` | 账户认证 | ✅ |
| `platform.claude.com` | Console 认证（新增） | ✅ |
| `storage.googleapis.com` | 二进制下载/更新 | 安装时 |
| `downloads.claude.ai` | 安装脚本/版本指针 | 安装时 |

**Surge 规则（完整 [Rule] 段）**：

```ini
# Claude/Anthropic 官方
DOMAIN-SUFFIX,anthropic.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claude.ai,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claude.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claude.dev,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,anthropic.ai,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,anthropic-ai.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claudeai.com,Claude-CA-ATT-VMESS
# CDN / 用户内容
DOMAIN,cdn.usefathom.com,Claude-CA-ATT-VMESS
DOMAIN,servd-anthropic-website.b-cdn.net,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claudeusercontent.com,Claude-CA-ATT-VMESS
# 第三方服务
DOMAIN-SUFFIX,intercom.io,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,intercomcdn.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,datadoghq.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,sentry.io,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,launchdarkly.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,statsig.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,statsigapi.net,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,stripe.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,stripe.network,Claude-CA-ATT-VMESS
# 更新域名
DOMAIN-SUFFIX,downloads.claude.ai,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,code.claude.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,storage.googleapis.com,Claude-CA-ATT-VMESS
# 关键词兜底（捕获未来新域名）
DOMAIN-KEYWORD,anthropic,Claude-CA-ATT-VMESS
DOMAIN-KEYWORD,claude,Claude-CA-ATT-VMESS
```

---

## 三、数据出口防追踪

### 3.1 IP 出口一致性

**核心原则**：固定代理出口 IP，避免频繁切换触发 Anthropic 安全审查。

| 策略 | 说明 |
|------|------|
| 仅 VMess 用于 Claude | Hysteria2 不入 Claude 组（IP 出口不一致） |
| 固定节点 | `Claude-Reach` 自动测速组保持最优节点，不频繁跳转 |
| 单一国家出口 | 避免短时间从多个国家 IP 访问 |

**Surge Proxy Group 配置**：
```ini
Claude-Fast = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, url=http://cp.cloudflare.com/generate_204, interval=300, tolerance=50, timeout=3
Claude-Reach = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=100, timeout=8
```

### 3.2 遥测全禁用

Claude Code 和 macOS 均有遥测，需要全面禁用：

**Claude Code 遥测**（加到 `~/.zshrc`）：

```bash
# === Claude Code 网络优化 ===
# 一键禁用：自动更新 + 反馈命令 + 错误报告 + 遥测
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# 允许代理执行 DNS 解析（配合 Surge Fake IP）
export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1

# 流空闲超时保护（代理环境推荐）
export CLAUDE_ENABLE_STREAM_WATCHDOG=1
```

上述一行 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 等效于同时设置：
- `DISABLE_TELEMETRY=1`（Statsig 遥测）
- `DISABLE_ERROR_REPORTING=1`（Sentry 错误报告）
- `DISABLE_AUTOUPDATER=1`（自动更新）
- `DISABLE_FEEDBACK_COMMAND=1`（隐藏 /feedback）

> **已知问题**（Issue #10494）：设置 `DISABLE_TELEMETRY=1` 后，Claude Code 仍每 10-30 秒向 Google 基础设施（`142.250.0.0/15`）发起连接，约 300-400 次/小时。防火墙屏蔽后功能正常。Anthropic 标记为"Not Planned"关闭。

**macOS 遥测**：

```bash
# 禁止诊断数据提交
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false
# 禁止崩溃报告弹窗
defaults write com.apple.CrashReporter DialogType -string "none"
# 关闭 Siri 数据共享
defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 0
# 关闭个性化广告
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false
# 关闭 iCloud 使用追踪
defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false
defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false
```

### 3.3 测试 URL 选择

`Claude-Reach` 组的可达性检测 URL 有两种方案：

| 方案 | URL | 优点 | 缺点 |
|------|-----|------|------|
| A（当前） | `http://docs.anthropic.com` | 验证 Anthropic 真实可达（301 响应，轻量） | ISP 可见目标域名（但请求走代理） |
| B（可选） | `http://cp.cloudflare.com/generate_204` | 更隐蔽，不暴露 Anthropic 意图 | 只测线路通畅，不测目标可达 |

> **当前 OVERSEA 配置采用方案 A**，因为请求走代理隧道，ISP 无法窥探。如果需要更高隐蔽性，可改用方案 B：
> ```ini
> # Claude-Reach 组改为：
> url=http://cp.cloudflare.com/generate_204
> ```

### 3.4 代理开关函数

```bash
# ~/.zshrc
proxy_on() {
  export http_proxy="http://127.0.0.1:6152"
  export https_proxy="http://127.0.0.1:6152"
  export all_proxy="socks5://127.0.0.1:6153"
  export HTTP_PROXY="http://127.0.0.1:6152"
  export HTTPS_PROXY="http://127.0.0.1:6152"
  export ALL_PROXY="socks5://127.0.0.1:6153"
  export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  echo "代理已开启"
}

proxy_off() {
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY
  echo "代理已关闭"
}

# 默认开启（Surge 常驻运行）
proxy_on > /dev/null 2>&1
```

---

## 四、WebRTC 防泄露

### 4.1 威胁说明

WebRTC 协议通过 STUN 服务器获取公网 IP，即使使用代理也可能绕过代理直接暴露真实 IP。这是最常见的 VPN/代理 IP 泄露途径。

### 4.2 Surge 层防护（已配置）

Surge 规则中已配置 WebRTC STUN 全局 REJECT：

```ini
# 阻止 WebRTC 泄漏 — 除 Claude 官方域名外的所有 STUN 请求
AND,((PROTOCOL,STUN), (NOT,((OR,((DOMAIN-SUFFIX,anthropic.com), (DOMAIN-SUFFIX,claude.ai), (DOMAIN-SUFFIX,claude.com)))))),REJECT
```

**作用**：
- 所有 STUN 协议请求被 Surge 拦截并丢弃
- Claude 官方域名的 STUN 请求放行（理论上 Claude 不使用 STUN，此为白名单保底）
- WebRTC 无法通过 STUN 获取真实公网 IP

### 4.3 浏览器层防护（补充）

Surge 规则已覆盖系统级 WebRTC 防护，但浏览器可作为额外防线：

**Chrome**：
1. 安装扩展 [WebRTC Leak Prevent] 或 [uBlock Origin]
2. uBlock Origin：设置 → 隐私 → 勾选"阻止 WebRTC 泄露本地 IP"

**Safari**：
- Safari 默认不暴露本地 IP，且 WebRTC 受限，无需额外配置

**Firefox**：
- 地址栏输入 `about:config`
- 设置 `media.peerconnection.enabled` 为 `false`（完全禁用 WebRTC）

### 4.4 验证 WebRTC 是否泄露

在 Surge 开启状态下访问：

- `https://browserleaks.com/webrtc`
- `https://ipleak.net/`

**预期结果**：
- Public IP 应显示代理出口 IP（不是真实 IP）
- Local IP 应为空或显示 `N/A`

---

## 五、IPv6 防泄漏

### 5.1 威胁说明

IPv6 流量可能绕过 IPv4 代理隧道直接出站，暴露真实 IPv6 地址。许多 ISP 已分配 IPv6，而代理节点可能不支持 IPv6 隧道。

### 5.2 Surge 层（已配置）

```ini
# [General] 段
ipv6 = false
```

Surge 增强模式下 IPv6 被完全禁用，所有流量强制走 IPv4 隧道。

### 5.3 系统层加固

Surge 关闭时 IPv6 仍然活跃，需要系统级禁用作为后备：

```bash
# 查看当前 IPv6 状态
networksetup -listallnetworkservices
networksetup -getinfo "Wi-Fi"

# 禁用 Wi-Fi 接口的 IPv6
sudo networksetup -setv6off "Wi-Fi"

# 如果有以太网
sudo networksetup -setv6off "Ethernet"
# 或
sudo networksetup -setv6off "Thunderbolt Bridge"
```

**还原**（需要 IPv6 时）：
```bash
sudo networksetup -setv6automatic "Wi-Fi"
```

### 5.4 内核级 IPv6 禁用（最彻底）

```bash
# 临时生效
sudo sysctl -w net.inet6.ip6.accept_rtadv=0
sudo sysctl -w net.inet6.ip6.forwarding=0
```

> 将以下两行追加到现有的 `/Library/LaunchDaemons/com.server.sysctl.plist` 脚本中永久化：
> ```
> sysctl -w net.inet6.ip6.accept_rtadv=0
> sysctl -w net.inet6.ip6.forwarding=0
> ```

### 5.5 验证 IPv6 已禁用

```bash
# 检查接口是否有全局 IPv6 地址
ifconfig | grep inet6
# 预期：仅有 ::1（本地回环）和 fe80::（链路本地），无全局 IPv6

# 在线验证
curl -6 https://ipv6.icanhazip.com/ 2>/dev/null
# 预期：连接失败（无 IPv6 出口）
```

---

## 六、Claude Code 专用环境变量（完整清单）

统一加到 `~/.zshrc`：

```bash
# ============================================
# Claude Code 防护环境变量（三台机器统一部署）
# ============================================

# --- 禁用非必要流量（等效于同时设置 DISABLE_TELEMETRY + DISABLE_ERROR_REPORTING + DISABLE_AUTOUPDATER + DISABLE_FEEDBACK_COMMAND）---
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# --- 禁用会话质量调查弹窗 ---
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1

# --- 隐藏 /upgrade 命令（配合上面的自动更新禁用）---
export DISABLE_UPGRADE_COMMAND=1

# --- 代理 DNS 解析 ---
export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1

# --- 流保护 ---
export CLAUDE_ENABLE_STREAM_WATCHDOG=1

# --- 子进程凭据清洗（v2.1.83+，强烈推荐）---
# 剥离 Bash 工具、Hooks、MCP 服务器中的 API 密钥和云服务凭据
export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
```

**完整环境变量参考**：

| 变量 | 值 | 用途 |
|------|:--:|------|
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | 一键禁用遥测+错误报告+自动更新+反馈（官方确认） |
| `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY` | `1` | 禁用 "How is Claude doing?" 会话质量调查 |
| `DISABLE_UPGRADE_COMMAND` | `1` | 隐藏 /upgrade 命令 |
| `CLAUDE_CODE_PROXY_RESOLVES_HOSTS` | `1` | 代理执行 DNS 解析（配合 Surge Fake IP） |
| `CLAUDE_ENABLE_STREAM_WATCHDOG` | `1` | 90 秒后中止失速的流（代理环境专用） |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | `90000` | 自定义流空闲超时毫秒数（v2.1.84+，默认 90000，高级选项） |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` | `1` | 剥离子进程中的 API 密钥和云凭据（v2.1.83+，强烈推荐） |
| `HTTPS_PROXY` | `http://127.0.0.1:6152` | Surge HTTP 代理（proxy_on 函数设置） |
| `NO_PROXY` | `localhost,127.0.0.1,...` | 绕过代理的本地地址 |

**不建议设置的变量**：

| 变量 | 原因 |
|------|------|
| `ANTHROPIC_API_KEY` | 明文密钥不应放在 shell 配置中，用 OAuth 登录 |
| `ALL_PROXY=socks5://...` | Claude Code 官方明确不支持 SOCKS 代理 |
| `NODE_EXTRA_CA_CERTS` | 除非 Surge 开启 MITM（建议对 api.anthropic.com 关闭 MITM） |

---

## 七、已知 Bug 与 Workaround

| Bug | 说明 | Workaround |
|-----|------|-----------|
| NO_PROXY 被忽略 (#39862) | v2.1.83 回归 bug，`NO_PROXY="*"` 也无效 | 临时清空代理变量：`HTTP_PROXY="" claude -p "hello"` |
| OAuth 不走 CONNECT (#33642) | OAuth 刷新走明文 GET，224 次连续失败 | 将 `api.anthropic.com` 加入 `NO_PROXY`（与上条冲突，Surge TUN 模式下影响小） |
| CONNECT 隧道挂起 (#43954) | 代理环境下每次 API 调用间挂起 290 秒 | **已在 v2.1.93 修复**，确保更新到此版本以上 |
| SOCKS 不支持但仍尝试 | 导致 502 错误 | 不要设置 `ALL_PROXY=socks5://...` |
| 遥测禁用不彻底 (#10494) | 仍向 Google 发起连接 300-400 次/小时 | 防火墙屏蔽 `142.250.0.0/15`，功能不受影响 |
| Cloudflare TLS 指纹 (v2.1.80 已修复) | 语音模式 WebSocket 被 Cloudflare Bot 检测拦截 | 升级到 v2.1.80+，确保 Surge TLS 配置正确 |
| SNI-based DPI (#44395) | 机构网络 SNI 嗅探静默阻断插件流量 | OVERSEA 环境无 GFW 影响小，确保 VMess+TLS 配置正确 |

> **注意**：#39862 和 #33642 存在 Workaround 冲突 — 一个需要清空代理变量，另一个需要把域名加入 NO_PROXY。在 Surge TUN 全局接管模式下，两者影响均较小，因为所有流量已通过 Surge 代理隧道处理。

---

## 八、Surge MITM 注意事项

如果 Surge 开启 TLS 解密（MITM），Claude Code 的 Node.js 运行时会拒绝 Surge 的 CA 证书。

**方案 A（推荐）：对 Claude 域名关闭 MITM**

Surge MITM 排除列表加入：`api.anthropic.com`、`claude.ai`、`platform.claude.com`

**方案 B：导入 Surge CA 证书**

```bash
export NODE_EXTRA_CA_CERTS=/path/to/surge-ca.pem
```

---

## 八·五、Claude Code 沙盒网络隔离（深度调研新发现）

Claude Code v2.x 内置了基于 macOS Sandbox 的网络隔离机制，**默认未启用**。配合 Surge 可实现双层网络控制。

**在 `~/.claude/settings.json` 中配置**：

```json
{
  "sandbox": {
    "enabled": true,
    "network": {
      "httpProxyPort": 6152,
      "allowedDomains": ["api.anthropic.com", "claude.ai", "platform.claude.com"],
      "allowManagedDomainsOnly": true
    }
  }
}
```

| 参数 | 说明 | 安全价值 |
|------|------|---------|
| `network.httpProxyPort` | 沙盒流量走指定 HTTP 代理（设为 Surge 端口 6152） | 强制沙盒流量经 Surge 代理 |
| `network.allowedDomains` | 白名单域名（支持通配符） | 限制 Claude 工具能访问的域名 |
| `network.allowManagedDomainsOnly` | 仅允许托管设置中的域 | 防止项目级设置扩展访问权限 |

> **注意**：若不指定 `httpProxyPort`，Claude Code 会自行启动一个本地代理进程。建议明确指定为 Surge 端口以统一流量管控。

> 方案 A 更安全，避免对 Claude API 流量做中间人解密。

---

## 九、防护验证脚本

```bash
#!/bin/bash
# === Claude 综合防护验证 ===

echo "═══════════════════════════════════════"
echo "       Claude 综合防护状态检查"
echo "═══════════════════════════════════════"

echo ""
echo "=== 1. 本地防护 ==="
echo -n "  防火墙: "
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled" && echo "✅ 已开启" || echo "❌ 未开启"
echo -n "  隐身模式: "
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -q "on" && echo "✅ 已开启" || echo "❌ 未开启"
HOSTS_COUNT=$(grep -c '0.0.0.0.*\(anthropic\|claude\)' /etc/hosts 2>/dev/null)
echo "  hosts Claude 屏蔽: ${HOSTS_COUNT} 条"
[ "$HOSTS_COUNT" -lt 20 ] && echo "  ⚠️ 警告：不足 20 条，Surge 关闭时可能泄露！"
echo "  💡 修改 hosts 后记得执行: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"

echo ""
echo "=== 2. DNS 防泄漏 ==="
echo -n "  Surge Fake IP: "
scutil --dns 2>/dev/null | grep -q '198.18.0.2' && echo "✅ 已接管" || echo "❌ 未接管"
echo -n "  HTTPS_PROXY: "
echo "${HTTPS_PROXY:-❌ 未设置}"

echo ""
echo "=== 3. 遥测禁用 ==="
echo -n "  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "
echo "${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-❌ 未设置}"
echo -n "  CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY: "
echo "${CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY:-❌ 未设置}"
echo -n "  DISABLE_UPGRADE_COMMAND: "
echo "${DISABLE_UPGRADE_COMMAND:-❌ 未设置}"
echo -n "  CLAUDE_CODE_PROXY_RESOLVES_HOSTS: "
echo "${CLAUDE_CODE_PROXY_RESOLVES_HOSTS:-❌ 未设置}"
echo -n "  CLAUDE_ENABLE_STREAM_WATCHDOG: "
echo "${CLAUDE_ENABLE_STREAM_WATCHDOG:-❌ 未设置}"
echo -n "  Apple 诊断提交: "
[ "$(defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null)" = "0" ] && echo "✅ 已禁用" || echo "⚠️ 未禁用"
echo -n "  Apple 广告: "
[ "$(defaults read com.apple.AdLib allowApplePersonalizedAdvertising 2>/dev/null)" = "0" ] && echo "✅ 已禁用" || echo "⚠️ 未禁用"

echo ""
echo "=== 4. WebRTC 防泄露 ==="
echo "  Surge STUN REJECT: 需在 Surge Dashboard → 规则中确认"
echo "  在线验证: https://browserleaks.com/webrtc"

echo ""
echo "=== 5. IPv6 防泄漏 ==="
IPV6_GLOBAL=$(ifconfig 2>/dev/null | grep 'inet6' | grep -v 'fe80\|::1' | wc -l | tr -d ' ')
echo -n "  全局 IPv6 地址: "
[ "$IPV6_GLOBAL" -eq 0 ] && echo "✅ 无（已禁用）" || echo "⚠️ 有 ${IPV6_GLOBAL} 个（可能泄露）"
echo -n "  Wi-Fi IPv6: "
networksetup -getinfo "Wi-Fi" 2>/dev/null | grep -q "IPv6: Off" && echo "✅ 已关闭" || echo "⚠️ 未关闭"

echo ""
echo "=== 6. 网络服务收敛 ==="
echo -n "  mDNS 多播广告: "
[ "$(defaults read /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements 2>/dev/null)" = "1" ] && echo "✅ 已禁用" || echo "⚠️ 未禁用"
echo -n "  Captive Portal: "
[ "$(defaults read /Library/Preferences/SystemConfiguration/CaptiveNetworkSupport Active 2>/dev/null)" = "0" ] && echo "✅ 已禁用" || echo "⚠️ 未禁用"

echo ""
echo "=== 7. 代理函数 ==="
echo -n "  proxy_on/proxy_off: "
grep -q 'proxy_on' ~/.zshrc 2>/dev/null && echo "✅ 已配置" || echo "❌ 未配置"

echo ""
echo "═══════════════════════════════════════"
echo "  验证完成"
echo "═══════════════════════════════════════"
```

---

## 九·五、三系统部署差异

> 部署前先确认网络服务名称：`networksetup -listallnetworkservices`

| 差异项 | Tahoe 26.4（M4 Max） | Sequoia 15.7.5（M4 Max） | Ventura 13.7.8（Intel i9） |
|--------|:--------------------:|:-----------------------:|:--------------------------:|
| Homebrew 路径 | `/opt/homebrew/bin` | `/opt/homebrew/bin` | `/usr/local/bin` |
| Thunderbolt Bridge | 可能无 | 可能无 | ✅ 有，需额外 IPv6 禁用 |
| LuLu 兼容 | ⚠️ 需确认新版 | ✅ | ✅ |
| Siri defaults 路径 | ⚠️ Liquid Glass 可能变更 | ✅ | ✅ |
| Intel 支持 | 最后一版支持 Intel | ❌ | ✅ 原生 |

---

## 十、执行清单（按优先级）

### P0 — 必须立即执行

| # | 项目 | 操作 |
|:-:|------|------|
| 1 | hosts 域名屏蔽 | 确认 22+ 条规则在三台机器上生效 |
| 2 | Surge 增强模式 | 确认 TUN 全局接管已开启 |
| 3 | 代理开关函数 | `~/.zshrc` 中 `proxy_on`/`proxy_off` 已配置 |
| 4 | Claude Code 环境变量 | `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 等五项（含 FEEDBACK_SURVEY 和 UPGRADE） |
| 5 | IPv6 系统级禁用 | `networksetup -setv6off "Wi-Fi"` |

### P1 — 重要，尽快执行

| # | 项目 | 操作 |
|:-:|------|------|
| 6 | CN 移除明文 DNS | `dns-server = system`（仅 CN 配置需要，OVERSEA 已完成） |
| 7 | ~~DoH 跟随出站~~ | ~~`encrypted-dns-follow-outbound-mode = true`~~ **已移除：会造成循环依赖** |
| 8 | 测试 URL 评估 | `Claude-Reach` 当前用 `docs.anthropic.com`（走代理安全），可选改为 `cp.cloudflare.com` |
| 9 | 防火墙 + 隐身模式 | 三台机器均需开启 |
| 10 | mDNS / Captive Portal | 禁用多播广告和检测 |

### P2 — 推荐

| # | 项目 | 操作 |
|:-:|------|------|
| 11 | LuLu 出站防火墙 | `brew install --cask lulu` |
| 12 | 浏览器 WebRTC 防护 | 安装 uBlock Origin 或 WebRTC Leak Prevent |
| 13 | Apple 遥测全关 | Analytics / Siri / 广告 / iCloud 追踪 |
| 14 | IPv6 内核级禁用 | sysctl LaunchDaemon 永久化 |

### P3 — 可选

| # | 项目 | 操作 |
|:-:|------|------|
| 15 | pf Kill Switch | Surge 退出时阻断非本地出站 |
| 16 | 遥测残留屏蔽 | LuLu 或 pf 屏蔽 `142.250.0.0/15`（Google 遥测残留） |

---

## 来源

| 来源 | 内容 |
|------|------|
| Claude_Protection_Research.md | Claude 网络调研（本项目） |
| Mac_System_Optimization_Guide.md | 系统安全加固终版（本项目） |
| Surge_Optimization_Guide.md | Surge 配置优化（本项目） |
| Mac_Perf_Optimize_*.md | 三台机器效能优化含八-D Claude 防护（本项目） |
| Claude_Protection_Audit.md | 审计报告（本项目） |
| [code.claude.com/docs/en/network-config](https://code.claude.com/docs/en/network-config) | 官方网络配置文档 |
| [code.claude.com/docs/en/env-vars](https://code.claude.com/docs/en/env-vars) | 官方环境变量参考（150+ 变量） |
| [code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings) | 官方设置文档（沙盒配置来源） |
| [github.com/anthropics/claude-code/issues](https://github.com/anthropics/claude-code/issues) | 已知 Bug 跟踪 |
| [github.com/anthropics/claude-code/blob/main/CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) | 版本变更日志 |
