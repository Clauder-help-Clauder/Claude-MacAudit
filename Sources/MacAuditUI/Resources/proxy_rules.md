# PROXY RULES

[English](proxy_rules_EN.md) · [中文](proxy_rules.md)

> 所有 Claude Code / Codex 流量必须通过住宅 IP（Residential IP）代理出口

---

## 为什么要走家宽？

- 🔴 机房 IP / VPS / 云服务器 IP 会被 Anthropic 风控标记为高风险标签
- 🔴 数据中心 IP 段有公开黑名单（datacenter、hosting、business），Claude Code 启动时检测
- 🟢 住宅 IP 是唯一能通过 Anthropic 风控的出口类型
- 🔴 被封后 deviceId 被永久关联，换账号无法恢复，必须重置 `~/.claude.json`

---

## 推荐代理软件

| 软件 | 平台 | 说明 |
|------|------|------|
| 🟢 **Surge** | macOS / iOS | 专业网络调试工具，支持规则分流、Fake IP DNS、增强模式 TUN 全局接管。Claude 防护首选。 |
| 🟢 **Shadowrocket** | iOS / macOS | 支持 Shadowsocks / V2Ray / Trojan 多协议，适合作为 Surge 之外的备选。 |
| 🟢 **V2RayU / V2RayX** | macOS | macOS 原生 V2Ray 客户端，支持 VMess / VLESS 协议。需手动配置系统代理。 |
| 🟢 **Clash Verge / ClashX Meta** | macOS / Windows | 规则分流能力强，但需注意 DNS 配置防止泄漏。 |
| 🔴 **严禁安装CC-SWITCH等API切换软件，如需适配其他LLMs，尽量手动编辑配置文件，风险未知, 暂时无法确认。 |

---

## 代理配置五要素

1. 🔴 **出口必须是住宅 IP**（Residential IP），不是机房/VPS/云服务器
2. 🔴 **全局模式**：代理必须覆盖所有流量（含 CLI、npm、git），不能仅代理浏览器
3. 🔴 **IPv6 全关**：IPv6 会绕过代理直连暴露真实 IP（`ipv6=false` / 系统级关闭）
4. 🔴 **DNS 防泄漏**：使用 Fake IP（198.18.0.2）或加密 DNS（DoH/DoT），防止 ISP 窥探
5. 🔴 **AI 服务域名单独走稳定节点**：`anthropic.com` / `claude.ai` / `openai.com` / `chatgpt.com` 建议固定出口，避免频繁切换 IP。Claude 和 Codex 可共用同一住宅 IP（两家公司风控系统独立）

---

## Surge 配置参考（已验证稳定方案）

### [General] 基础配置

```ini
ipv6 = false                    # 禁用 IPv6，防止泄露
ipv6-vif = off                  # TUN 接口也禁用 IPv6
dns-server = 223.5.5.5, 119.29.29.29, system
encrypted-dns-server = https://223.5.5.5/dns-query
udp-policy-not-supported-behaviour = REJECT  # UDP 不支持时拒绝
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, localhost, *.local
```

### [Rule] Claude 专用规则

```ini
# Claude/Anthropic 全域名 → 固定出口
DOMAIN-SUFFIX,anthropic.com,Claude-Stable
DOMAIN-SUFFIX,claude.ai,Claude-Stable
DOMAIN-SUFFIX,claude.com,Claude-Stable
DOMAIN-SUFFIX,claude.dev,Claude-Stable
DOMAIN-SUFFIX,claudeusercontent.com,Claude-Stable
DOMAIN-SUFFIX,statsigapi.net,Claude-Stable
DOMAIN-SUFFIX,datadoghq.com,Claude-Stable
DOMAIN-SUFFIX,intercom.io,Claude-Stable
DOMAIN-KEYWORD,anthropic,Claude-Stable
DOMAIN-KEYWORD,claude,Claude-Stable
```

### [Rule] Codex / OpenAI 专用规则

```ini
# Codex / OpenAI 全域名 → 固定出口
# 可和 Claude 共用 AI-Stable 节点（两家公司风控独立，同住宅 IP 无风险）
DOMAIN-SUFFIX,openai.com,AI-Stable
DOMAIN-SUFFIX,chatgpt.com,AI-Stable
DOMAIN-SUFFIX,oaistatic.com,AI-Stable
DOMAIN-SUFFIX,oaiusercontent.com,AI-Stable
DOMAIN-KEYWORD,openai,AI-Stable
DOMAIN-KEYWORD,chatgpt,AI-Stable

# 风控/遥测（OpenAI 和 Anthropic 一样用 Statsig + Sentry + Datadog）
DOMAIN-SUFFIX,statsig.com,AI-Stable
DOMAIN-SUFFIX,sentry.io,AI-Stable
DOMAIN-SUFFIX,cloudflareinsights.com,AI-Stable
```

> 💡 上方 Claude 规则里的 `Claude-Stable` 也可以改名为统一的 `AI-Stable`，让 Claude + Codex 共享同一个出口节点（推荐，一般家宽用户只有一个住宅 IP）。

### [Rule] STUN/WebRTC 防泄漏

