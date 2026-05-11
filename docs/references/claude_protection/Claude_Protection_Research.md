# Claude 专用网络防护深度研究报告

> 研究时间：2026-04-07
> 目的：为三台 Mac 工作站的 Claude 网络防护提供全面的防御策略

---

## 一、Claude Code CLI 网络配置（官方文档）

### 1.1 代理配置

官方文档地址：`https://code.claude.com/docs/en/network-config`

Claude Code 遵守标准代理环境变量，底层是 Node.js 的代理机制：

```bash
export HTTPS_PROXY=https://proxy.example.com:8080
export HTTP_PROXY=http://proxy.example.com:8080

# NO_PROXY 支持两种格式
export NO_PROXY="localhost 192.168.1.1 example.com .example.com"   # 空格分隔
export NO_PROXY="localhost,192.168.1.1,example.com,.example.com"   # 逗号分隔
export NO_PROXY="*"   # 绕过全部
```

带认证的代理：
```bash
export HTTPS_PROXY=http://username:password@proxy.example.com:8080
```

**重要限制**：
- 官方明确声明**不支持 SOCKS 代理**（`ALL_PROXY=socks5://...` 不生效）
- 不支持 NTLM、Kerberos 等复杂认证；官方建议通过 LLM Gateway 解决

---

### 1.2 影响网络行为的环境变量（完整列表）

**代理与连接**

| 变量 | 用途 |
|------|------|
| `HTTPS_PROXY` / `HTTP_PROXY` | 标准代理，Node.js 原生支持 |
| `NO_PROXY` | 绕过代理的主机列表 |
| `ANTHROPIC_BASE_URL` | 覆盖 API 端点，可指向自定义代理/网关 |
| `CLAUDE_CODE_PROXY_RESOLVES_HOSTS` | 设为 `1` 允许代理执行 DNS 解析 |
| `CLAUDE_ENABLE_STREAM_WATCHDOG` | 设为 `1` 在 90 秒后中止失速的流（代理环境专用） |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | 流空闲超时（默认 90000ms） |
| `API_TIMEOUT_MS` | API 请求超时（默认 600000ms / 10 分钟） |
| `NODE_EXTRA_CA_CERTS` | 企业自定义 CA 证书路径（解决 TLS 拦截问题） |

**mTLS 认证**

| 变量 | 用途 |
|------|------|
| `CLAUDE_CODE_CLIENT_CERT` | mTLS 客户端证书路径 |
| `CLAUDE_CODE_CLIENT_KEY` | mTLS 私钥路径 |
| `CLAUDE_CODE_CLIENT_KEY_PASSPHRASE` | 加密私钥口令 |

**认证**

| 变量 | 用途 |
|------|------|
| `ANTHROPIC_API_KEY` | API 密钥，设置后优先于订阅 OAuth |
| `ANTHROPIC_AUTH_TOKEN` | Bearer Token，用于 LLM Gateway |
| `ANTHROPIC_CUSTOM_HEADERS` | 自定义请求头（换行分隔） |
| `CLAUDE_CODE_OAUTH_TOKEN` | OAuth 访问令牌 |
| `CLAUDE_CODE_OAUTH_REFRESH_TOKEN` | OAuth 刷新令牌 |

**遥测与更新（禁用开关）**

