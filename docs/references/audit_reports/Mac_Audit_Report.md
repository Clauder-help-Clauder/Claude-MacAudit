# Mac 系统审计与加固指南

> 审计日期：2026-04-06
> 目标机器：testuser's MacBook（Intel，macOS）
> 审计范围：系统安全、网络配置、Shell 环境、共享服务、开发工具

---

## 第一部分：当前系统已有的定制化设定

### 1.1 系统外观与交互

| 项目 | 当前设定 | 说明 |
|------|---------|------|
| 界面风格 | Dark（深色模式） | 全局深色主题 |
| 字体抗锯齿阈值 | 4pt | 4pt 以上字体启用抗锯齿 |
| 双击标题栏 | 不最小化 | `AppleMiniaturizeOnDoubleClick = 0` |
| 触控板 Force Click | 已启用 | 支持重按触发 |
| Finder 弹簧文件夹 | 已启用，延迟 0.5s | 拖拽文件到文件夹上自动打开 |
| 屏幕闪烁提醒 | 已关闭 | 不使用视觉提示替代声音 |
| 默认搜索引擎 | Google | Safari 和系统搜索 |

### 1.2 语言与输入

| 项目 | 当前设定 |
|------|---------|
| 系统语言 | 英文（en_US） |
| 语言资产 | 英语 + 中文简体 |
| 自动大写 | 已启用 |
| 自动句号替换 | 已启用（双空格变句号） |
| 拼写检查 | 自动检测语言 |

**自定义文本替换：**

| 缩写 | 替换为 |
|------|--------|
| `omw` | On my way! |
| `msd` | 马上到！ |

### 1.3 终端环境

| 项目 | 当前设定 |
|------|---------|
| 终端模拟器 | Ghostty v1.3.1 |
| Shell | zsh |
| TERM | xterm-ghostty |
| 色彩支持 | truecolor |

**`.zshrc` 内容：**

```bash
# 全局代理环境变量
export http_proxy="http://127.0.0.1:6152"
export https_proxy="http://127.0.0.1:6152"
export all_proxy="socks5://127.0.0.1:6153"
export HTTP_PROXY="http://127.0.0.1:6152"
export HTTPS_PROXY="http://127.0.0.1:6152"
export ALL_PROXY="socks5://127.0.0.1:6153"
export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"

# Claude Code 快捷别名
alias c-d='claude --dangerously-skip-permissions'
```

### 1.4 网络架构

| 项目 | 当前设定 |
|------|---------|
| 主要连接 | Wi-Fi (`en0`，IP: `<dev-ip>`) |
| USB 有线网卡 | `en6`，仅 IPv6 link-local |
| 代理工具 | Surge（增强模式） |
| VPN 隧道 | `utun6`（Surge 创建，IP: `198.18.0.1`） |
| 默认路由 | 优先走 `utun6`（Surge），备用走 `en0` 网关 `10.0.0.1` |

**Surge 监听端口：**

| 端口 | 协议 | 绑定 |
|------|------|------|
| 6152 | HTTP 代理 | 127.0.0.1（仅本地） |
| 6153 | SOCKS5 代理 | 127.0.0.1（仅本地） |
| 6170 | Dashboard | `*`（所有接口） |
| 58346-58348 | 内部服务 | 127.0.0.1（仅本地） |

**DNS 配置：**

| DNS 服务器 | 来源 |
|-----------|------|
| `198.18.0.2` | Surge Fake IP DNS |
| `172.30.102.2` | 局域网内部 DNS |
| `223.5.5.5` | 阿里云公共 DNS |

**系统级代理：** Wi-Fi 和有线网卡的系统 Web 代理均未启用，代理完全通过终端环境变量 + Surge 实现。

### 1.5 Hosts 文件屏蔽

已添加 22 条规则，将 Anthropic/Claude 全部域名指向 `0.0.0.0`：

