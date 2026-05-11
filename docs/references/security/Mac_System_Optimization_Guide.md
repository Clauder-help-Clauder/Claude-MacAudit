# Mac 系统优化与加固指南

> 审计日期：2026-04-06（第三版，根据用户决策终版）
> 目标机器：testuser's MacBook（Intel，macOS）
> 数据来源：mac_audit_v1 + mac_audit_v2 + 网络最佳实践 + project.md 方案 + Surge 终版配置 + 用户决策

---

## 第一部分：当前系统状态总览

### 安全机制现状

| 机制 | 状态 | 评级 |
|------|------|:----:|
| SIP（系统完整性保护） | 已启用 | 🟢 |
| Gatekeeper | 已启用 | 🟢 |
| Homebrew 匿名统计 | 已禁用 | 🟢 |
| 防火墙 | 关闭 | 🔴 |
| 隐身模式 | 关闭 | 🔴 |
| FileVault 磁盘加密 | 关闭 | 🔴 |
| SSH 远程登录 | 开启，全接口暴露 | 🟡 保留 |
| SMB 文件共享 | 开启，访客可写 | 🔴 |
| Apple Remote Events | 开启（端口 3031） | 🔴 |
| AirPlay 接收器 | 开启（端口 5000/7000） | 🔴 |
| Apple Analytics/遥测 | 未关闭 | 🟡 |
| Siri | 未关闭 | 🟡 |
| 广告个性化 | 未关闭 | 🟡 |

### 网络现状

| 项目 | 状态 |
|------|------|
| 主要连接 | Wi-Fi (en0, IP: <dev-ip>) |
| 代理工具 | Surge 增强模式（utun6, Fake IP） |
| 系统级代理 | 未启用（代理仅通过环境变量）— **保持不变** |
| DNS | Surge Fake IP (198.18.0.2) + 阿里 DNS (223.5.5.5) |
| hosts 屏蔽 | 22 条 Anthropic/Claude 域名 |

---

## 重要说明：Surge 终版配置对系统防护的影响

### Surge 终版关键决策

| Surge 决策 | 理由 | 对 Mac 系统的影响 |
|-----------|------|-------------------|
| `FINAL,DIRECT` | 代理有流量限制，非 Claude 流量直连 | hosts 文件成为 Surge 关闭时的**唯一防线**，不可删除 |
| 保留明文 DNS | Host 段已保护 Claude 域名走 DoH | 系统层面无需额外 DNS 加固 |
| Hysteria2 不入 Claude 组 | IP 出口不一致 | 仅 VMess 节点用于 Claude |
| 不启用 encrypted-dns-follow-outbound-mode | DoH 走代理会循环依赖 | 系统无需修改 DNS 路由 |

### Claude 三层防护架构

```
┌────────────────────────────────────────────────────┐
│                Claude 流量防护层次                    │
├────────────────────────────────────────────────────┤
│                                                    │
│  第一层：Surge 规则（主力防护）                      │
│  ├── DOMAIN-SUFFIX 精确匹配 Claude 全域名           │
│  ├── DOMAIN-KEYWORD 兜底捕获未知新域名              │
│  ├── WebRTC STUN REJECT                            │
│  └── Host 段 DoH 保护 Claude 域名 DNS 解析          │
│       状态：✅ 已完成                               │
│                                                    │
│  第二层：pf 防火墙 Kill Switch（可选加固）           │
│  └── Surge 进程消失时阻断所有非本地出站             │
│       状态：❌ 未配置                               │
│       ⚠️ 配置复杂，配错会完全断网，需谨慎测试       │
│                                                    │
│  第三层：hosts 文件（最后防线）                      │
│  └── Surge 关闭时 hosts 阻断 Claude 域名直连        │
│       状态：✅ 已有 22 条规则                       │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 用户决策对本文档的影响

| 项目 | 用户决策 | 理由 |
|------|---------|------|
| SSH | **保留不关** | 两台 Mac 之间有 SSH 需求（远程连接、scp、VS Code Remote），防火墙开启后入站已有过滤 |
| Surge Dashboard | **保持 0.0.0.0 绑定** | 需要从另一台 Mac 远程控制 Surge，但应更换强密码 |
| c-d 别名 | **保留** | 有意使用的快捷方式 |
| NTP 服务器 | **不改** | Apple NTP 可靠且快，换 pool.ntp.org 无实际收益 |
| 系统级代理 | **不配置** | 代理有流量限制，环境变量已够用 |
| pf Kill Switch | **可选** | 配置复杂，配错会断网，需谨慎 |

---

## 第二部分：安全加固（P0 紧急）

### Step 1：开启防火墙 + 隐身模式

**问题**：所有入站端口对局域网完全暴露。

**推荐理由**：
- macOS 最基础的入站防护层
- 隐身模式让 Mac 不响应 ping 和端口扫描
- 零副作用，不影响正常使用
- 开启后 SSH 仍可通过防火墙规则放行

**操作步骤**：

```bash
# 开启防火墙
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# 开启隐身模式
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# 设置已签名应用自动允许入站
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
```

**验证**：
```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# 预期输出：Firewall is enabled. (State = 1)