| 变量 | 效果 |
|------|------|
| `DISABLE_TELEMETRY=1` | 禁用 Statsig 遥测 |
| `DISABLE_ERROR_REPORTING=1` | 禁用 Sentry 错误报告 |
| `DISABLE_AUTOUPDATER=1` | 禁用自动更新 |
| `DISABLE_FEEDBACK_COMMAND=1` | 隐藏 `/feedback` 命令 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` | **一键禁用**：同时禁用自动更新 + 反馈命令 + 错误报告 + 遥测 |

---

## 二、必须访问的域名白名单

官方文档 `/en/network-config` 列出的**必须访问**的域名：

| 域名 | 用途 | 是否必须 |
|------|------|---------|
| `api.anthropic.com` | Claude API + OAuth 端点 | 必须 |
| `claude.ai` | claude.ai 账户认证 | 必须（使用 claude.ai 账户时） |
| `platform.claude.com` | Anthropic Console 账户认证 | 必须（使用 Console 时） |
| `storage.googleapis.com` | 二进制下载 + 自动更新 | 安装/更新时必须 |
| `downloads.claude.ai` | 安装脚本、版本指针、插件 | 安装/更新时必须 |

**近期变化**：
- `platform.claude.com` 是新增的白名单域名
- 官方文档域名从 `docs.anthropic.com` 迁移到 `code.claude.com`（301 重定向）
- 安装源从 NPM 迁移到原生安装（`~/.local/bin/claude`），更新域名从 storage.googleapis.com 分出 downloads.claude.ai

---

## 三、遥测机制详解

### 3.1 Statsig（功能开关 + 运营指标）

- 用途：延迟、可靠性、使用模式等运营指标；**不包含代码内容、文件路径、bash 命令**
- 禁用：`DISABLE_TELEMETRY=1`
- 已知问题（Issue #10494，已关闭不予处理）：设置 `DISABLE_TELEMETRY=YES` 后，Claude Code 仍每 10-30 秒向 Google 基础设施（`142.250.0.0/15`）发起连接，每小时约 300-400 次，防火墙屏蔽后功能完全正常，证明为非必要流量。Anthropic 将此 issue 标记为 "Not Planned" 关闭

### 3.2 Sentry（错误报告）

- 用途：运营错误日志
- 禁用：`DISABLE_ERROR_REPORTING=1`
- 数据传输：TLS 加密，静态 256-bit AES 加密
- 端点通常为 `*.sentry.io` 或 `o*.ingest.sentry.io`

### 3.3 默认行为差异

| API 提供商 | Statsig | Sentry | 备注 |
|-----------|---------|--------|------|
| Anthropic 直连 | 默认开启 | 默认开启 | 需手动禁用 |
| Bedrock / Vertex / Foundry | 默认关闭 | 默认关闭 | 无需操作 |

---

## 四、OAuth 认证流程与涉及域名

**认证优先级**（从高到低）：
1. 云提供商凭证（Bedrock / Vertex / Foundry 环境变量）
2. `ANTHROPIC_AUTH_TOKEN`（Bearer Token）
3. `ANTHROPIC_API_KEY`（X-Api-Key 头）
4. `apiKeyHelper` 脚本输出（动态凭证）
5. 订阅 OAuth 凭证（`/login`，默认方式）

**OAuth 流程**：
- 首次运行 `claude` 时自动打开浏览器完成登录
- 浏览器无法打开时，按 `c` 复制 URL 手动粘贴
- macOS 上凭证存储在加密的 macOS Keychain
- Linux/Windows 存储在 `~/.claude/.credentials.json`（Linux 权限 0600）

**涉及的认证域名**：
- `claude.ai`：claude.ai 账户 OAuth 端点
- `platform.claude.com`：Console 账户认证
- `api.anthropic.com/api/oauth/profile`：OAuth 令牌刷新端点

---

## 五、已知代理相关 Bug

### 5.1 NO_PROXY 被忽略（回归 bug）

- Issue #39862：Claude Code v2.1.83 完全忽略 `NO_PROXY` 变量
- 这是 v2.1.38 修复过的 issue #22004 的回归
- 唯一有效的 workaround：
  ```bash
  HTTP_PROXY="" HTTPS_PROXY="" ALL_PROXY="" claude -p "hello"
  ```

### 5.2 OAuth 刷新不走 CONNECT 隧道

- Issue #33642：OAuth token 刷新请求通过代理时使用明文 HTTP GET，而非 CONNECT 隧道
- 症状：API 推理请求（走 CONNECT）正常，但 OAuth 刷新（走 GET）返回 503
- Workaround：将 `api.anthropic.com` 加入 `NO_PROXY`：
  ```bash
  export NO_PROXY="localhost,127.0.0.1,api.anthropic.com"
  ```

### 5.3 HTTP CONNECT 隧道挂起

- Issue #43954：Linux 环境下 HTTP CONNECT 代理中，交互模式每次 API 调用之间挂起约 290 秒

### 5.4 SOCKS 代理不支持但仍尝试使用

- 文档说明不支持 SOCKS，但代码仍会尝试，导致 502 错误

---

## 六、Surge + Claude Code 建议

### 6.1 Surge 规则建议

```
# Claude Code 核心 API
DOMAIN-SUFFIX,api.anthropic.com,YOUR_POLICY
DOMAIN-SUFFIX,claude.ai,YOUR_POLICY
DOMAIN-SUFFIX,platform.claude.com,YOUR_POLICY

# 安装与更新
DOMAIN-SUFFIX,storage.googleapis.com,YOUR_POLICY
DOMAIN-SUFFIX,downloads.claude.ai,YOUR_POLICY