```
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

> 注意：Surge 增强模式下 hosts 会被旁路，实际访问由 Surge 规则决定。

### 1.6 安全机制现状

| 机制 | 状态 |
|------|------|
| SIP（系统完整性保护） | ✅ 已启用 |
| Gatekeeper | ✅ 已启用 |
| 防火墙 | ❌ 关闭 |
| 隐身模式 | ❌ 关闭 |
| FileVault 磁盘加密 | ❌ 关闭 |

### 1.7 开发工具

| 工具 | 说明 |
|------|------|
| Homebrew | Intel Mac 路径 `/usr/local/Homebrew`，匿名统计已禁用 |
| .NET SDK | 已安装（`/usr/local/share/dotnet`） |
| Git | 全局配置仅有 `safe.directory`（重复 3-4 次） |
| Chrome | 未安装 |

### 1.8 用户账户

| 用户 | 说明 |
|------|------|
| `testuser` | 主用户 |
| `macuser` | 另一个用户（存在 Public 文件夹共享） |

---

## 第二部分：安全加固步骤

### Step 1：开启防火墙 + 隐身模式

**风险**：当前所有入站端口对局域网完全暴露。

```bash
# 开启防火墙
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# 开启隐身模式（不响应 ping 和端口扫描）
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# 设置默认阻止所有入站连接（已签名应用除外）
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
```

**验证：**
```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# 预期输出：Firewall is enabled. (State = 1)

/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
# 预期输出：Firewall stealth mode is on
```

---

### Step 2：关闭 SSH 远程登录

**风险**：SSH (端口 22) 对所有网络接口开放，局域网内任何人可尝试登录。

```bash
sudo systemsetup -setremotelogin off
```

**验证：**
```bash
sudo systemsetup -getremotelogin
# 预期输出：Remote Login: Off
```

---

### Step 3：关闭 Apple Remote Events

**风险**：端口 3031 对外开放，允许远程 Apple Events 调用。

```bash
sudo systemsetup -setremoteappleevents off
```

**验证：**
```bash
sudo systemsetup -getremoteappleevents
# 预期输出：Remote Apple Events: Off
```

---

### Step 4：修复 SMB 文件共享

**风险**：两个用户的公共文件夹开启 SMB 共享，访客无需认证即可读写。

```bash
# 移除共享点
sudo sharing -r "macuser's Public Folder"
sudo sharing -r "testuser's Public Folder"
```

如果仍需保留 testuser 的共享但禁止访客写入：
```bash
# 重新创建共享（只读 + 禁止访客）
sudo sharing -a /Users/testuser/Public -n "testuser's Public Folder" -R 1 -g 0 -s 001
```

**验证：**
```bash
sharing -l
# 预期输出：无共享点，或仅显示只读且禁止访客的共享
```

---

### Step 5：开启 FileVault 磁盘加密

**风险**：磁盘未加密，电脑被盗即可读取所有数据。

```bash
sudo fdesetup enable
```

> 执行后系统会生成恢复密钥，**务必保存到安全位置**（密码管理器、纸质备份等）。
> 首次加密会在后台进行，不影响正常使用。

**验证：**
```bash
fdesetup status
# 预期输出：FileVault is On. / Encryption in progress.
```

---

### Step 6：关闭 AirPlay 接收器

**风险**：端口 5000/7000 对所有接口开放。

**操作路径**：系统设置 → 通用 → AirDrop 与隔空播放 → 关闭"AirPlay 接收器"

或命令行：
```bash
defaults write com.apple.controlcenter "NSStatusItem Visible AirPlay" -bool false
```

**验证：**
```bash
lsof -i -P -n | grep ControlCe | grep LISTEN
# 预期输出：无结果
```

---

### Step 7：限制 Surge Dashboard 绑定地址

**风险**：Surge Dashboard (端口 6170) 绑定 `*`，局域网可访问。

**操作**：打开 Surge → 设置 → HTTP API → 将监听地址从 `0.0.0.0` 改为 `127.0.0.1`

**验证：**
```bash
lsof -i -P -n | grep 6170
# 预期输出：绑定地址应为 127.0.0.1:6170
```

---

### Step 8：Hosts 防护升级为 Surge 规则

**风险**：hosts 文件可被 DoH 和直连 IP 绕过，且不支持通配符。

在 Surge 配置文件的 `[Rule]` 段添加：
```
DOMAIN-SUFFIX,anthropic.com,REJECT
DOMAIN-SUFFIX,claude.ai,REJECT
DOMAIN-SUFFIX,claude.com,REJECT
DOMAIN-SUFFIX,claude.dev,REJECT
DOMAIN-SUFFIX,claudeusercontent.com,REJECT
```

> 这样即使出现新子域名也会被自动覆盖，且不受 DoH 影响。
> hosts 文件中的规则可保留作为 Surge 关闭时的兜底。

---

### Step 9：删除 `.zshrc` 中的危险别名

**风险**：`c-d` 别名跳过 Claude Code 所有权限确认，可能执行危险操作。

编辑 `~/.zshrc`，删除以下行：
```bash
alias c-d='claude --dangerously-skip-permissions'
```

如需便捷启动 Claude，改用安全别名：
```bash
alias c='claude'
```

**验证：**
```bash
grep 'dangerously' ~/.zshrc
# 预期输出：无结果
```

---

### Step 10：添加代理开关函数

**风险**：代理写死在 `.zshrc`，Surge 关闭时终端所有请求超时。

在 `~/.zshrc` 中将硬编码代理替换为函数：

```bash
# 代理开关函数
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

