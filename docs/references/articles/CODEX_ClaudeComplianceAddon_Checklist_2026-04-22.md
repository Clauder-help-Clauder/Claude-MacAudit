# CODEX 配套文档：ClaudeComplianceAddon 检查项清单

生成日期：2026-04-22  
作者标识：Codex  
目标：在**不改动现有功能**的前提下，为 `MacAudit` 新增一组补充检查项，用于降低官方 `Claude Code` 在企业代理/隐私网络场景下的误判风险与数据损失风险。

---

## 1. 使用原则

本清单仅用于：

- 补充现有检查项的覆盖盲区
- 检查代理、网络、证书、wrapper、备份等一致性问题
- 帮助用户识别容易造成误判、连接异常、数据损失的问题

本清单不用于：

- 隐藏代理痕迹
- 绕过平台风控
- 伪装账号画像
- 绕过地区限制

---

## 2. 新模块定位

建议新增模块名：

- `ClaudeComplianceAddonModule`

模块职责：

- 只新增，不替换现有模块
- 不调整现有 `m9/m10/m3/m13` 的归属
- 不变更现有 check id 和 fix 行为
- 所有新增项默认先作为 supplemental checks 展示

---

## 3. 检查项总表

下表给出建议新增的首批检查项。

| 新 ID | 名称 | 分类 | 风险类型 | 优先级 |
|---|---|---|---|---|
| `addon.proxy_case_consistency` | 代理变量大小写一致性 | 代理一致性 | 误判风险 | P0 |
| `addon.proxy_shell_system_consistency` | Shell 与系统代理一致性 | 代理一致性 | 误判风险 | P0 |
| `addon.proxy_port_alive` | 本地代理端口监听 | 代理一致性 | 稳定性风险 | P0 |
| `addon.proxy_protocol_supported` | 代理协议合规性 | 代理一致性 | 稳定性风险 | P1 |
| `addon.ca_file_present` | 企业 CA 文件存在性 | 企业网络 | 稳定性风险 | P1 |
| `addon.ca_file_readable` | 企业 CA 文件可读性 | 企业网络 | 稳定性风险 | P1 |
| `addon.multi_egress_detected` | 多出口并存 | 网络一致性 | 误判风险 | P1 |
| `addon.route_complexity` | 默认路由复杂度 | 网络一致性 | 稳定性风险 | P2 |
| `addon.claude_wrapper_detected` | Claude 启动包装器检测 | 合规边界 | 误判风险 | P0 |
| `addon.claude_alias_detected` | Claude alias/function 检测 | 合规边界 | 误判风险 | P1 |
| `addon.claude_local_state_present` | 本地状态目录存在性 | 数据保全 | 数据损失风险 | P2 |
| `addon.snapshot_export_ready` | 环境快照导出准备度 | 数据保全 | 数据损失风险 | P2 |

---

## 4. 检查项详细定义

### 4.1 `addon.proxy_case_consistency`

名称：
- 代理变量大小写一致性

检查目的：
- 防止 `HTTP_PROXY/http_proxy`
- `HTTPS_PROXY/https_proxy`
- `NO_PROXY/no_proxy`
出现值不同、只设一半、部分工具走代理部分工具不走代理的情况

建议命令：
```bash
printf "HTTP_UPPER=%s\nHTTP_LOWER=%s\nHTTPS_UPPER=%s\nHTTPS_LOWER=%s\nNO_UPPER=%s\nNO_LOWER=%s\n" \
  "${HTTP_PROXY:-}" "${http_proxy:-}" "${HTTPS_PROXY:-}" "${https_proxy:-}" "${NO_PROXY:-}" "${no_proxy:-}"
```

判定建议：
- 全部为空：`info`
- 大小写成对一致：`pass`
- 某对只设置了一侧或值不一致：`warn`

修复建议：
- 统一大小写两套变量
- 由单一函数统一导出和回收

证据等级：
- `heuristic`

---

### 4.2 `addon.proxy_shell_system_consistency`

名称：
- Shell 与系统代理一致性

检查目的：
- 避免 shell 已代理而系统未代理，或相反
- 降低“CLI 与桌面应用网络画像不一致”的情况

