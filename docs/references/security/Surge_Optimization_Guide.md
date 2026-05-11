# Surge 配置优化指南

> 审计日期：2026-04-06（第二版，含二次审查）
> 适用配置：CN-CA-CLAUDE.PNG / OVERSEA-CA-CLAUDE.PNG
> 目标：消除配置中的安全缺口，对齐 project.md 方案要求

---

## 当前配置评分（二次审查后）

| 评估维度 | 首次得分 | 修改后得分 | 满分目标 |
|---------|:-------:|:---------:|:--------:|
| Claude 域名覆盖 | 8/10 | 9.5/10 | 补 KEYWORD 后近满分 |
| DNS 安全性 | 6/10 | 7/10 | CN 改明文 + 加 follow-outbound → 9.5 |
| FINAL 策略 | 3/10 | 3/10 | 改代理 + 清 override → 10 |
| WebRTC 防护 | 10/10 | 10/10 | 已满分 |
| 节点冗余 | 7/10 | 7/10 | CN 加组 + OVERSEA 加节点 → 9 |
| 与 project.md 对齐度 | 55% | 72% | 落实全部建议 → 95%+ |

### 已完成的改进

- ✅ 补充 `claudeusercontent.com` 规则（`[Rule]` + `[Host]`）
- ✅ 新增 `DOMAIN-KEYWORD,anthropic` 和 `DOMAIN-KEYWORD,claude` 关键词兜底

### 仍需修复

- ❌ FINAL 仍为 DIRECT
- ❌ CN 明文 DNS 未改
- ❌ CN Proxy Group 未加入 Hysteria2
- ❌ override.conf 的 FINAL,DIRECT 会覆盖主配置
- ❌ Claude-Reach 测试 URL 暴露意图
- ❌ 缺少 encrypted-dns-follow-outbound-mode

---

## 优化 1：FINAL 策略改为走代理【P0】

### 问题

```
FINAL,DIRECT
```

所有未匹配规则的流量**直接裸连**，暴露真实 IP。虽然已新增 `DOMAIN-KEYWORD` 兜底，但仍无法覆盖：
- Anthropic 使用的第三方服务（支付回调、认证服务）不含 "claude" 或 "anthropic" 关键词
- IP 直连的请求不经过域名匹配

### 推荐理由

- `project.md` 明确要求："FINAL 走代理 — 消除未覆盖域名暴露真实 IP 的风险"
- 这是**单点最大风险**，修改成本为零，收益最大
- 副作用：所有非匹配流量也走代理，可能轻微影响非 Claude 流量速度

### 修改方式

**两份配置均需修改**，在 `[Rule]` 段最后一行：

找到：
```
FINAL,DIRECT
```

替换为：
```
FINAL,Claude-CA-ATT-VMESS
```

### 验证方法

```bash
curl -x http://127.0.0.1:6152 https://ipinfo.io/ip
# 预期输出：代理出口 IP，而非你的真实 IP
```

---

## 优化 2：清理 override.conf 中的 FINAL,DIRECT【P0】

### 问题

之前分析过的 override 配置中有：
```
FINAL,DIRECT
```

即使你把主配置改成 `FINAL,Claude-CA-ATT-VMESS`，override 会**覆盖回 DIRECT**，导致优化 1 完全失效。

### 推荐理由

- override 优先级高于主配置
- 不清理 override，修改主配置的 FINAL 毫无意义

### 操作步骤

1. 打开 Surge → 首页或配置页面
2. 找到 **覆盖配置（Override）** 或 **配置片段**
3. 编辑 override.conf，**删除 `FINAL,DIRECT` 这一行**
4. 保留局域网直连规则即可

修改后的 override 应为：
```
# override.conf - 覆盖配置，追加直连IP规则
[Rule]
IP-CIDR,192.168.1.1/32,DIRECT,no-resolve
IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
```

### 验证方法

修改后在 Surge Dashboard → 规则页面，检查 FINAL 策略是否显示为 `Claude-CA-ATT-VMESS`。

---

## 优化 3：CN 配置移除明文 DNS【P0】

### 问题

CN 配置中：
```
dns-server = 119.29.29.29, 223.5.5.5, system
```

明文 DNS 查询**不加密**，ISP 可以看到你在解析 `api.anthropic.com` 等域名。macOS 的 DNS 解析存在"竞速"行为 — 明文和加密 DNS 同时发出请求，谁先响应用谁。