/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
# 预期输出：Firewall stealth mode is on
```

---

### Step 2：关闭 Apple Remote Events

**问题**：端口 3031 对所有网络接口开放，允许远程 AppleScript 调用。

**推荐理由**：
- 不使用此功能，纯粹是攻击面
- 关闭后 SSH 和其他远程管理不受影响

**操作步骤**：

```bash
sudo systemsetup -setremoteappleevents off
```

**验证**：
```bash
sudo systemsetup -getremoteappleevents
# 预期输出：Remote Apple Events: Off
```

---

### Step 3：关闭 AirPlay 接收器

**问题**：端口 5000/7000 对所有接口开放，接收投屏请求。

**推荐理由**：
- 不使用此功能，纯粹是攻击面

**操作步骤**：

**图形界面**：系统设置 → 通用 → AirDrop 与隔空播放 → 关闭"AirPlay 接收器"

**验证**：
```bash
sudo lsof -i -P -n | grep ControlCe | grep LISTEN
# 预期输出：无结果
```

---

### Step 4：修复 SMB 文件共享

**问题**：两个用户的公共文件夹开启 SMB 共享，**访客无密码可读写**。

**推荐理由**：
- 这是严重安全问题
- 局域网内任何设备都可以无认证写入你的文件夹

**操作步骤**：

```bash
# 移除所有共享点
sudo sharing -r "macuser's Public Folder"
sudo sharing -r "testuser's Public Folder"
```

如果仍需保留共享但加固权限：
```bash
# 只读 + 禁止访客
sudo sharing -a /Users/testuser/Public -n "testuser's Public Folder" -R 1 -g 0 -s 001
```

**验证**：
```bash
sharing -l
# 预期输出：无共享点，或仅只读且禁止访客
```

---

### Step 5：开启 FileVault 磁盘加密

**问题**：磁盘未加密，电脑被盗即可读取所有数据。

**推荐理由**：
- M3 芯片性能影响为零，加一层开机认证保护
- macOS 安全的基础底线

**操作步骤**：

```bash
sudo fdesetup enable
```

系统会生成**恢复密钥** — **务必**保存到密码管理器或纸质备份。

**验证**：
```bash
fdesetup status
# 预期输出：FileVault is On.
```

---

## 第三部分：隐私加固（P1 重要）

### Step 6：关闭 Apple Analytics / Siri / 广告

**问题**：macOS 默认开启诊断数据提交、Siri 数据共享、崩溃报告、个性化广告。

**推荐理由**：
- 桌面 Mac 不需要这些功能
- 关闭不影响系统功能或更新

**操作步骤**：

```bash
# 禁止诊断数据自动提交
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false

# 禁止崩溃报告弹窗
defaults write com.apple.CrashReporter DialogType -string "none"

# 关闭 Siri
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false

# 关闭 Siri 数据共享
defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 0

# 关闭个性化广告
defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false

# 关闭 iCloud 使用追踪
defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false
defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false

