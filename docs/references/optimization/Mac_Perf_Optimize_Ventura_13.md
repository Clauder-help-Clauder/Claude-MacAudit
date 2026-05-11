# Mac 效能优化 — macOS Ventura 13.7.8 版

> 适用系统：macOS Ventura 13.7.8（Intel）
> 定位：AI 开发 / App 开发 / 车机开发工作站
> 核心业务：Claude Code, Codex, OpenCode, Gemini Code, Xcode, Ollama, 向量模型
> 不需要：音乐、视频剪辑、游戏、社交、照片、地图、Apple TV、新闻

---

## 版本特有说明

- macOS Ventura 13 **没有** Apple Intelligence 服务（`intelligenceflowd` 等不存在，无需禁用）
- macOS Ventura 13 **没有** Stage Manager 点击桌面功能（`EnableStandardClickToShowDesktop` 不适用）
- macOS Ventura 13 **没有** Liquid Glass UI（透明度效果较轻，但关闭仍有收益）
- `launchctl bootout` / `launchctl disable` 在 Ventura 上完全支持
- Intel Mac 上 FileVault 有轻微性能开销（与 Apple Silicon 零开销不同）
- Intel Mac 的 `pmset` 选项比 Apple Silicon 多（如 `hibernatemode`、`sms`）
- Ventura 上部分服务名称与 Tahoe 不同（已在脚本中标注）

---

## 一、关闭所有视觉特效

###bash
#!/bin/bash
# === macOS Ventura 13.7.8 — 关闭视觉特效 ===

# 窗口动画
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g NSToolbarFullScreenAnimationDuration -float 0
defaults write -g NSDocumentRevisionsWindowTransformAnimation -bool false
defaults write -g NSBrowserColumnAnimationSpeedMultiplier -float 0

# 滚动
defaults write -g NSScrollAnimationEnabled -bool false
defaults write -g NSScrollViewRubberbanding -bool false

# Quick Look
defaults write -g QLPanelAnimationDuration -float 0

# 工具提示立即显示
defaults write -g NSInitialToolTipDelay -integer 0

# Dock
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock springboard-show-duration -float 0
defaults write com.apple.dock springboard-hide-duration -float 0
defaults write com.apple.dock springboard-page-duration -float 0
defaults write com.apple.dock mineffect -string "scale"

# Finder
defaults write com.apple.finder DisableAllAnimations -bool true

# 弹簧加载延迟清零
defaults write -g com.apple.springing.delay -float 0

# 系统级减少动态效果 + 透明度
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true

# 关闭应用打开确认弹窗动画
defaults write com.apple.LaunchServices LSQuarantine -bool false

# 使设置生效
killall Dock
killall Finder

echo "视觉特效已关闭（macOS Ventura 13.7.8）"
###


> **与 Tahoe 版差异**：无 `EnableStandardClickToShowDesktop`（Ventura 没有此功能）



## 三、关闭非必要系统服务

###bash
#!/bin/bash
# === macOS Ventura 13.7.8 — 关闭非必要服务 ===
# 还原：launchctl enable gui/501/<服务名> 或 sudo launchctl enable system/<服务名>
# 完全还原：sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.* && 重启

echo "=== 1. Siri ==="
# 注意：Ventura 没有 Apple Intelligence 系列服务
SIRI=(
  com.apple.assistant_service com.apple.assistantd com.apple.assistant_cdmd
  com.apple.Siri.agent com.apple.siriactionsd com.apple.siriinferenced
  com.apple.sirittsd com.apple.SiriTTSTrainingAgent com.apple.siriknowledged
  com.apple.parsec-fbf com.apple.parsecd
  com.apple.knowledge-agent com.apple.suggestd com.apple.naturallanguaged
)
for s in "${SIRI[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
echo "  完成"

echo "=== 2. 音乐 / 媒体 / 娱乐 / 游戏 ==="
MEDIA=(
  com.apple.itunescloudd com.apple.mediastream.mstreamd
  com.apple.videosubscriptionsd com.apple.watchlistd
  com.apple.gamed com.apple.voicebankingd
  com.apple.newsd com.apple.weatherd com.apple.tipsd com.apple.financed
  com.apple.mediaanalysisd
)
for s in "${MEDIA[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
sudo launchctl bootout system/com.apple.GameController.gamecontrollerd 2>/dev/null
sudo launchctl disable system/com.apple.GameController.gamecontrollerd 2>/dev/null
echo "  完成"