### 推荐理由

- `project.md` 要求："仅使用加密 DNS — 移除明文 DNS，防止竞速泄漏"
- `[Host]` 段已为 Claude 域名指定了 DoH，但系统级明文 DNS 仍然泄漏其他域名的解析
- OVERSEA 配置已经用 `dns-server = system`，不存在此问题 ✅

### 修改方式

**仅 CN 配置需修改**，在 `[General]` 段：

找到：
```
dns-server = 119.29.29.29, 223.5.5.5, system
```

替换为：
```
dns-server = system
```

> **注意**：此修改需要 Surge 增强模式已开启。增强模式下 Surge 接管所有 DNS 请求，`dns-server = system` 仅作为 fallback。

### 验证方法

在 Surge Dashboard → DNS 页面查看所有 DNS 请求，确认没有发往 `119.29.29.29` 或 `223.5.5.5` 的明文查询。

---

## 优化 4：添加 encrypted-dns-follow-outbound-mode【P1】

### 问题

当前加密 DNS 请求（DoH）本身**不走代理**，直接连接 DoH 服务器。DoH 服务器可以看到你的真实 IP。

### 推荐理由

- 让 DoH 请求也遵循 Surge 代理规则
- DoH 服务器（阿里/Google/Cloudflare）将只看到代理出口 IP
- 进一步消除 IP 泄漏路径

### 修改方式

**两份配置均需修改**，在 `[General]` 段的 `encrypted-dns-server` 行后添加：

```
encrypted-dns-follow-outbound-mode = true
```

完整的 `[General]` 段（CN 配置修改后）：
```
[General]
loglevel = notify
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 100.64.0.0/10, localhost, *.local
dns-server = system
encrypted-dns-server = https://dns.alidns.com/dns-query, https://dns.google/dns-query, https://cloudflare-dns.com/dns-query
encrypted-dns-follow-outbound-mode = true
ipv6 = false
proxy-test-url = http://cp.cloudflare.com/generate_204
test-timeout = 5
```

---

## 优化 5：Claude-Reach 测试 URL 改为通用地址【P1】

### 问题

```
Claude-Reach = url-test, ..., url=http://docs.anthropic.com, ...
```

用 `docs.anthropic.com` 做可达性检测，每 600 秒发一次**明文 HTTP** 请求。虽然走代理，但：
- 如果代理节点暂时异常导致该请求直连，会暴露你在访问 Anthropic
- 代理服务器日志中会留下定期访问 Anthropic 的记录

### 推荐理由

- 可达性通过实际使用验证即可，不需要专门探测 Anthropic 域名
- 用通用 URL 替代，消除不必要的意图暴露

### 修改方式

**两份配置均需修改**：

找到：
```
Claude-Reach = url-test, ..., url=http://docs.anthropic.com, interval=600, tolerance=100, timeout=8
```

替换为：
```
Claude-Reach = url-test, ..., url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=100, timeout=8
```

CN 配置完整行：
```
Claude-Reach = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=100, timeout=8
```

OVERSEA 配置完整行：
```
Claude-Reach = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=100, timeout=8
```

---

## 优化 6：CN 配置 Proxy Group 加入 Hysteria2【P1】

### 问题

CN 配置 `[Proxy]` 段有 3 个节点（含 Hysteria2），但 `Claude-Fast` 和 `Claude-Reach` 组**只包含 2 个节点**，Hysteria2 未加入自动测速组。

### 推荐理由

- Hysteria2 节点存在但不参与自动切换，浪费了备用能力
- 当两个 VMess 节点都不可用时，Hysteria2 无法自动接管

### 修改方式

**仅 CN 配置需修改**，将 `[Proxy Group]` 段改为：

```
[Proxy Group]
Claude-Fast = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, url=http://cp.cloudflare.com/generate_204, interval=300, tolerance=50, timeout=3
Claude-Reach = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=100, timeout=8
Claude-CA-ATT-VMESS = select, Claude-Fast, Claude-Reach, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, DIRECT
```

---

## 优化 7：确认 Surge 增强模式已开启【P1】

### 问题

托管配置中无法体现增强模式（TUN）状态，需要在 Surge 客户端中手动确认。

### 推荐理由

- `project.md` 架构要求 "Enhanced Mode (TUN 全局接管)"
- 增强模式下 Surge 在网络层（L3）拦截所有流量，包括不走系统代理的应用
- 没有增强模式，某些应用（如部分 Electron 应用）可能绕过代理直连