# 关闭 Spotlight 建议
defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true
```

**验证**：
```bash
defaults read com.apple.SubmitDiagInfo AutoSubmit        # 预期：0
defaults read com.apple.CrashReporter DialogType         # 预期：none
defaults read com.apple.assistant.support "Assistant Enabled"  # 预期：0
defaults read com.apple.AdLib allowApplePersonalizedAdvertising  # 预期：0
```

---

### Step 7：关闭"重要地点"和基于位置的服务

**推荐理由**：桌面 Mac 不需要这些功能。

**操作步骤**（图形界面）：
1. 系统设置 → 隐私与安全性 → 定位服务
2. 系统服务 → 详细信息，关闭：
   - **重要地点**
   - **基于位置的 Apple 广告**
   - **基于位置的建议**

---

### Step 8：禁用 mDNS 多播广告

**推荐理由**：不用 AirDrop/AirPlay，禁用不受影响。Bonjour 广播构成设备指纹。

```bash
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true
```

---

### Step 9：禁用 Captive Portal 检测

**推荐理由**：不用公共 WiFi，无副作用。macOS 连 Wi-Fi 时会明文访问 `captive.apple.com` 暴露真实 IP。

```bash
sudo defaults write /Library/Preferences/SystemConfiguration/CaptiveNetworkSupport Active -bool false
```

---

### Step 10：屏幕锁定立即要求密码

```bash
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
```

---

### Step 11：AirDrop 设为"仅联系人"

图形界面：系统设置 → 通用 → AirDrop 与隔空播放 → 设为"仅联系人"

---

### Step 12：禁止 .DS_Store 写入网络和 USB 设备

```bash
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
```

---

## 第四部分：终端与开发环境优化（P2）

### Step 13：代理环境变量改为开关函数（必要）

**问题**：代理写死在 `.zshrc`，Surge 关闭时终端卡死。代理有流量限制，需要快速切换。

编辑 `~/.zshrc`，将硬编码代理替换为：

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

# 默认开启代理
proxy_on > /dev/null 2>&1
```

使用：`proxy_off` 临时关闭，`proxy_on` 重新开启。

---

### Step 14：清理 Git 重复配置

```bash
git config --global --unset-all safe.directory
git config --global --add safe.directory /usr/local/Homebrew
git config --global --add safe.directory /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core
git config --global --add safe.directory /usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask
```

---

### Step 15：Surge Dashboard 更换强密码

**问题**：Dashboard 绑定 `0.0.0.0:6170`，当前密码为 `dler`（默认弱密码）或 `password`。

**保持 0.0.0.0 绑定**（需要从另一台 Mac 远程控制），但**必须更换密码**。

**操作步骤**：
1. 打开 Surge → 设置 → HTTP API / External Controller
2. 将密码从当前值改为强密码（建议 16+ 字符，含大小写字母数字符号）
3. 保存

---

## 第五部分：系统体验优化（P3 可选）

### Step 16：Finder 优化

```bash
# 始终显示文件扩展名
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# 排序时文件夹优先
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# 展开保存面板
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

killall Finder
```

### Step 17：截图自定义

```bash
mkdir -p ~/Screenshots
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
killall SystemUIServer
```

---

## 第六部分：推荐安装的安全工具

| 工具 | 用途 | 安装方式 | 优先级 |
|------|------|---------|:------:|
| **LuLu** | 免费开源出站防火墙，监控所有出站连接 | `brew install --cask lulu` | P1 |
| **KnockKnock** | 检测开机启动持久化恶意软件 | `brew install --cask knockknock` | P2 |
| **KeePassXC** | 离线密码管理器 | `brew install --cask keepassxc` | P2 |
| **BleachBit** | 系统清理（缓存/日志/临时文件） | `brew install --cask bleachbit` | P3 |

> **LuLu** 特别推荐 — macOS 内置防火墙只管入站，LuLu 补全出站监控。当任何应用尝试连接外部服务器时，LuLu 会弹窗询问是否允许。

---

## 第七部分：可选加固 — pf Kill Switch

> ⚠️ **配置复杂，配错会完全断网，需要谨慎测试。**

当 Surge 崩溃或退出时，pf 规则阻断所有非本地出站连接，防止 Claude 流量直连。

详见 `setup-claude-env.sh` Step 7（第 322-408 行）。如果决定执行，建议：
1. 先在非关键时段测试
2. 准备好还原命令
3. 确认 pf 规则不影响 SSH（两台 Mac 之间的连接）

---

## 第八部分：加固后验证

完成所有步骤后，运行以下验证脚本：

