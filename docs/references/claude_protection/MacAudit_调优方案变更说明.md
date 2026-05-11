# MacAudit Claude 防护模块 → AI服务调优模块
# 调优方案变更说明 & 手动迁移指南

> 生成日期：2026-04-13  
> 适用版本：v0.1.3（旧）→ v0.1.4（新）  
> 依据：Claude Code 封号机制逆向分析文档（instructkr/claude-code）

---

## 一、核心理念变更

| | 旧版本（v0.1.3）| 新版本（v0.1.4）|
|---|---|---|
| **设计哲学** | 消失策略：屏蔽域名、关闭遥测 | **融入策略：让自己看起来像正常合规用户** |
| **核心原则** | 隔离 Claude Code 的网络行为 | 不做任何异常操作，保持默认行为 |
| **风险判断** | 关闭遥测 = 保护隐私 | 关闭遥测 = **极高封号风险 + 付费功能失效** |

---

## 二、Peer-to-Peer 对比

### 2.1 环境变量对比

| 变量 | 旧版建议 | 新版建议 | 原因 |
|------|---------|---------|------|
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | ✅ 设置=1（推荐） | ❌ **必须删除** | 触发贝叶斯风控标签；关闭 GrowthBook 导致 Opus 1M / Fast Mode 静默失效 |
| `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY` | ✅ 设置=1（推荐） | ❌ **建议删除** | 属于遥测关闭链路，同样增加风控标签 |
| `DISABLE_TELEMETRY` | ✅ 设置=1（推荐） | ❌ **必须删除** | 与 DISABLE_NONESSENTIAL_TRAFFIC 同效，最危险的设置 |
| `DISABLE_UPGRADE_COMMAND` | ✅ 设置=1 | ⚪ 无所谓（低影响） | 不影响安全也不影响风控，可保留可删除 |
| `CLAUDE_CODE_PROXY_RESOLVES_HOSTS` | ✅ 设置=1 | ✅ **保留=1** | 配合代理使用，防 DNS 泄露，安全 |
| `CLAUDE_ENABLE_STREAM_WATCHDOG` | ✅ 设置=1 | ✅ **保留=1** | 流稳定性，不涉及遥测 |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` | ✅ 设置=1 | ✅ **保留=1** | 防止子进程继承 API Key，安全设置 |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | ✅ 设置=90000 | ✅ **保留=90000** | 性能设置，不涉及遥测 |
| `ANTHROPIC_BASE_URL` | 未检测 | ❌ **新增：必须删除** | 服务端 Remote Managed Settings 专门审查此变量 |
| `NODE_TLS_REJECT_UNAUTHORIZED` | 未检测 | ❌ **新增：必须删除** | 服务端标记为危险变量 |

### 2.2 hosts 屏蔽对比

| | 旧版建议 | 新版建议 |
|---|---|---|
| **25 个 Anthropic/Claude 域名** | ✅ 全部屏蔽（推荐操作） | ❌ **全部删除屏蔽，恢复正常** |
| **storage.googleapis.com** | ✅ 屏蔽 | ❌ **删除屏蔽** |
| **statsigapi.net** | ✅ 屏蔽 | ❌ **删除屏蔽** |
| **原因** | 认为可以阻断遥测 | hosts 屏蔽无法阻止 API 请求内嵌的 Attribution Header 和 cch Attestation；"消失的数据"本身是异常信号 |

### 2.3 新增检测项（旧版无，新版新增）

| 检测项 | 新版建议 | 说明 |
|--------|---------|------|
| `deviceId` 检测 | ⚪ 信息展示 | `~/.claude.json` 是跨账号永久设备指纹，封号后需清理 |
| `git user.email` 检测 | ⚪ 信息展示 | Claude Code 读取 git 邮箱作为身份信号上报 |
| `npm registry` 检测 | ✅ 期望官方源 | 国内镜像源是强地理信号 |
| `TZ` 时区检测 | ⚪ 信息展示 | 时区需与代理 IP 地区一致 |
| `ANTHROPIC_BASE_URL` 反向检测 | ❌ 期望=not set | 服务端危险变量 |
| `NODE_TLS_REJECT_UNAUTHORIZED` 反向检测 | ❌ 期望=not set | 服务端危险变量 |

### 2.4 保持不变的项目

以下旧版的调优内容在新版中**完全保留**，无需修改：

- ✅ 代理配置（HTTPS_PROXY / all_proxy_on / all_proxy_off 函数）
- ✅ IPv6 关闭（Wi-Fi 和全接口）
- ✅ mDNS 多播禁用
- ✅ Captive Portal 禁用
- ✅ IPv6 路由通告禁用
- ✅ 防火墙开启 / 隐身模式 / 签名应用
- ✅ LuLu / KnockKnock 安装
- ✅ Surge 配置（TUN / Fake IP / Dashboard / STUN REJECT）
- ✅ macOS Apple 遥测禁用（SubmitDiagInfo / CrashReporter / AdLib / UsageTracking）
- ✅ Claude Code 沙盒配置（settings.json 网络白名单）

---

## 三、已完成旧版调优的电脑：手动迁移步骤

### 第一步：删除危险环境变量（最重要）

```bash
# 从 ~/.zshrc 删除以下变量（如果存在）
sed -i '' '/export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=/d' ~/.zshrc
sed -i '' '/export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=/d' ~/.zshrc
sed -i '' '/export DISABLE_TELEMETRY=/d' ~/.zshrc