echo "=== 3. 照片 / 地图 / 社交 / 通话 ==="
SOCIAL=(
  com.apple.photoanalysisd com.apple.photolibraryd com.apple.cloudphotod
  com.apple.Maps.pushdaemon com.apple.Maps.mapssyncd
  com.apple.maps.destinationd com.apple.navd
  com.apple.geodMachServiceBridge com.apple.geoanalyticsd
  com.apple.imagent com.apple.imautomatichistorydeletionagent
  com.apple.imtransferagent com.apple.avconferenced
  com.apple.telephonyutilities.callservicesd com.apple.CallHistoryPluginHelper
)
for s in "${SOCIAL[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
echo "  完成"

echo "=== 4. iCloud / 家庭 / 教育 / Screen Time / Time Machine ==="
CLOUD=(
  com.apple.cloudd com.apple.cloudpaird com.apple.CloudSettingsSyncAgent
  com.apple.iCloudNotificationAgent com.apple.iCloudUserNotifications
  com.apple.protectedcloudstorage.protectedcloudkeysyncing
  com.apple.homed com.apple.familycircled
  com.apple.familycontrols.useragent com.apple.familynotificationd
  com.apple.ScreenTimeAgent com.apple.macos.studentd com.apple.progressd
  com.apple.TMHelperAgent
)
for s in "${CLOUD[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
sudo launchctl bootout system/com.apple.backupd 2>/dev/null
sudo launchctl disable system/com.apple.backupd 2>/dev/null
sudo launchctl bootout system/com.apple.backupd-helper 2>/dev/null
sudo launchctl disable system/com.apple.backupd-helper 2>/dev/null
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
echo "  完成"

echo "=== 5. 遥测 / 分析 / 追踪 ==="
TELEMETRY_USER=(
  com.apple.UsageTrackingAgent com.apple.BiomeAgent com.apple.biomesyncd
  com.apple.inputanalyticsd com.apple.ap.adprivacyd com.apple.ap.promotedcontentd
  com.apple.triald com.apple.routined com.apple.duetexpertd
  com.apple.ContextStoreAgent
)
for s in "${TELEMETRY_USER[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
TELEMETRY_SYS=(
  com.apple.analyticsd com.apple.ecosystemanalyticsd
  com.apple.audioanalyticsd com.apple.wifianalyticsd
  com.apple.biomed com.apple.triald.system
)
for s in "${TELEMETRY_SYS[@]}"; do
  sudo launchctl bootout system/${s} 2>/dev/null; sudo launchctl disable system/${s} 2>/dev/null
done
echo "  完成"

echo "=== 6. 共享 / Sidecar / Handoff / 日历 / 提醒 / Apple Pay ==="
MISC=(
  com.apple.sharingd
  com.apple.screensharing.agent com.apple.screensharing.menuextra com.apple.screensharing.MessagesAgent
  com.apple.sidecar-hid-relay com.apple.sidecar-relay
  com.apple.calaccessd com.apple.dataaccess.dataaccessd com.apple.remindd
  com.apple.rapportd-user com.apple.passd
  com.apple.replicatord com.apple.chronod
  com.apple.helpd com.apple.followupd
  com.apple.icloud.searchpartyuseragent com.apple.findmy.findmylocateagent
)
for s in "${MISC[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
sudo launchctl bootout system/com.apple.netbiosd 2>/dev/null
sudo launchctl disable system/com.apple.netbiosd 2>/dev/null
echo "  完成"

echo ""
echo "=== 所有服务已禁用，请重启 Mac 使更改完全生效 ==="
###

> **与 Tahoe 版差异**：
> - 无 `intelligenceflowd`、`intelligencecontextd`、`intelligenceplatformd`、`generativeexperiencesd`、`knowledgeconstructiond`（Ventura 不存在这些服务）
> - 服务总数比 Tahoe 少约 6 个

---

## 四、Spotlight 索引精简

图形界面：系统设置 → Siri 与聚焦 → 聚焦

**取消勾选**：
- 书签与历史记录
- 字体
- 影片
- 音乐
- 邮件与信息
- 演示文稿
- 电子表格
- 联系人
- 日历
- PDF 文稿

**只保留**：
- ✅ 应用程序
- ✅ 开发者
- ✅ 文件夹
- ✅ 系统设置
- ✅ 文稿

排除大型目录（隐私标签页）：
- Ollama 模型目录
- `~/Downloads`
- `~/Movies`
- `~/Music`

---

## 五、内存与 CPU 调优（Intel 专用优化）

###bash
# 关闭突然运动传感器（SSD 不需要，Intel 时代遗留）
sudo pmset -a sms 0

# === Intel 专用：休眠模式优化 ===
# Intel Mac 支持 hibernatemode 调整，Apple Silicon 不支持
# hibernatemode 0 = 仅内存休眠（不写磁盘，省空间，唤醒更快）
# 注意：断电会丢失内存状态，仅适合常供电场景
sudo pmset -a hibernatemode 0
sudo pmset -a standby 0
# 可选：删除休眠文件释放空间（等于内存大小，16GB Mac 释放 16GB）
sudo rm -f /var/vm/sleepimage