### 操作步骤

1. 打开 Surge 主界面
2. 点击左上角开关旁边的"增强模式"（Enhanced Mode）按钮
3. 确认状态为**已开启**（按钮高亮）
4. 首次开启会要求安装系统扩展并输入密码

### 验证方法

```bash
# 检查 utun 接口是否存在
ifconfig | grep utun

# 检查默认路由是否指向 utun
netstat -rn | grep default | head -3
# 预期：default 路由应指向 utun 接口
```

---

## 优化 8：ATT 节点安全性评估【P2】

### 问题

```
🇺🇸 Claude-ATT-VMESS = vmess, iepl.tspvip.cc, 42612, username=..., vmess-aead=true
```

该节点**没有 TLS 和 WebSocket 封装**，VMess 裸连。与 `project.md` 要求的 "Nginx TLS 终端 + WebSocket" 架构不同。

### 分析

| 场景 | 风险 |
|------|------|
| 如果是 IPLC/IEPL 专线 | **低风险** — 专线不经过公网 GFW，无需 TLS 伪装 |
| 如果经过公网 | **高风险** — VMess 裸流量特征可被 DPI 识别 |

### 建议

确认 `iepl.tspvip.cc:42612` 是否为 IEPL 专线端口：
- 如果是：当前配置可接受
- 如果不是：应添加 TLS + WebSocket 封装

添加 TLS+WS 的写法：
```
🇺🇸 Claude-ATT-VMESS = vmess, iepl.tspvip.cc, 443, username=61afa79e-bea9-4163-854f-b3341e41f486, alterId=0, vmess-aead=true, tls=true, ws=true, ws-path=/你的路径, sni=你的域名, skip-cert-verify=false, udp-relay=false
```

---

## 优化 9：OVERSEA 配置增加 Hysteria2 备用节点【P2】

### 问题

OVERSEA 只有 2 个 VMess 节点，没有备用协议。

### 推荐理由

- Hysteria2 基于 QUIC/UDP，与 VMess/TCP 完全不同的协议栈
- CN 配置已经有这个节点，OVERSEA 仅需复制

### 修改方式

在 OVERSEA 配置的 `[Proxy]` 段末尾添加：
```
🇯🇵 CDN-TYO-Hysteria2 = hysteria2, cdn.vps.tokenx.com, 38443, password=c67ea136ac3e21fc0142bf348e347ada, sni=cdn.vps.tokenx.com, skip-cert-verify=false, download-bandwidth=500, port-hopping=38440-38500, port-hopping-interval=30
```

同时更新 `[Proxy Group]`，三个组都加入该节点：
```
Claude-Fast = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, url=http://cp.cloudflare.com/generate_204, interval=300, tolerance=50, timeout=3
Claude-Reach = url-test, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=100, timeout=8
Claude-CA-ATT-VMESS = select, Claude-Fast, Claude-Reach, 🇺🇸 Claude-ATT-VMESS, 🇯🇵 Claude-TYO-VMESS, 🇯🇵 CDN-TYO-Hysteria2, DIRECT
```

---

## 优化 10：增加第三方服务域名规则【P2】

### 问题

Claude 应用使用多个第三方服务。虽然 FINAL 改为代理后已兜底覆盖，但显式规则更清晰可靠。

### 修改方式

**两份配置均需修改**，在 `[Rule]` 段 Datadog 规则后、KEYWORD 规则前添加：

```
# Sentry 错误监控
DOMAIN-SUFFIX,sentry.io,Claude-CA-ATT-VMESS
# LaunchDarkly 功能开关
DOMAIN-SUFFIX,launchdarkly.com,Claude-CA-ATT-VMESS
# Statsig A/B 测试
DOMAIN-SUFFIX,statsig.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,statsigapi.net,Claude-CA-ATT-VMESS
# Stripe 支付（Claude Pro 订阅）
DOMAIN-SUFFIX,stripe.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,stripe.network,Claude-CA-ATT-VMESS
```

---

## 优化 11：CN 配置添加 udp-priority【P3】

### 问题

Hysteria2 基于 QUIC/UDP 协议，需要确保 UDP 流量处理正常。

### 修改方式

**仅 CN 配置**在 `[General]` 段添加：
```
udp-priority = true
```

---

## 优化 12：显式保留 alterId=0【P3】

### 问题