# 重新加载
source ~/.zshrc

# 验证已删除（以下三个命令应该都输出 "not set"）
echo "DISABLE_NONESSENTIAL_TRAFFIC: ${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-not set}"
echo "DISABLE_FEEDBACK_SURVEY: ${CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY:-not set}"
echo "DISABLE_TELEMETRY: ${DISABLE_TELEMETRY:-not set}"
```

### 第二步：检查并删除其他危险变量

```bash
# 检查是否存在（如果输出不是 "not set" 则需要删除）
echo "ANTHROPIC_BASE_URL: ${ANTHROPIC_BASE_URL:-not set}"
echo "NODE_TLS_REJECT_UNAUTHORIZED: ${NODE_TLS_REJECT_UNAUTHORIZED:-not set}"

# 如果存在，删除
sed -i '' '/export ANTHROPIC_BASE_URL=/d' ~/.zshrc
sed -i '' '/export NODE_TLS_REJECT_UNAUTHORIZED=/d' ~/.zshrc

source ~/.zshrc
```

### 第三步：清除 /etc/hosts 中的 Anthropic/Claude 屏蔽

```bash
# 查看当前 hosts 中的屏蔽条目（确认需要清理的内容）
grep -E "0\.0\.0\.0.*(anthropic|claude|statsigapi|storage\.googleapis)" /etc/hosts

# 删除所有相关屏蔽（一次执行）
sudo sed -i '' '/0\.0\.0\.0.*anthropic/d' /etc/hosts
sudo sed -i '' '/0\.0\.0\.0.*claude/d' /etc/hosts
sudo sed -i '' '/0\.0\.0\.0.*statsigapi/d' /etc/hosts
sudo sed -i '' '/0\.0\.0\.0.*googleapis/d' /etc/hosts

# 刷新 DNS 缓存
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

# 验证已清除（应该无输出）
grep -E "0\.0\.0\.0.*(anthropic|claude|statsigapi|storage\.googleapis)" /etc/hosts && echo "还有残留！" || echo "✅ 已清除"
```

### 第四步：验证保留的安全变量仍然存在

```bash
# 以下变量应该保持设置（输出应该是对应值，不是 "not set"）
echo "PROXY_RESOLVES_HOSTS: ${CLAUDE_CODE_PROXY_RESOLVES_HOSTS:-not set}"
echo "STREAM_WATCHDOG: ${CLAUDE_ENABLE_STREAM_WATCHDOG:-not set}"
echo "SUBPROCESS_ENV_SCRUB: ${CLAUDE_CODE_SUBPROCESS_ENV_SCRUB:-not set}"
echo "STREAM_IDLE_TIMEOUT_MS: ${CLAUDE_STREAM_IDLE_TIMEOUT_MS:-not set}"
```

如果某个变量显示 "not set"，重新添加：

```bash
# 按需添加缺失的安全变量
{
echo 'export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1'
echo 'export CLAUDE_ENABLE_STREAM_WATCHDOG=1'
echo 'export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1'
echo 'export CLAUDE_STREAM_IDLE_TIMEOUT_MS=90000'
} >> ~/.zshrc && source ~/.zshrc
```

### 第五步：检查 npm registry（新增项）

```bash
# 查看当前 registry
npm config get registry

# 如果不是官方源，修改为官方源
npm config set registry https://registry.npmjs.org/

# 验证
npm config get registry
# 期望输出：https://registry.npmjs.org/
```

### 第六步：确认 git user.email（新增检测项，信息参考）

```bash
# 查看当前 git 邮箱
git config --global user.email

# Claude Code 会读取此邮箱作为身份信号上报
# 建议确保此邮箱与 Claude Code 账号身份一致，避免暴露真实身份
# 如需修改：
# git config --global user.email "your-preferred-email@example.com"
```

### 第七步：确认 deviceId 状态（信息参考）

```bash
# 查看 deviceId 是否存在
cat ~/.claude.json 2>/dev/null | grep -o 'deviceId' | head -1 && echo "⚠ deviceId 存在（跨账号永久设备指纹）" || echo "未找到"

