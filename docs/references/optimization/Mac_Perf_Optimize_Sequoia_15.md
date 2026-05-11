# Mac 效能优化 — macOS Sequoia 15.7.5 版

> 适用系统：macOS Sequoia 15.7.5（Apple Silicon M4 Max，64GB 统一内存，2TB SSD）
> 定位：AI 开发 / App 开发 / 车机开发工作站
> 核心业务：Claude Code, Codex, OpenCode, Gemini Code, Xcode, Ollama, 向量模型
> 不需要：音乐、视频剪辑、游戏、社交、照片、地图、Apple TV、新闻

---

## 版本特有说明

- macOS Sequoia 15.1+ 引入了 Apple Intelligence 服务（`intelligenceflowd`、`intelligenceplatformd`），但范围比 Tahoe 小（无 `generativeexperiencesd`、`modelcatalogd`、`modelmanagerd`）
- Sequoia 15 新增了 iPhone Mirroring 功能，开发工作站不需要
- Sequoia 15 新增原生窗口平铺（Window Tiling），保留使用
- `launchctl bootout` / `launchctl disable` 是正确语法（`launchctl unload -w` 已弃用）
- SIP 保持启用，所有操作不需要关闭 SIP
- 无 Liquid Glass UI（Tahoe 26 专属），无需 `reduceBlurring`
- 无 Stage Manager 默认开启问题（Sequoia 默认关闭）
- 无 WindowServer 26.2-26.3 卡顿 bug

---

## 一、关闭所有视觉特效

```bash
#!/bin/bash
# === macOS Sequoia 15.7.5 — 关闭视觉特效 ===

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

# 焦点环动画关闭
defaults write -g NSUseAnimatedFocusRing -bool false

# 防止系统自动终止后台 App
defaults write -g NSDisableAutomaticTermination -bool true

# Dock
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock launchanim -bool false        # 关闭启动弹跳
defaults write com.apple.dock magnification -bool false      # 关闭放大效果
defaults write com.apple.dock expose-animation-duration -float 0.1  # Mission Control
defaults write com.apple.dock springboard-show-duration -float 0
defaults write com.apple.dock springboard-hide-duration -float 0
defaults write com.apple.dock springboard-page-duration -float 0
defaults write com.apple.dock mineffect -string "scale"      # 最小化用 scale 替代 genie

# Finder
defaults write com.apple.finder DisableAllAnimations -bool true

# 弹簧加载延迟清零
defaults write -g com.apple.springing.delay -float 0

# 系统级减少动态效果 + 透明度
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true

# 关闭应用打开确认弹窗动画
defaults write com.apple.LaunchServices LSQuarantine -bool false

# 网络/USB 卷不写 .DS_Store
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# 禁用 AirDrop
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true

# 使设置生效
killall Dock
killall Finder

echo "视觉特效已关闭（macOS Sequoia 15.7.5）"
```

---

## 二、Dock 精简

```bash
# 清空 Dock（之后手动拖入需要的应用）
defaults write com.apple.dock persistent-apps -array

# 自动隐藏
defaults write com.apple.dock autohide -bool true

# 最小图标
defaults write com.apple.dock tilesize -integer 36

# 不显示最近使用的应用
defaults write com.apple.dock show-recents -bool false

killall Dock

# 之后手动拖入：Terminal / Ghostty、Xcode、浏览器
```

---

## 三、关闭非必要系统服务

