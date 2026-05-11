# MacAudit × Surge 配置检查清单

> 基于 MacAudit 12 个审计模块的全量检测规则生成。
> 适用于：另一个 CC 进程对 Surge 配置进行系统性核查。
> 生成日期：2026-04-14

---

## 目录

1. [Surge 核心功能验证](#1-surge-核心功能验证)
2. [WebRTC / STUN 泄露防护](#2-webrtc--stun-泄露防护)
3. [DNS 配置与泄露防护](#3-dns-配置与泄露防护)
4. [IPv6 泄露防护](#4-ipv6-泄露防护)
5. [Claude Code 专属配置](#5-claude-code-专属配置)
6. [环境变量 × 代理配置](#6-环境变量--代理配置)
7. [浏览器防泄露（Chrome / Safari）](#7-浏览器防泄露chrome--safari)
8. [身份 / 地理信号对齐](#8-身份--地理信号对齐)
9. [IP 质量评估（出口 IP 检测项）](#9-ip-质量评估出口-ip-检测项)
10. [防火墙 / 系统安全](#10-防火墙--系统安全)
11. [Surge 配置模板（汇总）](#11-surge-配置模板汇总)

---

## 1. Surge 核心功能验证

来源模块：`m3`（NetworkSecurityModule）、`m10`（ClaudeProtectionModule）

### 1.1 Fake IP DNS 激活
- **check id**: `m3.surge_dns` / `m10.surge_dns`
- **验证命令**: `scutil --dns | grep '198.18.0.2'`
- **期望结果**: 输出中存在 `198.18.0.2`（Surge Fake IP 范围）
- **含义**: Surge 增强模式接管系统 DNS，防止 DNS 请求绕过隧道

```bash
# 验证
scutil --dns | grep -c '198.18.0.2'
# 期望输出: ≥ 1
```

### 1.2 TUN 接口激活
- **check id**: `m10.surge_tun`
- **验证命令**: `ifconfig | grep -c 'utun'`
- **期望结果**: 有 `utun` 接口（≥ 1）
- **含义**: Surge TUN 模式接管系统级流量，确保 Claude Code 等非 HTTP 流量也走代理

```bash
# 验证
ifconfig | grep 'utun' | head -5
```

### 1.3 Dashboard 端口监听
- **check id**: `m3.surge_dashboard` / `m10.surge_dashboard`
- **验证命令**: `lsof -nP -iTCP:6170 -sTCP:LISTEN`
- **期望结果**: 有监听进程（Surge Dashboard 端口 6170）

```bash
lsof -nP -iTCP:6170 -sTCP:LISTEN
```

---

## 2. WebRTC / STUN 泄露防护

来源模块：`m10.surge_stun_reject`（ClaudeProtectionModule）、`m14.webrtc_ip`（ChromeModule）

### 2.1 Surge STUN 拦截规则（核心）
- **check id**: `m10.surge_stun_reject`
- **期望**: Surge `.conf` 文件中存在 STUN 拦截规则
- **验证命令**:
```bash
find ~/Library/Application\ Support/Surge -name '*.conf' \
  -exec grep -li 'PROTOCOL,STUN\|stun.*REJECT' {} \;
# 期望输出: 至少一个文件路径
```

**Surge 规则（必须添加到 [Rule] 段）**:
```ini
# 阻止 WebRTC STUN 绕过代理暴露真实 IP
# 仅允许 Anthropic/Claude 相关 STUN（若有），其余全部拒绝
AND,((PROTOCOL,STUN),(NOT,((OR,((DOMAIN-SUFFIX,anthropic.com),(DOMAIN-SUFFIX,claude.ai)))))),REJECT
```

> **原理**: WebRTC 的 STUN 协议可以在代理/VPN 激活时仍然获取本地真实 IP 地址，从而绕过所有代理设置暴露真实地理位置。这是最常见的 IP 泄露渠道之一。

### 2.2 Chrome WebRTC IP 处理策略
- **check id**: `m14.webrtc_ip`
- **期望值**: `disable_non_proxied_udp`
- **验证命令**:
```bash
defaults read /Library/Managed\ Preferences/com.google.Chrome WebRtcIPHandlingPolicy 2>/dev/null
# 期望输出: disable_non_proxied_udp
```
- **修复命令**:
```bash
sudo defaults write /Library/Managed\ Preferences/com.google.Chrome \
  WebRtcIPHandlingPolicy -string 'disable_non_proxied_udp'
```

---

## 3. DNS 配置与泄露防护

来源模块：`m3.dns`（NetworkSecurityModule）、`m14.doh` / `m14.builtin_dns`（ChromeModule）、`m13.dns_servers`（IPQualityModule）

### 3.1 系统 DNS 服务器
- **check id**: `m3.dns`
- **验证命令**: `scutil --dns | grep 'nameserver\[0\]' | head -3`
- **期望结果**: DNS 服务器应为 Surge Fake IP（`198.18.x.x`）或可信加密 DNS
- **风险**: 若 DNS 服务器为电信/联通/移动 DNS（如 `223.5.5.5`、`114.114.114.114`），则暴露真实地理位置

```bash
# 检查 DNS 服务器
scutil --dns | grep 'nameserver'

# Surge 增强模式激活时，期望看到:
# nameserver[0] : 198.18.0.2
```

### 3.2 Chrome 内置 DNS 客户端（绕过系统 DNS）
- **check id**: `m14.builtin_dns`
- **期望值**: `0`（禁用）
- **验证命令**:
```bash
defaults read /Library/Managed\ Preferences/com.google.Chrome BuiltInDnsClientEnabled 2>/dev/null
# 期望: 0
```
- **修复命令**:
```bash
sudo defaults write /Library/Managed\ Preferences/com.google.Chrome \
  BuiltInDnsClientEnabled -bool false
```

### 3.3 Chrome DoH（绕过 Surge DNS）
- **check id**: `m14.doh`
- **期望值**: `off`（禁用）
- **风险**: Chrome 默认会升级到 Google DoH（8.8.8.8），完全绕过 Surge 的 DNS 劫持
- **修复命令**:
```bash
sudo defaults write /Library/Managed\ Preferences/com.google.Chrome \
  DnsOverHttpsMode -string 'off'
```

### 3.4 反向 DNS 检测（出口 IP）
- **check id**: `m13.reverse_dns`
- **验证**: `dig +short -x <your_exit_ip>`
- **期望**: rDNS 解析结果应与所声称的 ISP/地区一致（如住宅 IP 应有 ISP 的 PTR 记录）

---

## 4. IPv6 泄露防护

来源模块：`m3.ipv6`、`m3.wifi_ipv6`（NetworkSecurityModule）、`m8.net_inet6_*`（NetworkSecurityModule）、`m10.ipv6_*`（ClaudeProtectionModule）

> **核心风险**: 代理通常只处理 IPv4 流量。如果系统启用 IPv6，Claude Code 的部分连接可能直接通过 IPv6 直连，完全绕过 Surge，暴露真实 IPv6 地址（携带地理位置信息）。

### 4.1 IPv6 全局状态
- **check id**: `m3.ipv6` / `m10.ipv6_global` — `networkRisk: true`
- **期望值**: `0`（无全局 IPv6 地址）
- **验证命令**:
```bash
ifconfig | grep 'inet6' | grep -v '::1\|fe80' | wc -l
# 期望: 0
```

### 4.2 Wi-Fi 接口 IPv6
- **check id**: `m3.wifi_ipv6` / `m10.wifi_ipv6` — `networkRisk: true`
- **期望值**: `Off`
- **验证命令**:
```bash
networksetup -getinfo Wi-Fi | grep 'IPv6'
# 期望: IPv6: Off
```
- **修复命令**:
```bash
# 获取 Wi-Fi 接口名（可能是 Wi-Fi 或具体接口名）
WIFI=$(networksetup -listallnetworkservices | grep -i 'wi-fi\|wifi' | head -1)
sudo networksetup -setv6off "$WIFI"
```

### 4.3 全部接口 IPv6 批量关闭
- **check id**: `m10.ipv6_all_interfaces` — `networkRisk: true`
- **修复命令**:
```bash
# 关闭所有网络接口的 IPv6
networksetup -listallnetworkservices | tail -n +2 | while IFS= read -r svc; do
  sudo networksetup -setv6off "$svc" 2>/dev/null || true
done
echo "All interfaces IPv6 disabled"
```

### 4.4 IPv6 路由通告（sysctl）
- **check id**: `m8.net_inet6_ip6_accept_rtadv` — `networkRisk: true`
- **期望值**: `0`
- **注意**: `net.inet6.ip6.accept_rtadv` 在 macOS 上为**只读 sysctl**，`sudo sysctl -w` 会报错 `is read only`
- **正确修复命令**: 关闭接口 IPv6（RA 自然停止）:
```bash
networksetup -listallnetworkservices | grep -v '^An' | while IFS= read -r svc; do
  sudo networksetup -setv6off "$svc" 2>/dev/null
done
```

### 4.5 IPv6 转发（sysctl）
- **check id**: `m8.net_inet6_ip6_forwarding` — `networkRisk: true`
- **期望值**: `0`
- **注意**: `net.inet6.ip6.forwarding` 同样为**只读 sysctl**，无法通过 `sysctl -w` 修改
- **正确修复命令**: 同 §4.4，关闭 IPv6 接口即可禁止转发

**Surge 侧补充配置**:
```ini
[General]
# 禁用 IPv6 出站（确保 Surge 不走 IPv6）
ipv6 = false
ipv6-vif = disabled
```

---

## 5. Claude Code 专属配置

来源模块：`m10`（ClaudeProtectionModule）

### 5.1 settings.json 代理端口
- **check id**: `m10.sandbox_proxy`
- **文件**: `~/.claude/settings.json`
- **期望**: `httpProxyPort` = Surge 代理端口（默认 6152）
- **验证命令**:
```bash
cat ~/.claude/settings.json 2>/dev/null | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('network',{}).get('httpProxyPort','NOT SET'))"
```
- **修复命令**:
```bash
SURGE_PORT=6152
jq --arg port "$SURGE_PORT" \
  '.network = (.network // {}) | .network.httpProxyPort = ($port | tonumber)' \
  ~/.claude/settings.json > /tmp/_cs.json && mv /tmp/_cs.json ~/.claude/settings.json
```

### 5.2 沙盒域名白名单
- **check id**: `m10.sandbox_domains`
- **期望**: `allowedDomains` 包含 `["api.anthropic.com","*.anthropic.com"]`
- **验证命令**:
```bash
cat ~/.claude/settings.json 2>/dev/null | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('network',{}).get('allowedDomains','NOT SET'))"
```

### 5.3 仅允许托管域名
- **check id**: `m10.sandbox_managed`
- **期望**: `allowManagedDomainsOnly: true`
- **完整修复命令**（一次写入所有三项）:
```bash
SURGE_PORT=6152
jq \
  '.network = (.network // {})
   | .network.httpProxyPort = '"$SURGE_PORT"'
   | .network.allowedDomains = ["api.anthropic.com","*.anthropic.com"]
   | .network.allowManagedDomainsOnly = true' \
  ~/.claude/settings.json > /tmp/_cs.json && mv /tmp/_cs.json ~/.claude/settings.json
echo "Claude Code network sandbox configured"
```

### 5.4 代理 DNS 解析（防 DNS 泄露）
- **check id**: `m10.env_claude_code_proxy_resolves_hosts`
- **环境变量**: `CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1`
- **含义**: 让 Claude Code 通过代理解析域名，而非本地 DNS（配合 `HTTPS_PROXY` 使用）
- **添加到 `~/.zshrc`**:
```bash
export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1
export HTTPS_PROXY=http://127.0.0.1:6152
export HTTP_PROXY=http://127.0.0.1:6152
```

### 5.5 hosts 域名屏蔽状态（信息项）
- **check id**: `m10.hosts_total`
- **说明**: MacAudit 追踪以下 25 个域名在 `/etc/hosts` 中的屏蔽状态（降级为 info 级别，不判 pass/fail）

**22 个核心域名**：

| 类别 | 域名 |
|------|------|
| 主域 | `anthropic.com`, `www.anthropic.com`, `claude.com`, `www.claude.com` |
| API/CDN | `api.anthropic.com`, `cdn.anthropic.com`, `a-cdn.anthropic.com`, `s-cdn.anthropic.com`, `a-api.anthropic.com` |
| 控制台/认证 | `console.anthropic.com`, `api.console.anthropic.com`, `auth.anthropic.com` |
| 文档/状态 | `docs.anthropic.com`, `status.anthropic.com` |
| Claude Web | `claude.ai`, `www.claude.ai`, `claude.dev`, `www.claude.dev` |
| 平台/Code | `code.claude.com`, `platform.claude.com`, `claudeusercontent.com` |
| 遥测 | `statsig.anthropic.com` |

**3 个补充域名**：

| 域名 | 用途 |
|------|------|
| `downloads.claude.ai` | Claude Code 安装包/版本指针下载源 |
| `storage.googleapis.com` | Claude Code 二进制更新包托管（GCS） |
| `statsigapi.net` | Statsig 独立遥测上报端点 |

> ⚠️ **注意**: hosts 屏蔽这些域名会让 Claude Code 完全无法工作。MacAudit 仅检测屏蔽数量供参考，**不建议屏蔽**（"消失的数据"在风控贝叶斯模型中本身是异常信号）。

---

## 6. 环境变量 × 代理配置

来源模块：`m9`（ShellModule）、`m10`（ClaudeProtectionModule）

### 6.1 代理环境变量（必须设置）

| 变量 | check id | 推荐值 |
|------|----------|--------|
| `HTTPS_PROXY` | `m10.proxy_https` / `m9.https_proxy` | `http://127.0.0.1:6152` |
| `HTTP_PROXY` | `m9.http_proxy` | `http://127.0.0.1:6152` |
| `CLAUDE_CODE_PROXY_RESOLVES_HOSTS` | `m10.env_claude_code_proxy_resolves_hosts` | `1` |

### 6.2 NO_PROXY 本地排除（必须）
- **check id**: `m10.proxy_noproxy_in_func`
- **用途**: 防止本地服务请求也走代理，避免连接失败
- **推荐值**:
```bash
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1
export no_proxy=$NO_PROXY
```

### 6.3 推荐的 ~/.zshrc 代理函数

```bash
all_proxy_on() {
  export http_proxy="http://127.0.0.1:6152"
  export https_proxy="http://127.0.0.1:6152"
  export HTTP_PROXY="http://127.0.0.1:6152"
  export HTTPS_PROXY="http://127.0.0.1:6152"
  export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  export NO_PROXY="$no_proxy"
  export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1
  echo "ProxyOn (Surge :6152)"
}

all_proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
  unset CLAUDE_CODE_PROXY_RESOLVES_HOSTS
  echo "ProxyOff"
}

# 默认开启（可选）
all_proxy_on > /dev/null 2>&1
```

### 6.4 危险环境变量（不应设置）

以下变量**期望值为 `not set`**，设置后增加封号风险：

| 变量 | check id | 风险说明 |
|------|----------|----------|
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` | `m10.env_no_disable_traffic` | 关闭遥测是中文社区特有行为，风控直接推断地区；同时导致 Opus 4.6 1M/Fast Mode 不可用 |
| `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1` | `m10.env_no_disable_survey` | 属于遥测关闭链路，增加地域风险标签 |
| `DISABLE_TELEMETRY=1` | `m10.env_no_disable_telemetry` | 完全禁用 GrowthBook，自动成为风控异常用户 |
| `ANTHROPIC_BASE_URL=<自定义>` | `m10.env_no_custom_api` | 通过 GrowthBook 的 apiBaseUrlHost 字段上报到服务端，标记为危险 |
| `NODE_TLS_REJECT_UNAUTHORIZED=0` | `m10.env_no_tls_skip` | 跳过 TLS 证书验证，被 Remote Managed Settings 标记为危险变量 |

**验证命令**:
```bash
# 检查危险变量是否存在
for var in CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
           CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY \
           DISABLE_TELEMETRY \
           ANTHROPIC_BASE_URL \
           NODE_TLS_REJECT_UNAUTHORIZED; do
  val="${!var}"
  if [[ -n "$val" ]]; then
    echo "⚠ $var=$val (SHOULD BE UNSET)"
  else
    echo "✓ $var not set"
  fi
done
```

---

## 7. 浏览器防泄露（Chrome / Safari）

### 7.1 Chrome 完整防泄露配置

| check id | 名称 | 期望值 | 修复命令 |
|----------|------|--------|----------|
| `m14.webrtc_ip` | WebRTC IP 处理 | `disable_non_proxied_udp` | 见 §2.2 |
| `m14.doh` | Chrome DoH | `off` | 见 §3.3 |
| `m14.builtin_dns` | Chrome 内置 DNS | `0` | 见 §3.2 |
| `m14.network_predict` | 网络预加载 | `2`（禁用） | `defaults write ... NetworkPredictionOptions -int 2` |
| `m14.metrics` | 遥测上报 | `0` | `defaults write ... MetricsReportingEnabled -bool false` |

### 7.2 Safari 防泄露配置

| check id | 名称 | 期望值 |
|----------|------|--------|
| `m15.search_universal` | 网页搜索上报 | `0` |
| `m15.preload` | 预加载顶部结果 | `0` |
| `m15.enhanced_private` | 私有浏览指纹保护 | `1` |
| `m15.enhanced_regular` | 常规浏览指纹保护（macOS 26+）| `1` |

---

## 8. 身份 / 地理信号对齐

来源模块：`m10`（ClaudeProtectionModule）、`m9`（ShellModule）

> **核心原则**: 代理出口 IP 的地理位置、时区、语言、DNS 必须一致，任何不匹配都是风控信号。

### 8.1 时区对齐
- **check id**: `m10.tz_info`
- **验证**: 系统时区应与代理出口 IP 的地理位置一致
```bash
# 查看当前时区
sudo systemsetup -gettimezone
# 期望（美国代理示例）: America/New_York 或 America/Los_Angeles

# 查看 IP 时区
curl -s https://ipapi.co/timezone
```

### 8.2 语言环境对齐
- **check id**: `m10.lang_check` / `m9.lang_check`
- **验证**:
```bash
echo "LANG=$LANG"
echo "LC_ALL=$LC_ALL"
defaults read -g AppleLanguages | head -5
```
- **期望**（美国代理示例）:
  - `LANG=en_US.UTF-8`
  - `LC_ALL=` 未设置 或 `en_US.UTF-8`
  - `AppleLanguages` 第一项为 `en-US`

> ⚠️ `LANG=zh_CN.UTF-8` 或 `LC_ALL=zh_CN.UTF-8` 是强地理信号，无论代理在哪里都会被检测到。

### 8.3 npm 源地理信号
- **check id**: `m10.npm_registry`
- **期望值**: `https://registry.npmjs.org/`
- **验证**: `npm config get registry`
- **风险**: npmmirror（`registry.npmmirror.com`）、tuna 镜像等国内源是强地理位置信号
- **修复**: `npm config set registry https://registry.npmjs.org/`

### 8.4 zsh history 中文命令
- **check id**: `m9.zsh_history_cjk`
- **期望**: `0`（无中文字符行）
- **验证**: `grep -P '[\x{4e00}-\x{9fff}]' ~/.zsh_history | wc -l`

### 8.5 git email 身份泄露
- **check id**: `m10.git_email_leak`
- **验证**: `git config --global user.email`
- **风险**: Claude Code 读取此字段作为用户身份信号上报 GrowthBook，即使未 OAuth 登录也会被采集

---

## 9. IP 质量评估（出口 IP 检测项）

来源模块：`m13`（IPQualityModule）

MacAudit 对出口 IP 执行以下检测，Surge 配置应确保出口 IP 通过这些检查：

### 9.1 Phase B：API 风险评估

| check id | 名称 | 期望 |
|----------|------|------|
| `m13.is_proxy` | 代理检测 | `false`（住宅 IP 不应被标记为代理） |
| `m13.is_vpn` | VPN 检测 | `false`（住宅 IP 更佳） |
| `m13.is_tor` | Tor 检测 | `false` |
| `m13.is_datacenter` | 数据中心检测 | `false`（数据中心 IP 风险高） |
| `m13.ip_type` | IP 类型 | `residential`（住宅 IP 最优） |
| `m13.risk_hosting` | 托管检测 | `false` |

### 9.2 Phase C：DNSBL 黑名单
- **check id**: `m13.dnsbl_summary`
- **期望**: 未被任何 DNSBL 黑名单收录
- **包含列表**: Spamhaus ZEN, SORBS, SpamCop, Barracuda 等 13 个列表

### 9.3 Phase D：SMTP 端口
- **check id**: `m13.smtp_port25` / `m13.smtp_port587`
- **说明**: Port 25 开放是邮件服务器信号，通常意味着数据中心/VPS IP，不是住宅 IP 的特征

### 9.4 外部验证建议
```
□ https://ipleak.net       — 综合 IP/DNS/WebRTC 泄露检测
□ https://browserleaks.com — 浏览器指纹全面检测
□ https://whoer.net        — 匿名度评分
□ https://ip-api.com       — IP 地理/ASN/代理检测
□ https://ipapi.is         — VPN/数据中心/住宅 IP 分类
```

---

## 10. 防火墙 / 系统安全

来源模块：`m2`（NetworkSecurityModule）、`m4`（PrivacyModule）

### 10.1 防火墙配置

| check id | 名称 | 期望值 | 验证命令 |
|----------|------|--------|----------|
| `m2.firewall` | 防火墙全局状态 | `enabled` | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` |
| `m2.stealth` | 隐身模式 | `enabled` | `/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode` |
| `m2.allowsigned` | 允许已签名应用 | `enabled` | 确保 Claude Code（已签名）不被防火墙阻断 |

### 10.2 mDNS 多播（本地网络广播）
- **check id**: `m4.mdns` / `m10.mdns` — `networkRisk: true`
- **期望**: 禁用（`NoMulticastAdvertisements=true`）
- **修复命令**:
```bash
sudo defaults write /Library/Preferences/com.apple.mDNSResponder \
  NoMulticastAdvertisements -bool true
sudo killall -HUP mDNSResponder
```

### 10.3 Captive Portal 自动检测
- **check id**: `m4.captive` — `networkRisk: true`
- **风险**: 连接新 Wi-Fi 时自动向 Apple 发送 HTTP 探测请求，暴露真实 IP 和网络行为

---

## 11. Surge 配置模板（汇总）

基于以上所有检测规则，生成完整 Surge 配置片段：

### [General] 段

```ini
[General]
# 代理端口（Claude Code settings.json 中同步配置为 6152）
http-listen = 127.0.0.1:6152
socks5-listen = 127.0.0.1:6153

# 增强模式（Fake IP DNS，接管系统 DNS）
enhanced-mode-by-rule = true

# 禁用 IPv6（防止 IPv6 直连绕过代理）
ipv6 = false
ipv6-vif = disabled

# DNS 加密（防止 DNS 泄露）
encrypted-dns-server = https://1.1.1.1/dns-query, https://8.8.8.8/dns-query

# 让 Surge 接管 DNS 解析
use-local-host-item-for-proxy = true
```

### [Rule] 段（必须包含）

```ini
[Rule]
# ═══════════════════════════════════════════════════════
# 1. WebRTC/STUN 泄露防护（最高优先级）
# ═══════════════════════════════════════════════════════
AND,((PROTOCOL,STUN),(NOT,((OR,((DOMAIN-SUFFIX,anthropic.com),(DOMAIN-SUFFIX,claude.ai)))))),REJECT

# ═══════════════════════════════════════════════════════
# 2. Anthropic / Claude 核心域名 → 强制走代理
# ═══════════════════════════════════════════════════════
DOMAIN-SUFFIX,anthropic.com,YourProxy
DOMAIN-SUFFIX,claude.ai,YourProxy
DOMAIN-SUFFIX,claude.com,YourProxy
DOMAIN-SUFFIX,claude.dev,YourProxy
DOMAIN-SUFFIX,claudeusercontent.com,YourProxy

# ═══════════════════════════════════════════════════════
# 3. 遥测域名 → 代理（不建议屏蔽，见 §5 说明）
# ═══════════════════════════════════════════════════════
DOMAIN-SUFFIX,statsig.anthropic.com,YourProxy
DOMAIN-SUFFIX,statsigapi.net,YourProxy

# ═══════════════════════════════════════════════════════
# 4. Claude Code 更新/下载 → 代理
# ═══════════════════════════════════════════════════════
DOMAIN,downloads.claude.ai,YourProxy
# 注意: storage.googleapis.com 范围很广，按需添加

# ═══════════════════════════════════════════════════════
# 5. 本地流量 → 直连
# ═══════════════════════════════════════════════════════
DOMAIN,localhost,DIRECT
IP-CIDR,127.0.0.0/8,DIRECT
IP-CIDR,192.168.0.0/16,DIRECT
IP-CIDR,10.0.0.0/8,DIRECT
IP-CIDR,172.16.0.0/12,DIRECT
```

### 验证清单（给 CC 进程执行）

```bash
#!/bin/bash
# MacAudit Surge 配置快速验证脚本

echo "=== Surge 核心功能 ==="
echo -n "Fake IP DNS: "
scutil --dns | grep -q '198.18.0.2' && echo "✓" || echo "✗ 未检测到 198.18.0.2"

echo -n "TUN 接口: "
ifconfig | grep -q 'utun' && echo "✓" || echo "✗ 未找到 utun 接口"

echo -n "Dashboard (6170): "
lsof -nP -iTCP:6170 -sTCP:LISTEN 2>/dev/null | grep -q LISTEN && echo "✓" || echo "✗"

echo -n "STUN 拦截规则: "
find ~/Library/Application\ Support/Surge -name '*.conf' -exec grep -l 'PROTOCOL,STUN' {} \; 2>/dev/null \
  | grep -q . && echo "✓" || echo "✗ 未找到 STUN 规则"

echo ""
echo "=== IPv6 泄露防护 ==="
echo -n "全局 IPv6 地址: "
COUNT=$(ifconfig | grep 'inet6' | grep -v '::1\|fe80' | wc -l | tr -d ' ')
[[ "$COUNT" -eq 0 ]] && echo "✓ (0 个)" || echo "✗ ($COUNT 个活跃 IPv6 地址)"

echo -n "IPv6 路由通告: "
VAL=$(sysctl -n net.inet6.ip6.accept_rtadv 2>/dev/null)
[[ "$VAL" == "0" ]] && echo "✓" || echo "✗ ($VAL)"

echo ""
echo "=== Claude Code 配置 ==="
echo -n "settings.json 代理端口: "
PORT=$(cat ~/.claude/settings.json 2>/dev/null | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('network',{}).get('httpProxyPort','NOT SET'))" 2>/dev/null)
[[ "$PORT" != "NOT SET" ]] && echo "✓ ($PORT)" || echo "✗ 未配置"

echo -n "PROXY_RESOLVES_HOSTS: "
[[ -n "$CLAUDE_CODE_PROXY_RESOLVES_HOSTS" ]] && echo "✓ ($CLAUDE_CODE_PROXY_RESOLVES_HOSTS)" || echo "✗ 未设置"

echo ""
echo "=== 危险环境变量 ==="
for var in CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
           CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY \
           DISABLE_TELEMETRY \
           NODE_TLS_REJECT_UNAUTHORIZED; do
  val="${!var}"
  if [[ -n "$val" ]]; then
    echo "✗ $var=$val"
  else
    echo "✓ $var (not set)"
  fi
done

echo ""
echo "=== 语言/地理信号 ==="
echo "LANG: $LANG"
echo "LC_ALL: ${LC_ALL:-not set}"
TZ_SYSTEM=$(sudo systemsetup -gettimezone 2>/dev/null | awk '{print $NF}')
echo "系统时区: $TZ_SYSTEM"
echo "npm 源: $(npm config get registry 2>/dev/null)"
echo ""
echo "=== 完成 ==="
```

---

*本文档由 MacAudit v0.1.5 检测规则自动整理生成，涵盖 m2/m3/m4/m8/m9/m10/m13/m14/m15 共 9 个模块的相关检测项。*