新配置中两个 VMess 节点移除了 `alterId=0` 参数。Surge 默认值为 0，功能上没问题，但不同 Surge 版本可能行为不同。

### 修改方式

在两个 VMess 节点中显式加回 `alterId=0`：
```
🇺🇸 Claude-ATT-VMESS = vmess, iepl.tspvip.cc, 42612, username=..., alterId=0, vmess-aead=true, udp-relay=false
🇯🇵 Claude-TYO-VMESS = vmess, cdn.vps.tokenx.com, 2096, username=..., alterId=0, vmess-aead=true, tls=true, ws=true, ...
```

---

## 完整 [Rule] 段参考（两份配置通用）

```
[Rule]
# Claude/Anthropic 官方
DOMAIN-SUFFIX,anthropic.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claude.ai,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claude.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claude.dev,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,anthropic.ai,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,anthropic-ai.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,claudeai.com,Claude-CA-ATT-VMESS
# Anthropic CDN/分析
DOMAIN,cdn.usefathom.com,Claude-CA-ATT-VMESS
DOMAIN,servd-anthropic-website.b-cdn.net,Claude-CA-ATT-VMESS
# 用户内容 CDN
DOMAIN-SUFFIX,claudeusercontent.com,Claude-CA-ATT-VMESS
# Intercom 客服
DOMAIN-SUFFIX,intercom.io,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,intercomcdn.com,Claude-CA-ATT-VMESS
# Datadog 遥测
DOMAIN-SUFFIX,datadoghq.com,Claude-CA-ATT-VMESS
# Sentry 错误监控
DOMAIN-SUFFIX,sentry.io,Claude-CA-ATT-VMESS
# LaunchDarkly 功能开关
DOMAIN-SUFFIX,launchdarkly.com,Claude-CA-ATT-VMESS
# Statsig A/B 测试
DOMAIN-SUFFIX,statsig.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,statsigapi.net,Claude-CA-ATT-VMESS
# Stripe 支付
DOMAIN-SUFFIX,stripe.com,Claude-CA-ATT-VMESS
DOMAIN-SUFFIX,stripe.network,Claude-CA-ATT-VMESS
# 阻止 WebRTC 泄漏
AND,((PROTOCOL,STUN), (NOT,((OR,((DOMAIN-SUFFIX,anthropic.com), (DOMAIN-SUFFIX,claude.ai), (DOMAIN-SUFFIX,claude.com)))))),REJECT
# 关键词兜底
DOMAIN-KEYWORD,anthropic,Claude-CA-ATT-VMESS
DOMAIN-KEYWORD,claude,Claude-CA-ATT-VMESS
# 兜底：所有未匹配流量走代理
FINAL,Claude-CA-ATT-VMESS
```

---

## 修改优先级总览

| 优先级 | 编号 | 优化项 | 适用配置 | 状态 |
|:------:|:----:|--------|:--------:|:----:|
| **P0** | 1 | FINAL → 代理 | 两份 | ❌ 未改 |
| **P0** | 2 | 清理 override FINAL,DIRECT | 客户端 | ❌ 未确认 |
| **P0** | 3 | CN 移除明文 DNS | 仅 CN | ❌ 未改 |
| **P1** | 4 | encrypted-dns-follow-outbound-mode | 两份 | ❌ 新增 |
| **P1** | 5 | Claude-Reach URL 改通用 | 两份 | ❌ 新增 |
| **P1** | 6 | CN Proxy Group 加 Hysteria2 | 仅 CN | ❌ 未改 |
| **P1** | 7 | 确认增强模式 | 客户端 | 待确认 |
| **P2** | 8 | ATT 节点安全确认 | 确认即可 | 待确认 |
| **P2** | 9 | OVERSEA 加 Hysteria2 | 仅 OVERSEA | ❌ 未改 |
| **P2** | 10 | 第三方服务域名 | 两份 | ❌ 未改 |
| **P3** | 11 | udp-priority | 仅 CN | ❌ 新增 |
| **P3** | 12 | 显式保留 alterId=0 | 两份 | ❌ 新增 |

### 已完成项

| 原编号 | 优化项 | 状态 |
|:------:|--------|:----:|
| 旧-2 | 补充 claudeusercontent.com 规则 | ✅ 已完成 |
| 旧-4 | Host 段补充 claudeusercontent.com | ✅ 已完成 |
| — | 新增 DOMAIN-KEYWORD 兜底 | ✅ 自行添加 |