```bash
#!/bin/bash
# === macOS Sequoia 15.7.5 — 关闭非必要服务 ===
# 语法：launchctl bootout + disable（Sequoia 正确方式）
# 还原：launchctl enable gui/501/<服务名> 或 sudo launchctl enable system/<服务名>
# 完全还原：sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.* && 重启

echo "=== 1. Siri / Apple Intelligence（Sequoia 15.1+ 引入）==="
SIRI_AI=(
  com.apple.assistant_service com.apple.assistantd com.apple.assistant_cdmd
  com.apple.Siri.agent com.apple.siriactionsd com.apple.siriinferenced
  com.apple.sirittsd com.apple.SiriTTSTrainingAgent com.apple.siriknowledged
  com.apple.parsec-fbf com.apple.parsecd
  com.apple.intelligenceflowd com.apple.intelligencecontextd
  com.apple.intelligenceplatformd
  com.apple.knowledgeconstructiond com.apple.knowledge-agent
  com.apple.suggestd com.apple.naturallanguaged
  com.apple.proactived com.apple.milod
  com.apple.corespeechd
)
# 注意：Sequoia 无 generativeexperiencesd、modelcatalogd、modelmanagerd（Tahoe 专属）
for s in "${SIRI_AI[@]}"; do
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
  com.apple.shazamd
  com.apple.sportsd
  com.apple.homeenergyd
  com.apple.translationd
)
# 注意：shazamd / sportsd / homeenergyd / translationd 是 Sequoia 新增需禁用项
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
# 禁止 Time Machine 弹出新磁盘提示
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

echo "=== 6. 共享 / Sidecar / Handoff / 日历 / 提醒 / Apple Pay / iPhone Mirroring ==="
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
# 注意：iPhone Mirroring 通过 sharingd + rapportd 相关服务支持，上面已禁用
for s in "${MISC[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
sudo launchctl bootout system/com.apple.netbiosd 2>/dev/null
sudo launchctl disable system/com.apple.netbiosd 2>/dev/null
echo "  完成"

echo "=== 7. AMP 系列（Apple Music 守护进程）==="
AMP=(
  com.apple.AMPDeviceDiscoveryAgent com.apple.AMPDownloadAgent
  com.apple.AMPLibraryAgent com.apple.AMPArtworkAgent
  com.apple.AMPDevicesAgent com.apple.AMPSystemPlayerAgent
)
for s in "${AMP[@]}"; do
  launchctl bootout gui/501/${s} 2>/dev/null; launchctl disable gui/501/${s} 2>/dev/null
done
echo "  完成"

echo ""
echo "=== 所有服务已禁用，请重启 Mac 使更改完全生效 ==="
```

---

## 四、Spotlight 索引精简

图形界面：系统设置 → Siri 与聚焦 → 聚焦

**取消勾选**（不需要索引的类别）：
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

排除大型目录（隐私标签页 → 添加）：
- Ollama 模型目录
- `~/Downloads`
- `~/Movies`
- `~/Music`

---

## 五、内存与 CPU 调优（AI 工作负载）

```bash
# 关闭突然运动传感器（SSD 不需要）
sudo pmset -a sms 0

# 关闭 App Nap（Ollama 等后台服务需要持续运行）
defaults write NSGlobalDomain NSAppSleepDisabled -bool true

# 关闭软件更新自动下载（手动控制更新时机）
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
# 保留安全更新
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

# 键盘重复速度加快
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -int 10

# 关闭照片面部识别
defaults write com.apple.photoanalysisd enabled -bool false

# 关闭 iCloud 桌面与文稿同步（开发用 Git，不走 iCloud）
# 图形界面：系统设置 → Apple ID → iCloud → iCloud 云盘 → 关闭"桌面与文稿文件夹"

# 隐藏控制中心媒体播放控件
defaults write com.apple.controlcenter "NSStatusItem Visible NowPlaying" -bool false
```

### ulimit 配置（大模型开发必需）

加到 `~/.zshrc`：
```bash
# 文件描述符限制（大模型加载大量文件）
ulimit -n 65536
ulimit -u 2048
```

### Ollama 模型存储路径

如果有外置存储或大容量分区，加到 `~/.zshrc`：
```bash
export OLLAMA_MODELS="/path/to/large/storage/ollama/models"
```

### Xcode 清理

```bash
# 清理旧模拟器
xcrun simctl delete unavailable

# 清理派生数据
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 清理旧 iOS 设备支持文件
# Xcode → Settings → Platforms → 删除不需要的旧版本
```

---

## 六、不要关闭的服务（Sequoia 版）