# 遥测（可选择屏蔽或直连）
DOMAIN-KEYWORD,statsig,DIRECT
DOMAIN-KEYWORD,sentry,DIRECT
```

### 6.2 Surge MITM 注意事项

如果 Surge 开启了 TLS 解密（MITM），需要将 Surge 的 CA 证书配置到：
```bash
export NODE_EXTRA_CA_CERTS=/path/to/surge-ca.pem
```

建议对 `api.anthropic.com` 关闭 MITM，避免 TLS 固定导致连接失败。

---

## 七、自动更新机制

**更新域名**：
- `storage.googleapis.com`：二进制文件下载（原始 GCS bucket）
- `downloads.claude.ai`：版本指针、清单文件、签名密钥、插件可执行文件

**更新方式**：
- 原生安装（推荐）：后台自动更新
- Homebrew 安装：不自动更新，需手动执行 `brew upgrade claude-code`

**禁用自动更新**：
```bash
DISABLE_AUTOUPDATER=1
# 强制插件更新即使主更新器禁用
FORCE_AUTOUPDATE_PLUGINS=1
```

---

## 八、账号安全与封号防御（社区情报）

### 8.1 已知封号触发因素

（来自 Reddit r/ClaudeAI、GitHub Issues 社区讨论）

- **IP 出口不一致**：短时间内从不同地理位置的 IP 访问，可能触发安全审查
- **共享账号**：多人共用同一账号同时使用
- **违反 AUP（Acceptable Use Policy）**：生成有害内容、尝试越狱等
- **异常流量模式**：短时间大量 API 调用，超出正常使用范围
- **VPN/代理检测**：部分用户报告使用已知 VPN IP 段被限速或限制

### 8.2 IP 一致性策略

- **建议固定代理出口 IP**：使用同一个代理节点，避免频繁切换
- Surge 配置中已决定仅用 VMess（不用 Hysteria2），原因正是 IP 出口一致性
- 避免同一账号在短时间内从多个国家/地区的 IP 访问

### 8.3 DNS 泄露防护

- Surge 增强模式已接管 DNS（Fake IP 198.18.0.2）
- hosts 文件作为 Surge 关闭时的防线
- WebRTC STUN 已在 Surge 中 REJECT

### 8.4 账号恢复

- 封号后可通过 support@anthropic.com 申诉
- 提供使用场景说明（开发工作站、合法用途）
- API 用户比 Web 用户有更清晰的申诉路径

---

## 九、建议新增的防护措施

### 9.1 .zshrc 新增环境变量

```bash
# === Claude Code 网络优化 ===
# 禁用非必要流量（遥测 + 错误报告 + 自动更新）
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# 允许代理执行 DNS 解析（配合 Surge Fake IP）
export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1

# 流空闲超时保护（代理环境推荐开启）
export CLAUDE_ENABLE_STREAM_WATCHDOG=1
```

### 9.2 hosts 新增域名

```
# Claude Code 更新域名（可选屏蔽，防止 Surge 关闭时自动更新泄露）
0.0.0.0 downloads.claude.ai
0.0.0.0 code.claude.com

# 遥测域名（可选屏蔽）
0.0.0.0 statsig.anthropic.com
# 注意：statsig.anthropic.com 已在现有 hosts 中
```

### 9.3 Surge 规则补充

```
# Claude Code 更新域名（确保走代理）
DOMAIN-SUFFIX,downloads.claude.ai,Claude
DOMAIN-SUFFIX,code.claude.com,Claude

# Google Storage（Claude Code 更新下载源）
DOMAIN-SUFFIX,storage.googleapis.com,Claude
```

---

## 来源

| 来源 | 内容 |
|------|------|
| [code.claude.com/docs/en/network-config](https://code.claude.com/docs/en/network-config) | 企业网络配置官方文档 |
| [code.claude.com/docs/en/env-vars](https://code.claude.com/docs/en/env-vars) | 完整环境变量参考 |
| [code.claude.com/docs/en/authentication](https://code.claude.com/docs/en/authentication) | 认证方式、优先级、存储位置 |
| [code.claude.com/docs/en/data-usage](https://code.claude.com/docs/en/data-usage) | 遥测服务、数据流说明 |
| [code.claude.com/docs/en/troubleshooting](https://code.claude.com/docs/en/troubleshooting) | 代理问题排查 |
| [github.com/anthropics/claude-code/issues/39862](https://github.com/anthropics/claude-code/issues/39862) | NO_PROXY 被忽略 bug |
| [github.com/anthropics/claude-code/issues/33642](https://github.com/anthropics/claude-code/issues/33642) | OAuth 刷新不走 CONNECT 隧道 |
| [github.com/anthropics/claude-code/issues/10494](https://github.com/anthropics/claude-code/issues/10494) | DISABLE_TELEMETRY 无效 |