```bash
echo "=== 1. 防火墙 ==="
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

echo ""
echo "=== 2. SSH（应保持开启）==="
sudo systemsetup -getremotelogin

echo ""
echo "=== 3. Remote Events ==="
sudo systemsetup -getremoteappleevents

echo ""
echo "=== 4. FileVault ==="
fdesetup status

echo ""
echo "=== 5. 共享 ==="
sharing -l

echo ""
echo "=== 6. 监听端口 ==="
echo "  (不应出现 *:3031 和 *:5000/*:7000，*:22 保留)"
sudo lsof -i -P -n | grep LISTEN | grep -E '(\*:3031|\*:5000|\*:7000)'

echo ""
echo "=== 7. Analytics ==="
echo -n "  诊断提交: "; defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null || echo "未设置"
echo -n "  崩溃报告: "; defaults read com.apple.CrashReporter DialogType 2>/dev/null || echo "未设置"
echo -n "  Siri: "; defaults read com.apple.assistant.support "Assistant Enabled" 2>/dev/null || echo "未设置"
echo -n "  广告: "; defaults read com.apple.AdLib allowApplePersonalizedAdvertising 2>/dev/null || echo "未设置"

echo ""
echo "=== 8. Git ==="
git config --global --list 2>/dev/null | grep safe.directory | sort | uniq -c

echo ""
echo "=== 9. zshrc ==="
echo -n "  代理函数: "; grep -c 'proxy_on' ~/.zshrc 2>/dev/null || echo "0"

echo ""
echo "=== 10. 锁屏 ==="
echo -n "  要求密码: "; defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "未设置"
echo -n "  延迟(秒): "; defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "未设置"

echo ""
echo "=== 11. mDNS ==="
echo -n "  多播广告: "; defaults read /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements 2>/dev/null || echo "未设置"

echo ""
echo "=== 12. Captive Portal ==="
echo -n "  状态: "; defaults read /Library/Preferences/SystemConfiguration/CaptiveNetworkSupport Active 2>/dev/null || echo "未设置"
```

### 预期结果

| 检查项 | 预期值 |
|--------|--------|
| 防火墙 | `Firewall is enabled` |
| 隐身模式 | `Stealth mode is on` |
| SSH | `Remote Login: On`（保留） |
| Remote Events | `Remote Apple Events: Off` |
| FileVault | `FileVault is On` |
| SMB 共享 | 无共享点或仅只读 |
| 端口 3031/5000/7000 | 不再出现 |
| 诊断提交 | `0` |
| 崩溃报告 | `none` |
| Siri | `0` |
| 广告 | `0` |
| Git safe.directory | 每条仅 1 次 |
| 代理函数 | `1`（proxy_on 存在） |
| 锁屏要求密码 | `1` |
| 锁屏延迟 | `0` |
| mDNS 多播 | `1`（已禁用） |
| Captive Portal | `0`（已禁用） |

---

## 附录：安全架构图（加固后）

```
┌──────────────────────────────────────────────────────────────┐
│              Mac 安全架构（加固后 — 终版）                     │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  [第一层：系统安全]                                           │
│    ├── SIP ✅                                                │
│    ├── Gatekeeper ✅                                         │
│    ├── FileVault 全盘加密 ✅（Step 5）                        │
│    ├── 防火墙 + 隐身模式 ✅（Step 1）                         │
│    └── 锁屏立即要求密码 ✅（Step 10）                         │
│                                                              │
│  [第二层：Claude 三层防护]                                    │
│    ├── L1: Surge 规则（SUFFIX + KEYWORD 双覆盖）✅            │
│    ├── L2: pf Kill Switch（可选，配置复杂需谨慎）             │
│    └── L3: hosts 22 条屏蔽规则（最后防线）✅                  │
│                                                              │
│  [第三层：网络服务收敛]                                       │
│    ├── SSH 保留（防火墙过滤入站）🟡                           │
│    ├── Remote Events 关闭 ✅（Step 2）                        │
│    ├── AirPlay 接收关闭 ✅（Step 3）                          │
│    ├── SMB 访客共享修复 ✅（Step 4）                          │
│    └── Surge Dashboard 保留远程访问，换强密码 ✅（Step 15）   │
│                                                              │
│  [第四层：隐私防护]                                           │
│    ├── Analytics / Siri / 广告 全关 ✅（Step 6）              │
│    ├── 重要地点 / 位置广告关闭 ✅（Step 7）                   │
│    ├── mDNS 多播广告禁用 ✅（Step 8）                        │
│    ├── Captive Portal 禁用 ✅（Step 9）                      │
│    ├── AirDrop 仅联系人 ✅（Step 11）                        │
│    └── .DS_Store 不写入外部设备 ✅（Step 12）                │
│                                                              │
│  [第五层：终端安全]                                           │
│    ├── proxy_on/proxy_off 开关函数 ✅（Step 13）             │
│    ├── c-d 别名保留（用户有意使用）                           │
│    └── Homebrew 匿名统计禁用 ✅（已做）                      │
│                                                              │
│  [第六层：出站监控]（推荐）                                   │
│    └── LuLu 出站防火墙 — 监控所有应用的出站连接             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```