| 服务 | 原因 |
|------|------|
| `com.apple.contactsd` | 关闭会导致 App Store 冻结 |
| `com.apple.AirPlayXPCHelper` | 关闭导致 Safari 媒体播放出错 |
| `com.apple.donotdisturbd` | 关闭导致通知中心停止工作 |
| `com.apple.iconservices.*` | 关闭导致 Finder CPU 飙升 |
| `com.apple.metadata.mds` | Spotlight 核心，Xcode 符号搜索依赖 |
| `com.apple.WindowServer` | 图形核心，绝对不能关 |

> **注意**：Sequoia 不包含 `modelcatalogd` 和 `modelmanagerd`（Tahoe 26 新增），无需保留。Ollama 使用自己的运行时，与 Apple 框架无关。

---

## 七、7x24 工作站稳定性配置

### Step A：电源管理 — 永不休眠

```bash
# ===== 接电源时 =====
sudo pmset -c sleep 0           # 系统永不休眠
sudo pmset -c disksleep 0       # 磁盘永不休眠
sudo pmset -c displaysleep 30   # 显示器 30 分钟后关闭（省电不影响运行）
sudo pmset -c standby 0         # 禁用待机
sudo pmset -c powernap 0        # 禁用 Power Nap
# 注意：Apple Silicon 不支持 hibernatemode 和 autopoweroff 修改，跳过

# ===== 用电池时 =====
sudo pmset -b sleep 15          # 电池模式 15 分钟休眠（设 0 会电池耗尽硬关机）
sudo pmset -b disksleep 0
sudo pmset -b displaysleep 10
sudo pmset -b standby 0
sudo pmset -b powernap 0

# ===== 通用 =====
sudo pmset -a autorestart 1     # 断电恢复自动开机
sudo pmset -a womp 1            # 网络唤醒（SSH 远程唤醒）
sudo pmset -c wifi 1            # 接电源时 Wi-Fi 不断
sudo pmset -b wifi 1            # 电池时 Wi-Fi 也不断
sudo systemsetup -setrestartfreeze on   # 内核崩溃自动重启
sudo pmset -a lowpowermode 0    # 关闭节能模式（CPU 不降频）
```

### Step B：合盖不休眠

**有外接显示器**：macOS 原生 clamshell 模式，无需配置。

**纯合盖运行**：

```bash
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
```

或安装 **Amphetamine**（App Store 免费），设为启动时自动激活 + 合盖保持唤醒。

### Step C：防止意外中断

```bash
# 清除定时关机计划
sudo pmset schedule cancelall 2>/dev/null

# 关闭热角（防止鼠标误触触发锁屏/休眠）
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-br-corner -int 0
killall Dock
```

### Step D：关闭屏保

```bash
defaults -currentHost write com.apple.screensaver idleTime 0
```

> 如果同时启用了"立即锁屏要求密码"（安全加固），禁用屏保后锁屏不会自动触发。如果有物理安全需求，改为设长时间（如 `1800` = 30 分钟）而非 0。

### Step E：网络连接稳定

```bash
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
```

---

## 八、系统底层调优

### Step F：文件描述符限制永久化（系统级）

`.zshrc` 中的 `ulimit` 只对终端生效。GUI 应用（Xcode、Ollama）需要系统级配置：

```bash
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
```

重启后所有应用（包括 Xcode、Ollama）都能打开大量文件。

### Step G：APFS 快照清理

```bash
# 查看本地快照
tmutil listlocalsnapshots /

# 如果有快照且不用 Time Machine，清理释放空间
tmutil deletelocalsnapshots /
```

### Step H：Xcode 自动清理 DerivedData

每周日凌晨 4 点自动清理超过 7 天的编译缓存 + 无用模拟器：

```bash
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
```

---

## 八-B：Sequoia 版本特有优化

### Step K：Ollama 升级到 0.19+（MLX 加速，Apple Silicon 专用）

Ollama 0.19 版本支持 Apple MLX 框架，Apple Silicon 上性能大幅提升：
- 预填充速度提升 **1.6 倍**
- 生成速度提升 **近 2 倍**
- 更智能的内存管理

```bash
# 检查当前版本
ollama --version

# 升级
brew upgrade ollama
# 或从 ollama.com 下载最新版
```

### Step L：Ollama 内存管理环境变量

跑大模型时限制并发，避免内存溢出：