建议命令：
```bash
echo "SHELL_HTTPS=${HTTPS_PROXY:-${https_proxy:-not set}}"
scutil --proxy 2>/dev/null | grep -E 'HTTPSEnable|HTTPSProxy|HTTPEnable|HTTPProxy|SOCKSEnable|SOCKSProxy'
```

判定建议：
- shell 和系统都未设置：`info`
- shell/system 都存在且指向同一出口：`pass`
- 仅一边开启或明显不一致：`warn`

修复建议：
- 明确采用 shell 代理还是系统代理
- 若企业要求仅 CLI 代理，应在报告中标为“已知场景例外”

证据等级：
- `community_supported`

---

### 4.3 `addon.proxy_port_alive`

名称：
- 本地代理端口监听

检查目的：
- 避免环境变量设置正确，但代理程序未运行

建议命令：
```bash
for p in 6152 7890 7897 7891; do
  lsof -nP -iTCP:$p -sTCP:LISTEN 2>/dev/null | tail -n +2 && echo "PORT=$p"
done
```

判定建议：
- 代理变量存在但本地端口无监听：`fail`
- 至少有对应端口监听：`pass`
- 无代理变量：`info`

修复建议：
- 启动对应代理程序
- 或清理无效环境变量

证据等级：
- `code_inferred`

---

### 4.4 `addon.proxy_protocol_supported`

名称：
- 代理协议合规性

检查目的：
- 提示是否使用了官方不推荐/不支持的代理协议

建议命令：
```bash
echo "${HTTPS_PROXY:-${https_proxy:-}} ${HTTP_PROXY:-${http_proxy:-}}"
```

判定建议：
- 出现 `socks5://` / `socks://`：`warn`
- 出现 `http://` / `https://`：`pass`
- 无代理：`info`

证据等级：
- `official`

---

### 4.5 `addon.ca_file_present`

名称：
- 企业 CA 文件存在性

检查目的：
- 企业 HTTPS 解密/受管代理环境下，确认自定义 CA 路径存在

建议命令：
```bash
for v in SSL_CERT_FILE NODE_EXTRA_CA_CERTS REQUESTS_CA_BUNDLE CURL_CA_BUNDLE; do
  eval "val=\${$v:-}"
  [ -n "$val" ] && printf "%s=%s\n" "$v" "$val"
done
```

判定建议：
- 没有配置自定义 CA：`info`
- 配置了但路径不存在：`fail`
- 配置了且路径存在：`pass`

证据等级：
- `official`

---

### 4.6 `addon.ca_file_readable`

名称：
- 企业 CA 文件可读性

检查目的：
- 防止路径存在但权限不可读

建议命令：
```bash
for f in "${SSL_CERT_FILE:-}" "${NODE_EXTRA_CA_CERTS:-}" "${REQUESTS_CA_BUNDLE:-}" "${CURL_CA_BUNDLE:-}"; do
  [ -n "$f" ] && [ -e "$f" ] && [ -r "$f" ] && echo "READABLE:$f" || [ -n "$f" ] && echo "UNREADABLE:$f"
done
```

判定建议：
- 有配置但不可读：`fail`
- 有配置且可读：`pass`
- 无配置：`info`

证据等级：
- `official`

---

### 4.7 `addon.multi_egress_detected`

名称：
- 多出口并存

检查目的：
- 识别系统 VPN、shell proxy、全局 IPv6、系统代理同时存在的复杂网络环境

建议命令：
```bash
echo "SHELL_PROXY=${HTTPS_PROXY:-${https_proxy:-not set}}"
scutil --proxy 2>/dev/null | grep -E 'HTTPSEnable|SOCKSEnable|HTTPEnable'
ifconfig 2>/dev/null | grep inet6 | grep -v 'fe80\|::1\|%lo' | wc -l | tr -d ' '
```

判定建议：
- 单出口或结构清晰：`pass`
- 同时存在多层出口：`warn`

证据等级：
- `heuristic`

---

### 4.8 `addon.route_complexity`

名称：
- 默认路由复杂度

检查目的：
- 识别接口过多、默认路由复杂、桥接/USB/VPN 混合的环境

建议命令：
```bash
route -n get default 2>/dev/null
networksetup -listallnetworkservices 2>/dev/null
```