```ini
# 阻止所有非 Claude/Codex 域名的 STUN 请求
AND,((PROTOCOL,STUN),(NOT,((OR,((DOMAIN-SUFFIX,anthropic.com),(DOMAIN-SUFFIX,claude.ai),(DOMAIN-SUFFIX,openai.com),(DOMAIN-SUFFIX,chatgpt.com)))))),REJECT
```

### [Host] Claude / Codex 域名 DNS 加密

```ini
# 强制 AI 服务域名使用 Google DoH 解析
*.anthropic.com = server:https://dns.google/dns-query
*.claude.ai = server:https://dns.google/dns-query
*.claude.com = server:https://dns.google/dns-query
*.statsigapi.net = server:https://dns.google/dns-query
*.openai.com = server:https://dns.google/dns-query
*.chatgpt.com = server:https://dns.google/dns-query
*.oaistatic.com = server:https://dns.google/dns-query
```

### [Proxy Group] 稳定出口（Claude + Codex 共用一个）

```ini
# 推荐：Claude + Codex 共用同一个住宅 IP 节点
AI-Stable = fallback, 主节点, 备节点1, 备节点2,
  url=http://cp.cloudflare.com/generate_204, interval=300, timeout=5
```

### ⚠️ Claude / Codex 账号使用最佳实践

- 🟢 **Claude 和 Codex 可共用同一个住宅 IP 出口**（两家公司风控系统独立）
- 🔴 不要频繁切换出口 IP（每次切换都会增加风控标记）
- 🟢 严格 1 机器 1 住宅 IP 1 组账号的组合最稳定
- 🔴 被封后 deviceId 被永久关联，换账号无法恢复，需重置对应 AI 服务的本地状态

---

## Shadowrocket 配置要点

- 添加节点后选择「全局代理」模式（不是规则模式）
- 安装 CA 证书并信任：设置 → 通用 → 关于本机 → 证书信任设置
- 关闭 IPv6：设置 → 蜂窝网络 → 蜂窝数据选项 → IPv6 设为关闭
- DNS 配置使用加密 DNS：设置中填入 `https://1.1.1.1/dns-query`

---

## V2RayU 配置要点

- PAC 模式不安全，必须使用「全局模式」或配置系统代理覆盖所有流量
- 手动设置系统代理：网络 → Wi-Fi → 代理 → HTTP/HTTPS 填 `127.0.0.1:端口`
- 配合 MacAudit 检测项确认 IPv6 已关闭、DNS 未泄漏
- ⚠️ V2RayU 不支持 Fake IP，需手动配置 DoH 防止 DNS 泄露

---

## Surge 关闭时的应急防护

- 🟢 在 `/etc/hosts` 中添加 Claude 域名 → `0.0.0.0`，阻断直连
- 🟢 hosts 文件是 Surge 关闭后的最后防线，确保即使代理断开也不会裸连
- 🟢 修改 hosts 后运行 `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`
- 🟢 Claude Code 环境变量 `CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1` 确保代理接管 DNS

---

## 验证方法

- 🟢 运行 MacAudit → 确认所有 A0 检测项通过
- 🟢 浏览器访问 [ipleak.net] https://ipleak.net  → 确认 DNS 出口与代理 IP 一致
- 🟢 浏览器访问 [browserleaks.com/webrtc] https://browserleaks.com/webrtc  → 确认 No Leak
- 🟢 浏览器访问 [whoer.net] https://whoer.net → 评分 85+ 且 Proxy 显示 No
- 🟢 终端运行 `curl ip.sb --proxy $HTTPS_PROXY` → 确认出口为住宅 IP

---

## 账号注册最佳实践（账号层防护）

- 🟢 **强烈推荐：全新安装 macOS**（抹掉所有内容和设置 / 全新安装）
  - 设备指纹干净，不被旧账号关联
  - 消除 `~/Library/` 历史登录态、Cookie、Keychain 残留
- 🟢 **推荐使用 iCloud 账户订阅 Claude / Codex**
  - 付款走 App Store IAP（App 内购买），**彻底脱离信用卡**
  - Apple 会加收约 30% 平台抽成，但换来：
    - 无信用卡盗刷 / chargeback 风险
    - 无银行风控标签（信用卡跨账号共用是封号高发原因）
    - 付款合规可追溯（Apple ID 消费记录）
  - 订阅可一键取消，不会被绑定长期扣款
- 🔴 信用卡直付的 AI 订阅是封号风险最高的支付方式之一

---

## 关于我们的实践

> 我们持续运行 **3× Claude Max 20×** 和 **3× Codex 20×** 账号，通过上述代理和系统加固规则保护。**一个月零封号。**

公式很简单但不容易做对：

> **稳定住宅 IP → 所有 Claude 域名走固定节点 → 不换机器不换线路 → 完整执行计划 → 不封号。**

难的是中间的一切：DNS 泄漏防护、IPv6 旁路阻断、确保每个 CLI 工具都走代理、配置 Surge/Clash 规则让 `anthropic.com`、`claude.ai`、`statsigapi.net`、`datadoghq.com` 全部正确路由。MacAudit 自动检测这一切。

**感谢 [wstormai] https://wstormai.store/  在测试期间提供的可靠订阅充值服务。**

**Clauder Help Clauder.** ⭐ 如果这保住了你的账号，给我们一颗星。 [https://github.com/Clauder-help-Clauder/Claude-MacAudit/](https://github.com/Clauder-help-Clauder/Claude-MacAudit/)