```bash
# 加到 ~/.zshrc
export OLLAMA_MAX_LOADED_MODELS=1    # 同时只加载 1 个模型
export OLLAMA_MAX_QUEUE=512          # 最大请求队列
export OLLAMA_NUM_PARALLEL=4         # M4 Max 64GB 可设 4 并发
```

### Step M：禁用 Spotlight 网络搜索

```bash
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true
```

---

## 八-C：工程级生产环境优化

### Step N：TCP/IP 网络栈调优

对 SSH 远程开发、Ollama API 跨机调用、Git 大仓库操作有直接收益。

```bash
# 临时生效（重启后失效）
sudo sysctl -w net.inet.tcp.sendspace=1048576
sudo sysctl -w net.inet.tcp.recvspace=1048576
sudo sysctl -w net.inet.tcp.autorcvbufmax=33554432
sudo sysctl -w net.inet.tcp.autosndbufmax=33554432
sudo sysctl -w net.inet.tcp.mssdflt=1460
sudo sysctl -w net.inet.tcp.delayed_ack=0

# Sequoia 新增网络调优参数（Tahoe 文档缺失）
sudo sysctl -w kern.ipc.maxsockbuf=16777216
sudo sysctl -w net.inet.tcp.win_scale_factor=8
sudo sysctl -w net.inet.tcp.slowstart_flightsize=20
sudo sysctl -w net.inet.tcp.local_slowstart_flightsize=20
sudo sysctl -w net.inet.tcp.sack=1
sudo sysctl -w net.inet.tcp.always_keepalive=1
sudo sysctl -w net.inet.tcp.msl=5000
sudo sysctl -w net.inet.tcp.blackhole=2
sudo sysctl -w net.inet.udp.blackhole=1

# 永久化：创建 LaunchDaemon 在开机时应用
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
sysctl -w kern.ipc.maxsockbuf=16777216
sysctl -w net.inet.tcp.win_scale_factor=8
sysctl -w net.inet.tcp.slowstart_flightsize=20
sysctl -w net.inet.tcp.local_slowstart_flightsize=20
sysctl -w net.inet.tcp.sack=1
sysctl -w net.inet.tcp.always_keepalive=1
sysctl -w net.inet.tcp.msl=5000
sysctl -w net.inet.tcp.blackhole=2
sysctl -w net.inet.udp.blackhole=1
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/com.server.sysctl.plist
sudo chmod 644 /Library/LaunchDaemons/com.server.sysctl.plist
```

| 参数 | 默认值 | 优化值 | 作用 |
|------|:------:|:------:|------|
| `sendspace` | 131,702 | 1,048,576 | TCP 发送缓冲区 1MB |
| `recvspace` | 131,702 | 1,048,576 | TCP 接收缓冲区 1MB |
| `autorcvbufmax` | 4MB | 32MB | 自动调整上限 |
| `autosndbufmax` | 4MB | 32MB | 同上 |
| `mssdflt` | 512 | 1460 | 现代以太网 MSS |
| `delayed_ack` | 3 | 0 | 禁用延迟 ACK，SSH 更流畅 |
| `maxsockbuf` | 8MB | 16MB | Socket 缓冲区上限 |
| `win_scale_factor` | 4 | 8 | RFC 7323 窗口缩放因子 |
| `slowstart_flightsize` | 4 | 20 | 慢启动初始拥塞窗口 |
| `sack` | 1 | 1 | 选择性确认（保持启用） |
| `always_keepalive` | 0 | 1 | TCP 保活探测 |
| `msl` | 15000 | 5000 | 最大段生命周期（ms），加速 TIME_WAIT 回收 |
| `tcp.blackhole` | 0 | 2 | 丢弃到关闭端口的 TCP（安全加固） |
| `udp.blackhole` | 0 | 1 | 丢弃到关闭端口的 UDP（安全加固） |