判定建议：
- 仅信息展示
- 后续可作为场景标签辅助

证据等级：
- `heuristic`

---

### 4.9 `addon.claude_wrapper_detected`

名称：
- Claude 启动包装器检测

检查目的：
- 识别是否存在自定义脚本包裹 `claude` 启动

建议命令：
```bash
command -v claude 2>/dev/null
type claude 2>/dev/null
```

判定建议：
- 官方路径/标准执行文件：`pass`
- shell function / alias / wrapper script：`warn`

修复建议：
- 直接调用官方 `claude`
- 将 wrapper 仅用于本地便利，不要注入网络/认证逻辑

证据等级：
- `code_inferred`

---

### 4.10 `addon.claude_alias_detected`

名称：
- Claude alias/function 检测

检查目的：
- 识别 `.zshrc` / `.bashrc` 中是否定义了 `alias claude=` 或 `claude()`

建议命令：
```bash
grep -nE '(^alias claude=|^claude\(\))' ~/.zshrc ~/.bashrc ~/.zprofile 2>/dev/null || true
```

判定建议：
- 未发现：`pass`
- 发现：`warn`

证据等级：
- `heuristic`

---

### 4.11 `addon.claude_local_state_present`

名称：
- 本地状态目录存在性

检查目的：
- 提醒用户本地是否存在 `Claude Code` 状态目录，可用于备份

建议命令：
```bash
test -d ~/.claude && echo "exists" || echo "missing"
```

判定建议：
- 存在：`info`
- 不存在：`info`

说明：
- 纯数据保全提示，不参与风险分

证据等级：
- `code_inferred`

---

### 4.12 `addon.snapshot_export_ready`

名称：
- 环境快照导出准备度

检查目的：
- 判断是否具备导出环境快照的必要工具与目录能力

建议命令：
```bash
command -v jq >/dev/null 2>&1 && echo jq || echo no-jq
command -v scutil >/dev/null 2>&1 && echo scutil || echo no-scutil
command -v networksetup >/dev/null 2>&1 && echo networksetup || echo no-networksetup
```

判定建议：
- 作为 `info`
- 为后续“导出审计快照”功能做前置准备

证据等级：
- `code_inferred`

---

## 5. 风险层级建议

这些新增项建议不要直接复用现有“安全/中/高”标签语义，而是在报告层附加：

- `违规风险`
- `误判风险`
- `稳定性风险`
- `数据损失风险`

实现上可先作为字符串标签，不改底层 `riskLevel`。

---

## 6. 与现有模块的边界

为避免影响现有功能，建议边界如下：

- `ShellModule`
  保留：已有代理变量、git、TZ、shell 函数项
  新增模块不替代它，只做“交叉一致性判断”

- `NetworkSecurityModule`
  保留：IPv6/DNS/firewall/networksetup
  新增模块只补“多出口并存/代理与系统一致性”

- `IPQualityModule`
  保留：公网 IP / DNSBL / proxy info
  新增模块不重复这些信息

- `ClaudeProtectionModule`
  保留：Claude/Anthropic 相关环境变量与说明
  新增模块补充 wrapper、协议、企业 CA、快照能力

---

## 7. 测试建议

建议新增测试文件：

- `ClaudeComplianceAddonModuleTests.swift`

测试覆盖：

1. 所有新增 check id 唯一
2. 所有新增 checks 归属模块正确
3. 代理变量一致性逻辑
4. wrapper/alias 检测逻辑
5. CA 路径存在/不可读分支
6. 多出口并存的判定逻辑

第一阶段优先做纯静态/纯字符串逻辑测试，不做高耦合环境测试。

---

## 8. 首批上线建议

最推荐先上线这 4 项：

1. `addon.proxy_case_consistency`
2. `addon.proxy_shell_system_consistency`
3. `addon.proxy_port_alive`
4. `addon.claude_wrapper_detected`

理由：

- 不碰现有功能
- 命令简单
- 价值高
- 误报成本低

---

## 9. Codex 备注

这份清单的设计目标是：

- 给开发实现直接落地的输入
- 保持与现有功能并存
- 最大限度降低回归风险

如进入实现阶段，建议严格按：

1. 新模块
2. 新测试
3. 新报告分区

三步推进，而不要修改现有模块行为。