# 关闭 App Nap（Ollama 等后台服务需要持续运行）
defaults write NSGlobalDomain NSAppSleepDisabled -bool true

# 关闭软件更新自动下载
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

# 键盘重复速度加快
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -int 10

# 关闭照片面部识别
defaults write com.apple.photoanalysisd enabled -bool false

# 关闭 iCloud 桌面与文稿同步
# 图形界面：系统设置 → Apple ID → iCloud → iCloud 云盘 → 关闭"桌面与文稿文件夹"

# 隐藏控制中心媒体播放控件
defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false
###

> **与 Tahoe 版差异**：
> - 新增 `hibernatemode 0` + `standby 0` + 删除 sleepimage（Intel 专用，Apple Silicon 不支持）
> - Intel Mac 上这三条可以**释放 16GB+ 磁盘空间** + 加速唤醒

### ulimit 配置

加到 `~/.zshrc`：
###bash
ulimit -n 65536
ulimit -u 2048
###

### Ollama 模型存储路径

加到 `~/.zshrc`：
###bash
export OLLAMA_MODELS="/path/to/large/storage/ollama/models"
###

### Xcode 清理

###bash
xcrun simctl delete unavailable
rm -rf ~/Library/Developer/Xcode/DerivedData/*
###

---

## 六、不要关闭的服务（Ventura 版）

| 服务 | 原因 |
|------|------|
| `com.apple.contactsd` | 关闭会导致 App Store 冻结 |
| `com.apple.AirPlayXPCHelper` | 关闭导致 Safari 媒体播放出错 |
| `com.apple.donotdisturbd` | 关闭导致通知中心停止工作 |
| `com.apple.iconservices.*` | 关闭导致 Finder CPU 飙升 |
| `com.apple.metadata.mds` | Spotlight 核心，Xcode 符号搜索依赖 |
| `com.apple.WindowServer` | 图形核心 |
| `com.apple.coreduetd` | 系统进程调度依赖 |

> **与 Tahoe 版差异**：Ventura 没有 `modelcatalogd` 和 `modelmanagerd`（Apple ML 基础设施是 Tahoe 新增的）

---

## 七、7x24 工作站稳定性配置

### Step A：电源管理 — 永不休眠

###bash
# ===== 接电源时 =====
sudo pmset -c sleep 0           # 系统永不休眠
sudo pmset -c disksleep 0       # 磁盘永不休眠
sudo pmset -c displaysleep 30   # 显示器 30 分钟后关闭
sudo pmset -c standby 0         # 禁用待机
sudo pmset -c powernap 0        # 禁用 Power Nap
sudo pmset -c hibernatemode 0   # 禁用休眠写入磁盘（Intel 专用）
sudo pmset -c autopoweroff 0    # 禁用自动断电（Intel 专用）

# ===== 用电池时 =====
sudo pmset -b sleep 15          # 电池模式 15 分钟休眠（设 0 会电池耗尽硬关机）
sudo pmset -b disksleep 0
sudo pmset -b displaysleep 10
sudo pmset -b standby 0
sudo pmset -b powernap 0
sudo pmset -b hibernatemode 0   # Intel 专用
sudo pmset -b autopoweroff 0    # Intel 专用

# ===== 通用 =====
sudo pmset -a autorestart 1     # 断电恢复自动开机
sudo pmset -a womp 1            # 网络唤醒（SSH 远程唤醒）
sudo pmset -c wifi 1            # 接电源时 Wi-Fi 不断
sudo pmset -b wifi 1            # 电池时 Wi-Fi 也不断
sudo systemsetup -setrestartfreeze on   # 内核崩溃自动重启
sudo pmset -a lowpowermode 0    # 关闭节能模式（CPU 不降频）
sudo pmset -a sms 0             # 关闭突然运动传感器（Intel SSD 不需要）

# Intel 专用：删除休眠文件释放空间（等于内存大小）
sudo rm -f /var/vm/sleepimage
###

### Step B：GPU 稳定性（Intel 双 GPU 机型）

###bash
# 先确认是否有双 GPU
system_profiler SPDisplaysDataType | grep "Chipset Model"

# 如果有两个 GPU，禁用自动切换（避免切换时闪屏/崩溃）
# 0 = 仅集成显卡（省电，纯代码开发够用）
# 1 = 仅独立显卡（性能，跑 AI 模型推荐）
# 2 = 自动切换（默认，可能不稳定）
sudo pmset -a gpuswitch 0    # 或 1，根据需要选择
###

> 如果只有一个 GPU，跳过此步。

### Step C：合盖不休眠

**有外接显示器**：macOS 原生 clamshell 模式，无需配置。

**纯合盖运行**：

###bash
# caffeinate LaunchAgent — 开机自动保持唤醒
cat > ~/Library/LaunchAgents/com.user.caffeinate.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.caffeinate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-dimsu</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.user.caffeinate.plist
###

或安装 **Amphetamine**（App Store 免费），设为启动时自动激活 + 合盖保持唤醒。

### Step D：防止意外中断

###bash
# 清除定时关机计划
sudo pmset schedule cancelall 2>/dev/null

# 关闭热角（防止鼠标误触触发锁屏/休眠）
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-br-corner -int 0
killall Dock

# 禁止低电量自动休眠
sudo pmset -b lowpowermode 0
###

### Step E：关闭屏保

###bash
defaults -currentHost write com.apple.screensaver idleTime 0
###

> ⚠️ 如果同时启用了"立即锁屏要求密码"（安全加固 Step 10），禁用屏保后锁屏不会自动触发。如果有物理安全需求，改为设长时间（如 `1800` = 30 分钟）而非 0。

### Step F：网络连接稳定

###bash
# SSH 连接复用 + 保活
mkdir -p ~/.ssh/sockets
cat >> ~/.ssh/config << 'SSH_EOF'

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    ConnectTimeout 10
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
SSH_EOF
###

---

## 八、系统底层调优

### Step G：文件描述符限制永久化（系统级）

`.zshrc` 中的 `ulimit` 只对终端生效。GUI 应用（Xcode、Ollama）需要系统级配置：

###bash
sudo tee /Library/LaunchDaemons/limit.maxfiles.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>limit.maxfiles</string>
    <key>ProgramArguments</key>
    <array>
        <string>launchctl</string>
        <string>limit</string>
        <string>maxfiles</string>
        <string>65536</string>
        <string>524288</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/limit.maxfiles.plist
sudo chmod 644 /Library/LaunchDaemons/limit.maxfiles.plist
###

### Step H：内核共享内存调优（Intel 专用，大模型加载）

###bash
# 查看当前值
sysctl kern.sysv.shmmax
sysctl kern.sysv.shmall

# 增大共享内存（Ollama / 向量模型加载大块数据）
sudo sysctl -w kern.sysv.shmmax=2147483648   # 2GB
sudo sysctl -w kern.sysv.shmall=524288        # 页数

# 永久化
sudo tee -a /etc/sysctl.conf << 'EOF'
kern.sysv.shmmax=2147483648
kern.sysv.shmall=524288
EOF
###

> Apple Silicon 上共享内存管理不同，通常不需要此步。**仅 Intel 适用**。

### Step I：APFS 快照清理

###bash
# 查看本地快照
tmutil listlocalsnapshots /

# 如果有快照且不用 Time Machine，清理释放空间
tmutil deletelocalsnapshots /
###

### Step J：Xcode 自动清理 DerivedData

每周日凌晨 4 点自动清理超过 7 天的编译缓存 + 无用模拟器：

###bash
cat > ~/Library/LaunchAgents/com.user.xcode-cleanup.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.xcode-cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -mtime +7 -exec rm -rf {} + 2>/dev/null; xcrun simctl delete unavailable 2>/dev/null</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
        <key>Weekday</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.user.xcode-cleanup.plist
###

---

## 八-B：Ventura Intel 版本特有优化

### Step K：Ollama 内存管理环境变量

跑大模型时限制并发，避免内存溢出：

###bash
# 加到 ~/.zshrc
export OLLAMA_MAX_LOADED_MODELS=1    # 同时只加载 1 个模型
export OLLAMA_MAX_QUEUE=512          # 最大请求队列
export OLLAMA_NUM_PARALLEL=1         # Intel Mac 建议单并发
###

> 注意：Ollama 0.19 的 MLX 加速仅支持 Apple Silicon，Intel Mac 无法使用。

### Step L：禁用 Spotlight 网络搜索

`LookupSuggestionsDisabled` 关闭了查词建议，但 Spotlight 仍可能向 Apple 发送搜索请求：

###bash
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true
###

### Step M：i9 散热优化（Intel i9 机型专用）

Intel i9 MacBook Pro 在持续高负载（Ollama 推理、Xcode 编译）下会严重降频。以下两个工具是社区公认的"i9 续命方案"：

**工具 1：Turbo Boost Switcher（关闭睿频）**

- 下载：[tbswitcher.rugarciap.com](http://tbswitcher.rugarciap.com/)（免费版即可）
- 作用：关闭 i9 的 Turbo Boost 睿频功能
- 效果：CPU 温度**暴降 10-15 度**，告别降频和风扇狂啸
- 原理：i9 的 Turbo Boost 会将单核从 2.9GHz 飙到 4.8GHz，但散热跟不上立刻降频。关闭后锁定基频（2.9GHz），温度平稳，**持续负载下总吞吐反而更高**
- 推荐设置：开发/编译/AI 推理时**关闭 Turbo Boost**，轻度使用时可打开

**工具 2：Macs Fan Control（提前散热）**

- 下载：[crystalidea.com/macs-fan-control](https://crystalidea.com/macs-fan-control)（免费版即可）
- 作用：手动控制风扇转速策略
- 效果：提前散热，防止 i9 撞击温度墙（100°C）
- 推荐设置：
  - 将风扇起转温度从苹果默认的 ~90°C 调低到 **65-70°C**
  - 或设为"基于传感器"模式，选择 CPU Proximity 传感器

**两者配合使用效果最佳**：Turbo Boost Switcher 降低热源 + Macs Fan Control 提前散热 = i9 稳定输出不降频。

> ⚠️ 仅适用于 Intel i9 MacBook Pro（2018-2020）。Apple Silicon Mac 散热管理完全不同，不需要这些工具。

---

## 八-C：工程级生产环境优化

### Step N：TCP/IP 网络栈调优

对 SSH 远程开发、Ollama API 跨机调用、Git 大仓库操作有直接收益。

###bash
# 临时生效
sudo sysctl -w net.inet.tcp.sendspace=1048576
sudo sysctl -w net.inet.tcp.recvspace=1048576
sudo sysctl -w net.inet.tcp.autorcvbufmax=33554432
sudo sysctl -w net.inet.tcp.autosndbufmax=33554432
sudo sysctl -w net.inet.tcp.mssdflt=1460
sudo sysctl -w net.inet.tcp.delayed_ack=0

# 永久化
sudo tee /Library/LaunchDaemons/com.server.sysctl.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.server.sysctl</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
sysctl -w net.inet.tcp.sendspace=1048576
sysctl -w net.inet.tcp.recvspace=1048576
sysctl -w net.inet.tcp.autorcvbufmax=33554432
sysctl -w net.inet.tcp.autosndbufmax=33554432
sysctl -w net.inet.tcp.mssdflt=1460
sysctl -w net.inet.tcp.delayed_ack=0
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/com.server.sysctl.plist
sudo chmod 644 /Library/LaunchDaemons/com.server.sysctl.plist
###

| 参数 | 默认值 | 优化值 | 作用 |
|------|:------:|:------:|------|
| `sendspace` | 131,702 | 1,048,576 | TCP 发送缓冲区 1MB |
| `recvspace` | 131,702 | 1,048,576 | TCP 接收缓冲区 1MB |
| `autorcvbufmax` | 4MB | 32MB | 自动调整上限 |
| `autosndbufmax` | 4MB | 32MB | 同上 |
| `mssdflt` | 512 | 1460 | 现代以太网 MSS |
| `delayed_ack` | 3 | 0 | 禁用延迟 ACK，SSH 更流畅 |

### Step O：`serverperfmode` 服务器性能模式（Intel 专用）

Apple 官方为 Intel Mac 提供的**服务器性能模式**，专为 24/7 高负载场景设计。

###bash
# 开启（需重启生效）
sudo nvram boot-args="serverperfmode=1 $(nvram boot-args 2>/dev/null | cut -f 2-)"

# 验证
nvram boot-args
# 预期输出包含：serverperfmode=1
###

效果：
- 增大内核内存分配限制
- 提高系统级进程和文件描述符上限
- 优化线程调度策略
- 专为 24/7 高负载设计

> ⚠️ **仅 Intel Mac 支持**，Apple Silicon 不支持。来源：[Apple Support HT202528](https://support.apple.com/en-us/HT202528)
> ⚠️ 存储在 NVRAM，重置 NVRAM 会丢失，需重新设置。
> 还原：`sudo nvram boot-args="$(nvram boot-args 2>/dev/null | cut -f 2- | sed 's/serverperfmode=1//')"`

### Step P：通知中心完全禁用

开发工作站不需要任何通知干扰：

###bash
launchctl bootout gui/501/com.apple.notificationcenterui 2>/dev/null
launchctl disable gui/501/com.apple.notificationcenterui 2>/dev/null
###

> 右上角通知中心完全消失。还原：`launchctl enable gui/501/com.apple.notificationcenterui`

### Step Q：caffeinate 升级为系统级 LaunchDaemon

开机即生效，无需用户登录：

###bash
# 移除用户级（如果之前创建过）
launchctl unload ~/Library/LaunchAgents/com.user.caffeinate.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.caffeinate.plist

# 创建系统级
sudo tee /Library/LaunchDaemons/com.server.caffeinate.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.server.caffeinate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-dimsu</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/com.server.caffeinate.plist
sudo chmod 644 /Library/LaunchDaemons/com.server.caffeinate.plist
sudo launchctl load /Library/LaunchDaemons/com.server.caffeinate.plist
###

### Step R：Intel i9 专用 — Ollama 推理优化

Intel Mac 没有 MLX 加速，Ollama 性能依赖 CPU。配合 Turbo Boost Switcher（Step M）使用：

**Ollama 线程数**（加到 `~/.zshrc`）：
###bash
# Intel i9 建议值（配合关闭 Turbo Boost 时）
export OLLAMA_NUM_PARALLEL=1         # 单并发
export OLLAMA_MAX_LOADED_MODELS=1    # 同时只加载 1 个模型
# Ollama 会自动检测 CPU 核心数设置线程，无需手动指定
###

**量化选择**（Intel 上更重要，没有 GPU 加速）：
- 首选 `Q4_K_M` — 速度和质量最佳平衡
- 8GB RAM 机器用 `Q4_K_S` — 更省内存
- 避免 `Q6_K` 和 `FP16` — Intel CPU 推理极慢且发热严重

---

## 八-D：Claude 专用网络防护（关键）

> 此配置是 Claude Code 正常工作的**核心依赖**，必须在三台机器上统一部署。
> 与 Surge 配置文档配合使用，构成 Claude 流量的三层防护。

### Step T：hosts 文件 — Claude 域名屏蔽（Surge 关闭时的最后防线）

Surge 配置中 `FINAL,DIRECT`（代理有流量限制），意味着 Surge 关闭后所有流量直连。
hosts 文件将 Claude/Anthropic 全域名指向 `0.0.0.0`，确保 Surge 关闭时 Claude 流量被阻断而非明文泄露。

###bash
# 编辑 hosts 文件
sudo nano /etc/hosts

# 在文件末尾追加以下内容（22 条规则）：
###

###
# === Claude / Anthropic 域名屏蔽 ===
# 作用：Surge 关闭时阻断 Claude 域名直连（最后防线）
# 不影响 Surge 开启时的正常使用（Surge 增强模式接管 DNS）

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
###

###bash
# 刷新 DNS 缓存使 hosts 立即生效
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
###

**验证**：
###bash
# Surge 关闭后测试（应超时或拒绝连接）
ping -c 1 api.anthropic.com
# 预期：ping: cannot resolve api.anthropic.com: Unknown host

# Surge 开启后测试（应正常解析到 Fake IP）
ping -c 1 api.anthropic.com
# 预期：PING api.anthropic.com (198.18.x.x)
###

> **重要**：Anthropic 可能随时新增域名。如果 Claude Code 连接失败且 Surge 日志显示新域名，需要同步更新 hosts 和 Surge 规则。Surge 中已配置 `DOMAIN-KEYWORD,anthropic` 和 `DOMAIN-KEYWORD,claude` 兜底。

### Step U：.zshrc 代理开关函数 + Claude Code 配置（必要）

**问题**：代理写死在 `.zshrc`，Surge 关闭时终端所有命令卡死。代理有流量限制，需要快速切换。

编辑 `~/.zshrc`，将硬编码代理替换为开关函数：

###bash
# === 代理开关函数 ===
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

# 默认开启代理（Surge 常驻运行）
proxy_on > /dev/null 2>&1
###

使用：`proxy_off` 临时关闭代理，`proxy_on` 重新开启。

**为什么 Claude Code 依赖代理环境变量**：
- Claude Code 通过 `HTTPS_PROXY` 环境变量将 API 请求路由到 Surge
- Surge 根据规则将 Claude 流量走指定代理节点（仅 VMess，不用 Hysteria2）
- 如果代理变量缺失，Claude Code 会尝试直连 → 被 hosts 阻断 → 连接失败

---

## 九、验证脚本（含新增项）

###bash
echo "=== 电源管理 ==="
pmset -g | grep -E "sleep|standby|hibernate|powernap|autopoweroff|displaysleep|womp|wifi|lowpowermode|gpuswitch"

echo ""
echo "=== 屏保 ==="
defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo "未设置"

echo ""
echo "=== 自动重启 ==="
pmset -g | grep autorestart
sudo systemsetup -getrestartfreeze

echo ""
echo "=== 热角 ==="
for corner in tl tr bl br; do
    val=$(defaults read com.apple.dock "wvous-${corner}-corner" 2>/dev/null)
    echo "  $corner: ${val:-未设置}"
done

echo ""
echo "=== caffeinate ==="
pgrep -l caffeinate && echo "  运行中" || echo "  未运行"
echo -n "  级别: "; ls /Library/LaunchDaemons/com.server.caffeinate.plist 2>/dev/null && echo "系统级" || echo "用户级或未配置"

echo ""
echo "=== 文件描述符限制 ==="
launchctl limit maxfiles

echo ""
echo "=== 共享内存 ==="
sysctl kern.sysv.shmmax kern.sysv.shmall

echo ""
echo "=== GPU 切换 ==="
pmset -g | grep gpuswitch || echo "  单 GPU 或不适用"

echo ""
echo "=== SSH 连接复用 ==="
grep -c "ControlMaster" ~/.ssh/config 2>/dev/null && echo "  已配置" || echo "  未配置"

echo ""
echo "=== 休眠文件 ==="
ls -lh /var/vm/sleepimage 2>/dev/null || echo "  已删除"

echo ""
echo "=== TCP/IP 网络栈 ==="
echo "  sendspace: $(sysctl -n net.inet.tcp.sendspace)"
echo "  recvspace: $(sysctl -n net.inet.tcp.recvspace)"
echo "  autorcvbufmax: $(sysctl -n net.inet.tcp.autorcvbufmax)"
echo "  autosndbufmax: $(sysctl -n net.inet.tcp.autosndbufmax)"
echo "  mssdflt: $(sysctl -n net.inet.tcp.mssdflt)"
echo "  delayed_ack: $(sysctl -n net.inet.tcp.delayed_ack)"

echo ""
echo "=== serverperfmode ==="
nvram boot-args 2>/dev/null | grep -q serverperfmode && echo "  已启用" || echo "  未启用"

echo ""
echo "=== 通知中心 ==="
launchctl print-disabled gui/501 2>/dev/null | grep notificationcenterui && echo "  已禁用" || echo "  运行中"

echo ""
echo "=== Ollama ==="
echo -n "  版本: "; ollama --version 2>/dev/null || echo "未安装"
echo -n "  OLLAMA_MAX_LOADED_MODELS: "; echo "${OLLAMA_MAX_LOADED_MODELS:-未设置}"
echo -n "  OLLAMA_NUM_PARALLEL: "; echo "${OLLAMA_NUM_PARALLEL:-未设置}"

echo ""
echo "=== i9 散热工具 ==="
ls /Applications/Turbo\ Boost\ Switcher.app 2>/dev/null && echo "  Turbo Boost Switcher: 已安装" || echo "  Turbo Boost Switcher: 未安装"
ls /Applications/Macs\ Fan\ Control.app 2>/dev/null && echo "  Macs Fan Control: 已安装" || echo "  Macs Fan Control: 未安装"

echo ""
echo "=== Claude 网络防护（关键）==="
HOSTS_COUNT=$(grep -c '0.0.0.0.*\(anthropic\|claude\)' /etc/hosts 2>/dev/null)
echo "  hosts Claude 域名屏蔽: ${HOSTS_COUNT} 条"
if [ "$HOSTS_COUNT" -lt 20 ]; then
  echo "  ⚠️ 警告：hosts 规则不足 20 条，Surge 关闭时 Claude 流量可能泄露！"
fi
echo -n "  代理函数: "; grep -c 'proxy_on' ~/.zshrc 2>/dev/null && echo "条匹配（已配置）" || echo "未配置"
echo -n "  HTTPS_PROXY: "; echo "${HTTPS_PROXY:-未设置}"
echo -n "  Surge 增强模式 DNS: "; scutil --dns | grep -c '198.18.0.2' 2>/dev/null && echo "已接管" || echo "未接管"
###
for corner in tl tr bl br; do
    val=$(defaults read com.apple.dock "wvous-${corner}-corner" 2>/dev/null)
    echo "  $corner: ${val:-未设置}"
done

echo ""
echo "=== caffeinate ==="
pgrep -l caffeinate && echo "  运行中" || echo "  未运行"

echo ""
echo "=== 文件描述符限制 ==="
launchctl limit maxfiles

echo ""
echo "=== 共享内存 ==="
sysctl kern.sysv.shmmax kern.sysv.shmall

echo ""
echo "=== GPU 切换 ==="
pmset -g | grep gpuswitch || echo "  单 GPU 或不适用"

echo ""
echo "=== SSH 连接复用 ==="
grep -c "ControlMaster" ~/.ssh/config 2>/dev/null && echo "  已配置" || echo "  未配置"

echo ""
echo "=== 休眠文件 ==="
ls -lh /var/vm/sleepimage 2>/dev/null || echo "  已删除"
###

---

## 十、还原方法

###bash
# 还原所有服务（删除禁用记录 + 重启）
sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.plist 2>/dev/null
sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.501.plist 2>/dev/null

# 还原电源管理（Intel）
sudo pmset -c sleep 1
sudo pmset -c displaysleep 10
sudo pmset -c standby 1
sudo pmset -c powernap 1
sudo pmset -c hibernatemode 3
sudo pmset -c autopoweroff 1
sudo pmset -b sleep 5
sudo pmset -b displaysleep 2
sudo pmset -b hibernatemode 3
sudo pmset -b autopoweroff 1
sudo pmset -a lowpowermode 1
sudo pmset -a sms 1

# 还原 GPU 切换
sudo pmset -a gpuswitch 2

# 还原屏保
defaults -currentHost write com.apple.screensaver idleTime 300

# 还原热角
defaults delete com.apple.dock wvous-tl-corner 2>/dev/null
defaults delete com.apple.dock wvous-tr-corner 2>/dev/null
defaults delete com.apple.dock wvous-bl-corner 2>/dev/null
defaults delete com.apple.dock wvous-br-corner 2>/dev/null
killall Dock

# 停止 caffeinate
launchctl unload ~/Library/LaunchAgents/com.user.caffeinate.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.caffeinate.plist

# 还原文件描述符限制
sudo rm -f /Library/LaunchDaemons/limit.maxfiles.plist

# 还原共享内存
sudo sysctl -w kern.sysv.shmmax=4194304
sudo sysctl -w kern.sysv.shmall=1024
sudo sed -i '' '/kern.sysv.shmmax/d;/kern.sysv.shmall/d' /etc/sysctl.conf 2>/dev/null

# 停止 Xcode 自动清理
launchctl unload ~/Library/LaunchAgents/com.user.xcode-cleanup.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.xcode-cleanup.plist

# 还原视觉特效
defaults delete -g NSAutomaticWindowAnimationsEnabled
defaults delete -g NSScrollAnimationEnabled
defaults delete -g NSWindowResizeTime
defaults delete -g QLPanelAnimationDuration
defaults delete -g NSScrollViewRubberbanding
defaults delete -g NSInitialToolTipDelay
defaults delete com.apple.dock autohide-delay
defaults delete com.apple.dock autohide-time-modifier
defaults delete com.apple.dock launchanim
defaults delete com.apple.dock magnification
defaults delete com.apple.dock mineffect
defaults delete com.apple.finder DisableAllAnimations
defaults delete com.apple.universalaccess reduceMotion
defaults delete com.apple.universalaccess reduceTransparency
killall Dock; killall Finder

sudo reboot
###

---

## 附录：两版本差异对照表

| 项目 | Tahoe 26.4（M4 Max 64GB） | Ventura 13.7.8（Intel i9） |
|------|:------------------------:|:--------------------------:|
| 芯片 | Apple Silicon M4 Max | Intel Core i9 |
| 内存 | 64GB 统一内存 | 16/32GB DDR4 |
| 存储 | 2TB SSD | 视配置 |
| Apple Intelligence 服务 | 有（6 个，需禁用） | 无 |
| Stage Manager 点击桌面 | 有（需关闭） | 无 |
| Liquid Glass UI | 有（`reduceBlurring` 可关） | 无 |
| `modelcatalogd/modelmanagerd` | 有（保留，ML 依赖） | 无 |
| `serverperfmode` | ❌ 不支持 | ✅ Intel 专用 |
| `hibernatemode` 调整 | ❌ 不支持（Apple Silicon） | ✅ 支持（可释放 16GB+） |
| `standby` 调整 | ❌ 不支持 | ✅ 支持 |
| `sms`（突然运动传感器） | 无意义 | 可关闭（SSD 不需要） |
| Turbo Boost Switcher | ❌ 不适用 | ✅ 强烈推荐（i9 续命） |
| Macs Fan Control | ❌ 不适用 | ✅ 推荐（提前散热） |
| Ollama MLX 加速 | ✅ 0.19+ 支持 | ❌ Intel 无 MLX |
| Ollama 可跑最大模型 | 70B（Q4_K_M，~40GB） | 7B-13B（受内存限制） |
| Ollama 并发数 | 4 并发 | 1 并发 |
| TCP/IP 网络栈调优 | ✅ 支持 | ✅ 支持 |
| `launchctl bootout/disable` | ✅ 支持 | ✅ 支持 |
| `launchctl unload -w` | ❌ 已弃用 | ⚠️ 可能生效但不推荐 |
| 需禁用服务总数 | ~85 个 | ~79 个 |
| FileVault 性能开销 | 零（硬件加速） | 轻微（Intel 无专用引擎） |