# ⚠ 注意：不要轻易删除 ~/.claude.json
# 只有在封号后需要彻底清理环境时才执行以下步骤：
# 1. 备份有价值的配置：
#    cp -r ~/.claude/skills/ ~/claude_backup_skills/
#    cp ~/.claude/settings.json ~/claude_backup_settings.json
#    cp ~/.claude/CLAUDE.md ~/claude_backup_CLAUDE.md
#    cp -r ~/.claude/rules/ ~/claude_backup_rules/
# 2. 然后完全删除：
#    rm -rf ~/.claude/ && rm ~/.claude.json
```

### 第八步：验证最终状态

```bash
echo "=== 迁移验证 ==="
echo ""
echo "【危险变量（应全部为 not set）】"
echo "DISABLE_NONESSENTIAL_TRAFFIC: ${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-not set}"
echo "DISABLE_FEEDBACK_SURVEY: ${CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY:-not set}"
echo "DISABLE_TELEMETRY: ${DISABLE_TELEMETRY:-not set}"
echo "ANTHROPIC_BASE_URL: ${ANTHROPIC_BASE_URL:-not set}"
echo "NODE_TLS_REJECT_UNAUTHORIZED: ${NODE_TLS_REJECT_UNAUTHORIZED:-not set}"
echo ""
echo "【安全变量（应全部有值）】"
echo "PROXY_RESOLVES_HOSTS: ${CLAUDE_CODE_PROXY_RESOLVES_HOSTS:-not set}"
echo "STREAM_WATCHDOG: ${CLAUDE_ENABLE_STREAM_WATCHDOG:-not set}"
echo "SUBPROCESS_ENV_SCRUB: ${CLAUDE_CODE_SUBPROCESS_ENV_SCRUB:-not set}"
echo "STREAM_IDLE_TIMEOUT_MS: ${CLAUDE_STREAM_IDLE_TIMEOUT_MS:-not set}"
echo ""
echo "【hosts 清理（应无输出）】"
grep -E "0\.0\.0\.0.*(anthropic|claude|statsigapi|googleapis)" /etc/hosts && echo "⚠ 还有残留！" || echo "✅ hosts 已清理"
echo ""
echo "【npm registry（应为官方源）】"
npm config get registry 2>/dev/null || echo "npm 未安装"
```

---

## 四、~/.zshrc 对比参考

### 旧版 ~/.zshrc 相关内容（应删除的部分）

```bash
# ❌ 以下内容应该删除
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
export DISABLE_TELEMETRY=1
export DISABLE_UPGRADE_COMMAND=1   # 无需设置；如已设置可删除（低影响）
```

### 新版 ~/.zshrc 应保留的内容

```bash
# ✅ 安全变量（保留）
export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1
export CLAUDE_ENABLE_STREAM_WATCHDOG=1
export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1
export CLAUDE_STREAM_IDLE_TIMEOUT_MS=90000

# ✅ 代理函数（保留）
all_proxy_on() {
  export http_proxy="http://127.0.0.1:6152"
  export https_proxy="http://127.0.0.1:6152"
  export HTTP_PROXY="http://127.0.0.1:6152"
  export HTTPS_PROXY="http://127.0.0.1:6152"
  export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  echo "代理已开启"
}

all_proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
  echo "代理已关闭"
}

all_proxy_on > /dev/null 2>&1
```

---

## 五、关键原理说明

### 为什么不能关闭遥测？

```
DISABLE_TELEMETRY=1
    ↓
isAnalyticsDisabled() = true
    ↓
is1PEventLoggingEnabled() = false
    ↓
isGrowthBookEnabled() = false
    ↓
所有付费功能 Feature Flag 失效：
  - Opus 4.6 1M 模型 → 静默消失
  - Fast Mode → 不可用
  - Remote Control → 失效
  （无任何报错提示）
```

### 为什么不能屏蔽 hosts？

Claude Code 的通信分两层：
1. **域名层**（被 hosts 影响）：Datadog、BigQuery 遥测通道
2. **API 请求层**（hosts 无法影响）：每个 API 请求的 system prompt 中内嵌 `x-anthropic-billing-header`（Attribution Header）和 `cch`（Attestation token）

屏蔽 hosts 只切断了第1层，第2层完全不受影响。
而第1层数据"消失"本身就是异常信号，风控系统会注意到。

### 为什么关闭遥测是地域标签？

> 关闭遥测的教程几乎只在中文社区传播。风控系统不需要知道你是谁，只需要知道：在所有关闭遥测的用户中，不合规地区用户的比例显著偏高。
> 
> P(不合规地区 | 关闭遥测) 远高于基准概率。

---

## 六、无法规避的硬性检测（参考）

无论如何操作，以下内容 Anthropic 服务端始终可见：

| 信号 | 说明 |
|------|------|
| `cch` Attestation | Bun 底层 Zig 代码生成，无法绕过 |
| Fingerprint 校验 | 盐值 `59cf53e54c78` 硬编码，与服务端强耦合 |
| Session ID / User-Agent | 每个请求携带 |
| IP 地址 / TLS 指纹 | HTTP 连接层，始终可见 |
| OAuth Token | 账号身份 |
| API 调用频率和时间分布 | 行为模式 |

**最安全的做法：合规使用，让自己看起来和正常用户没有区别。**