# 默认开启代理（Surge 通常常开）
proxy_on
```

---

### Step 11：清理 Git 重复配置

```bash
# 清除所有重复的 safe.directory
git config --global --unset-all safe.directory

# 重新添加（每条仅一次）
git config --global --add safe.directory /usr/local/Homebrew
git config --global --add safe.directory /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core
git config --global --add safe.directory /usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask
```

补充基本全局配置（按需修改）：
```bash
git config --global user.name "testuser"
git config --global user.email "your-email@example.com"
git config --global core.editor "nano"
git config --global init.defaultBranch main
```

**验证：**
```bash
git config --global --list
# 预期输出：每条 safe.directory 仅出现一次
```

---

### Step 12：确认 `macuser` 用户

系统存在另一个用户 `macuser`，需确认：
- 该用户是否仍在使用？
- 是否需要保留？
- 如不需要，建议移除以减少攻击面

查看用户列表：
```bash
dscl . list /Users | grep -v '^_'
```

---

## 第三部分：加固后验证清单

完成以上步骤后，运行以下命令确认：

```bash
echo "=== 1. 防火墙 ==="
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

echo "=== 2. SSH ==="
sudo systemsetup -getremotelogin

echo "=== 3. Remote Events ==="
sudo systemsetup -getremoteappleevents

echo "=== 4. FileVault ==="
fdesetup status

echo "=== 5. 共享 ==="
sharing -l

echo "=== 6. 监听端口 ==="
sudo lsof -i -P -n | grep LISTEN

echo "=== 7. Git 配置 ==="
git config --global --list

echo "=== 8. 代理别名 ==="
grep -E '(dangerously|proxy_on|proxy_off)' ~/.zshrc
```

**预期结果：**

| 检查项 | 预期值 |
|--------|--------|
| 防火墙 | `Firewall is enabled` |
| 隐身模式 | `Stealth mode is on` |
| SSH | `Remote Login: Off` |
| Remote Events | `Remote Apple Events: Off` |
| FileVault | `FileVault is On` |
| SMB 共享 | 无共享点或仅只读 |
| 端口 22/3031 | 不再出现在监听列表 |
| Surge 6170 | 绑定 `127.0.0.1` |
| Git safe.directory | 每条仅一次 |
| 危险别名 | 不存在 `dangerously` |

---

## 附录：安全架构图

```
┌──────────────────────────────────────────────────────────────┐
│                    Mac 安全架构（加固后）                       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  [第一层：系统安全]                                            │
│    ├── SIP ✅                                                │
│    ├── Gatekeeper ✅                                         │
│    ├── FileVault ✅（加固后）                                  │
│    └── 防火墙 + 隐身模式 ✅（加固后）                           │
│                                                              │
│  [第二层：网络安全]                                            │
│    ├── Surge 增强模式（全流量代理）                              │
│    ├── Surge 规则 REJECT Anthropic 域名（加固后）               │
│    ├── hosts 文件屏蔽（兜底）                                   │
│    ├── SSH 关闭 ✅（加固后）                                    │
│    ├── SMB 共享关闭 ✅（加固后）                                │
│    └── AirPlay 接收关闭 ✅（加固后）                            │
│                                                              │
│  [第三层：终端安全]                                            │
│    ├── 代理开关函数（proxy_on / proxy_off）                     │
│    ├── 移除 dangerously-skip-permissions 别名                  │
│    └── Homebrew 匿名统计已禁用                                 │
│                                                              │
│  [第四层：数据安全]                                            │
│    ├── FileVault 全盘加密                                     │
│    └── 无多余用户共享                                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```