> 来源：[ESnet Host Tuning](https://fasterdata.es.net/host-tuning/macos/) + [macos-sequoia-optimisation](https://github.com/hodorogandrei/macos-sequoia-optimisation)

### Step O：M4 Max 本地大模型热管理与性能优化

M4 Max 拥有 64GB 统一内存和 40 核 GPU，是本地跑大模型的顶级配置。

**64GB 统一内存的优势**：
- 可加载 70B 参数模型（Q4_K_M 量化约 40GB）
- 可同时加载 2 个 7B-13B 模型
- GPU 和 CPU 共享同一内存池，无需数据拷贝

**线程数配置**（加到 `~/.zshrc` 或 Ollama 启动参数）：

| M4 Max 型号 | 推荐线程数 | 说明 |
|-------------|:---------:|------|
| M4 Max（14 核 CPU） | `-t 10` | 10 性能核心全用，4 能效核心留给系统 |

**量化选择**（64GB 内存下选择更宽松）：

| 量化格式 | 推荐度 | 内存占用（7B） | 内存占用（70B） |
|---------|:------:|:-------------:|:--------------:|
| Q4_K_M | 首选 | ~4GB | ~40GB |
| Q5_K_M | 可用 | ~5GB | ~48GB |
| Q6_K | 70B 可能紧张 | ~6GB | ~55GB |
| Q8_0 | 仅 7B-13B | ~7GB | 超 64GB |
| FP16 | 仅小模型 | ~14GB | 超 64GB |

**物理散热**：
- M4 Max MacBook Pro 有双风扇主动散热，散热能力强
- 持续满载仍建议放在硬质表面，合盖竖立放置
- AC 供电 + 电池限充 80%（系统设置 → 电池 → 电池健康 → 优化电池充电）
- 64GB 机器跑大模型时温度通常稳定在 70-80°C

**温度监控**：
```bash
sudo powermetrics --samplers smc,cpu_power,gpu_power --show-all --interval 2000
```

> M4 Max 温度墙约 105°C，正常负载下不应超过 85°C。如果持续超过 90°C 说明散热有问题。

### Step P：Metal GPU 全量卸载验证

M4 Max 拥有 40 核 GPU，必须确保 Ollama/llama.cpp 将所有模型层卸载到 GPU：

```bash
# 加到 ~/.zshrc，确保 Ollama 使用全部 GPU 层
export OLLAMA_GPU_LAYERS=99
```

验证 Metal 是否生效：
```bash
ollama run llama3:8b --verbose 2>&1 | grep -i metal
# 预期输出应包含 "Metal" 和 "using XX/64 GB of device memory"
# 如果看到 "CPU only" 说明 Metal 没生效，检查 Xcode Command Line Tools：
xcode-select --install
```

### Step Q：内存带宽争抢注意事项

M4 Max 有 546 GB/s 内存带宽，Ollama 推理性能**直接受内存带宽限制**。

**关键规则**：
- `OLLAMA_MAX_LOADED_MODELS=2` 是 64GB 的实用上限
- Ollama 推理 + Xcode 编译**不要同时跑** — Xcode linker 阶段吃大量内存带宽
- 建议错峰：编译时暂停推理，推理时不触发编译

**监控内存带宽压力**：
```bash
memory_pressure
# 预期：System-wide memory free percentage: 30%+
# 如果低于 15%，说明内存带宽已饱和

sudo powermetrics --samplers memory --interval 2000
```

### Step R：通知中心完全禁用

开发工作站不需要任何通知干扰：

```bash
launchctl bootout gui/501/com.apple.notificationcenterui 2>/dev/null
launchctl disable gui/501/com.apple.notificationcenterui 2>/dev/null
```

> 右上角通知中心完全消失。还原：`launchctl enable gui/501/com.apple.notificationcenterui`

### Step S：caffeinate 升级为系统级 LaunchDaemon

当前 caffeinate 在 `~/Library/LaunchAgents/`（用户级），需要用户登录才生效。升级为系统级：

```bash
# 如果之前创建了用户级的，先移除
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
```

---

## 八-D：Claude 专用网络防护（关键）

> 此配置是 Claude Code 正常工作的**核心依赖**，必须在三台机器上统一部署。
> 与 Surge 配置文档配合使用，构成 Claude 流量的三层防护。

### Step T：hosts 文件 — Claude 域名屏蔽（Surge 关闭时的最后防线）

Surge 配置中 `FINAL,DIRECT`（代理有流量限制），意味着 Surge 关闭后所有流量直连。
hosts 文件将 Claude/Anthropic 全域名指向 `0.0.0.0`，确保 Surge 关闭时 Claude 流量被阻断而非明文泄露。

```bash
# 编辑 hosts 文件
sudo nano /etc/hosts

# 在文件末尾追加以下内容（22 条规则）：
```

```
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
```

```bash
# 刷新 DNS 缓存使 hosts 立即生效
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

**验证**：
```bash
# Surge 关闭后测试（应超时或拒绝连接）
ping -c 1 api.anthropic.com
# 预期：ping: cannot resolve api.anthropic.com: Unknown host

# Surge 开启后测试（应正常解析到 Fake IP）
ping -c 1 api.anthropic.com
# 预期：PING api.anthropic.com (198.18.x.x)
```

> **重要**：Anthropic 可能随时新增域名。如果 Claude Code 连接失败且 Surge 日志显示新域名，需要同步更新 hosts 和 Surge 规则。Surge 中已配置 `DOMAIN-KEYWORD,anthropic` 和 `DOMAIN-KEYWORD,claude` 兜底。

### Step U：.zshrc 代理开关函数 + Claude Code 配置（必要）

**问题**：代理写死在 `.zshrc`，Surge 关闭时终端所有命令卡死。代理有流量限制，需要快速切换。

编辑 `~/.zshrc`，将硬编码代理替换为开关函数：

```bash
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
```

使用：`proxy_off` 临时关闭代理，`proxy_on` 重新开启。

**为什么 Claude Code 依赖代理环境变量**：
- Claude Code 通过 `HTTPS_PROXY` 环境变量将 API 请求路由到 Surge
- Surge 根据规则将 Claude 流量走指定代理节点（仅 VMess，不用 Hysteria2）
- 如果代理变量缺失，Claude Code 会尝试直连 → 被 hosts 阻断 → 连接失败

---

## 九、验证脚本

```bash
#!/bin/bash
# === macOS Sequoia 15.7.5 — 优化验证 ===

echo "=== 电源管理 ==="
pmset -g | grep -E "sleep|standby|hibernate|powernap|autopoweroff|displaysleep|womp|wifi|lowpowermode"

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
echo "=== SSH 连接复用 ==="
grep -c "ControlMaster" ~/.ssh/config 2>/dev/null && echo "  已配置" || echo "  未配置"

echo ""
echo "=== TCP/IP 网络栈 ==="
echo "  sendspace: $(sysctl -n net.inet.tcp.sendspace)"
echo "  recvspace: $(sysctl -n net.inet.tcp.recvspace)"
echo "  autorcvbufmax: $(sysctl -n net.inet.tcp.autorcvbufmax)"
echo "  autosndbufmax: $(sysctl -n net.inet.tcp.autosndbufmax)"
echo "  mssdflt: $(sysctl -n net.inet.tcp.mssdflt)"
echo "  delayed_ack: $(sysctl -n net.inet.tcp.delayed_ack)"

echo ""
echo "=== Sequoia 新增网络参数 ==="
echo "  maxsockbuf: $(sysctl -n kern.ipc.maxsockbuf)"
echo "  win_scale_factor: $(sysctl -n net.inet.tcp.win_scale_factor)"
echo "  slowstart_flightsize: $(sysctl -n net.inet.tcp.slowstart_flightsize)"
echo "  sack: $(sysctl -n net.inet.tcp.sack)"
echo "  always_keepalive: $(sysctl -n net.inet.tcp.always_keepalive)"
echo "  msl: $(sysctl -n net.inet.tcp.msl)"
echo "  tcp.blackhole: $(sysctl -n net.inet.tcp.blackhole)"
echo "  udp.blackhole: $(sysctl -n net.inet.udp.blackhole)"

echo ""
echo "=== 通知中心 ==="
launchctl print-disabled gui/501 2>/dev/null | grep notificationcenterui && echo "  已禁用" || echo "  运行中"

echo ""
echo "=== Ollama ==="
echo -n "  版本: "; ollama --version 2>/dev/null || echo "未安装"
echo -n "  OLLAMA_MAX_LOADED_MODELS: "; echo "${OLLAMA_MAX_LOADED_MODELS:-未设置}"
echo -n "  OLLAMA_NUM_PARALLEL: "; echo "${OLLAMA_NUM_PARALLEL:-未设置}"
echo -n "  OLLAMA_GPU_LAYERS: "; echo "${OLLAMA_GPU_LAYERS:-未设置}"

echo ""
echo "=== Sequoia 新增 defaults ==="
echo -n "  NSUseAnimatedFocusRing: "; defaults read -g NSUseAnimatedFocusRing 2>/dev/null || echo "未设置"
echo -n "  NSDisableAutomaticTermination: "; defaults read -g NSDisableAutomaticTermination 2>/dev/null || echo "未设置"
echo -n "  DSDontWriteNetworkStores: "; defaults read com.apple.desktopservices DSDontWriteNetworkStores 2>/dev/null || echo "未设置"
echo -n "  DSDontWriteUSBStores: "; defaults read com.apple.desktopservices DSDontWriteUSBStores 2>/dev/null || echo "未设置"
echo -n "  DisableAirDrop: "; defaults read com.apple.NetworkBrowser DisableAirDrop 2>/dev/null || echo "未设置"

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
```

---

## 十、还原方法

```bash
#!/bin/bash
# === macOS Sequoia 15.7.5 — 还原所有优化 ===

# 还原所有服务（删除禁用记录 + 重启）
sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.plist 2>/dev/null
sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.501.plist 2>/dev/null

# 还原电源管理
sudo pmset -c sleep 1
sudo pmset -c displaysleep 10
sudo pmset -c standby 1
sudo pmset -c powernap 1
sudo pmset -b sleep 5
sudo pmset -b displaysleep 2
sudo pmset -a lowpowermode 1

# 还原屏保
defaults -currentHost write com.apple.screensaver idleTime 300

# 还原热角
defaults delete com.apple.dock wvous-tl-corner 2>/dev/null
defaults delete com.apple.dock wvous-tr-corner 2>/dev/null
defaults delete com.apple.dock wvous-bl-corner 2>/dev/null
defaults delete com.apple.dock wvous-br-corner 2>/dev/null
killall Dock

# 停止 caffeinate
sudo launchctl unload /Library/LaunchDaemons/com.server.caffeinate.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.server.caffeinate.plist
launchctl unload ~/Library/LaunchAgents/com.user.caffeinate.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.caffeinate.plist

# 还原文件描述符限制
sudo rm -f /Library/LaunchDaemons/limit.maxfiles.plist

# 停止 Xcode 自动清理
launchctl unload ~/Library/LaunchAgents/com.user.xcode-cleanup.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.xcode-cleanup.plist

# 还原网络调优
sudo rm -f /Library/LaunchDaemons/com.server.sysctl.plist

# 还原视觉特效
defaults delete -g NSAutomaticWindowAnimationsEnabled
defaults delete -g NSScrollAnimationEnabled
defaults delete -g NSWindowResizeTime
defaults delete -g QLPanelAnimationDuration
defaults delete -g NSScrollViewRubberbanding
defaults delete -g NSInitialToolTipDelay
defaults delete -g NSUseAnimatedFocusRing
defaults delete -g NSDisableAutomaticTermination
defaults delete com.apple.dock autohide-delay
defaults delete com.apple.dock autohide-time-modifier
defaults delete com.apple.dock launchanim
defaults delete com.apple.dock magnification
defaults delete com.apple.dock mineffect
defaults delete com.apple.finder DisableAllAnimations
defaults delete com.apple.universalaccess reduceMotion
defaults delete com.apple.universalaccess reduceTransparency
defaults delete com.apple.desktopservices DSDontWriteNetworkStores
defaults delete com.apple.desktopservices DSDontWriteUSBStores
defaults delete com.apple.NetworkBrowser DisableAirDrop
killall Dock; killall Finder

# 还原通知中心
launchctl enable gui/501/com.apple.notificationcenterui

sudo reboot
```
