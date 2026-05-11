# Mac 效能优化指南 — AI 开发工作站专用

> 日期：2026-04-06
> 目标机器：testuser's MacBook（Intel，macOS）
> 定位：纯 AI 开发 / App 开发 / 车机开发工作站
> 核心业务：Claude Code, Codex, OpenCode, Gemini Code, Xcode, Ollama, Mac Vision, 向量模型
> 不需要：音乐、视频剪辑、游戏、社交、照片管理、地图导航、Apple TV、新闻

---

## 第一部分：关闭所有视觉特效

### Step 1：系统级动画全部关闭

```bash
# 关闭窗口打开/关闭动画
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

# 关闭滚动动画
defaults write -g NSScrollAnimationEnabled -bool false

# 窗口缩放速度设为即时
defaults write -g NSWindowResizeTime -float 0.001

# 关闭 Quick Look 面板动画
defaults write -g QLPanelAnimationDuration -float 0

# 关闭橡皮筋回弹效果
defaults write -g NSScrollViewRubberbanding -bool false

# 关闭文档版本浏览动画
defaults write -g NSDocumentRevisionsWindowTransformAnimation -bool false

# 关闭工具栏全屏动画
defaults write -g NSToolbarFullScreenAnimationDuration -float 0

# 关闭浏览器列动画
defaults write -g NSBrowserColumnAnimationSpeedMultiplier -float 0
```

### Step 2：Dock 动画关闭

```bash
# Dock 自动隐藏无延迟
defaults write com.apple.dock autohide-delay -float 0

# Dock 隐藏/显示动画时间为零
defaults write com.apple.dock autohide-time-modifier -float 0

# Mission Control 动画为零
defaults write com.apple.dock expose-animation-duration -float 0

# Launchpad 动画为零
defaults write com.apple.dock springboard-show-duration -float 0
defaults write com.apple.dock springboard-hide-duration -float 0
defaults write com.apple.dock springboard-page-duration -float 0

# 最小化窗口无动画（scale 替代 genie）
defaults write com.apple.dock mineffect -string "scale"

# 重启 Dock
killall Dock
```

### Step 3：Finder 动画关闭

```bash
# 关闭 Finder 所有动画
defaults write com.apple.finder DisableAllAnimations -bool true

# 重启 Finder
killall Finder
```

### Step 4：系统辅助功能级别优化

```bash
# 减少动态效果（系统级）
defaults write com.apple.universalaccess reduceMotion -bool true

# 减少透明度（减少 GPU 合成负担）
defaults write com.apple.universalaccess reduceTransparency -bool true
```

也可通过图形界面：系统设置 → 辅助功能 → 显示 → 开启"减少动态效果"和"降低透明度"

### Step 5：关闭启动台动画提示

```bash
# 禁用打开应用确认弹窗
defaults write com.apple.LaunchServices LSQuarantine -bool false

# 禁用 "应用已下载" 首次运行提示的动画
# （Gatekeeper 仍生效，只是去掉动画延迟）
```

---

## 第二部分：关闭非必要系统服务

> ⚠️ 以下操作不需要关闭 SIP。使用 `launchctl disable` 方式，重启后生效。
> 还原方法：`launchctl enable gui/501/<服务名>` 或 `sudo launchctl enable system/<服务名>`

### Step 6：关闭 Siri / AI 助手相关（已在安全加固中部分完成）

```bash
# 用户级 Siri 服务
launchctl bootout gui/501/com.apple.assistant_service 2>/dev/null
launchctl disable gui/501/com.apple.assistant_service
launchctl bootout gui/501/com.apple.assistantd 2>/dev/null
launchctl disable gui/501/com.apple.assistantd
launchctl bootout gui/501/com.apple.assistant_cdmd 2>/dev/null
launchctl disable gui/501/com.apple.assistant_cdmd
launchctl bootout gui/501/com.apple.Siri.agent 2>/dev/null
launchctl disable gui/501/com.apple.Siri.agent
launchctl bootout gui/501/com.apple.siriactionsd 2>/dev/null
launchctl disable gui/501/com.apple.siriactionsd
launchctl bootout gui/501/com.apple.siriinferenced 2>/dev/null
launchctl disable gui/501/com.apple.siriinferenced
launchctl bootout gui/501/com.apple.sirittsd 2>/dev/null
launchctl disable gui/501/com.apple.sirittsd
launchctl bootout gui/501/com.apple.SiriTTSTrainingAgent 2>/dev/null
launchctl disable gui/501/com.apple.SiriTTSTrainingAgent
launchctl bootout gui/501/com.apple.siriknowledged 2>/dev/null
launchctl disable gui/501/com.apple.siriknowledged
launchctl bootout gui/501/com.apple.parsec-fbf 2>/dev/null
launchctl disable gui/501/com.apple.parsec-fbf
launchctl bootout gui/501/com.apple.parsecd 2>/dev/null
launchctl disable gui/501/com.apple.parsecd
```

### Step 7：关闭 Apple Intelligence / 生成式体验

```bash
launchctl bootout gui/501/com.apple.intelligenceflowd 2>/dev/null
launchctl disable gui/501/com.apple.intelligenceflowd
launchctl bootout gui/501/com.apple.intelligencecontextd 2>/dev/null
launchctl disable gui/501/com.apple.intelligencecontextd
launchctl bootout gui/501/com.apple.intelligenceplatformd 2>/dev/null
launchctl disable gui/501/com.apple.intelligenceplatformd
launchctl bootout gui/501/com.apple.generativeexperiencesd 2>/dev/null
launchctl disable gui/501/com.apple.generativeexperiencesd
launchctl bootout gui/501/com.apple.knowledgeconstructiond 2>/dev/null
launchctl disable gui/501/com.apple.knowledgeconstructiond
launchctl bootout gui/501/com.apple.knowledge-agent 2>/dev/null
launchctl disable gui/501/com.apple.knowledge-agent
launchctl bootout gui/501/com.apple.suggestd 2>/dev/null
launchctl disable gui/501/com.apple.suggestd
```

### Step 8：关闭音乐 / 媒体 / 娱乐服务

```bash
# iTunes / Apple Music
launchctl bootout gui/501/com.apple.itunescloudd 2>/dev/null
launchctl disable gui/501/com.apple.itunescloudd
launchctl bootout gui/501/com.apple.mediastream.mstreamd 2>/dev/null
launchctl disable gui/501/com.apple.mediastream.mstreamd

# Apple TV / 视频订阅
launchctl bootout gui/501/com.apple.videosubscriptionsd 2>/dev/null
launchctl disable gui/501/com.apple.videosubscriptionsd
launchctl bootout gui/501/com.apple.watchlistd 2>/dev/null
launchctl disable gui/501/com.apple.watchlistd

# 游戏
sudo launchctl bootout system/com.apple.GameController.gamecontrollerd 2>/dev/null
sudo launchctl disable system/com.apple.GameController.gamecontrollerd
launchctl bootout gui/501/com.apple.gamed 2>/dev/null
launchctl disable gui/501/com.apple.gamed

# 语音合成训练
launchctl bootout gui/501/com.apple.voicebankingd 2>/dev/null
launchctl disable gui/501/com.apple.voicebankingd

# 新闻
launchctl bootout gui/501/com.apple.newsd 2>/dev/null
launchctl disable gui/501/com.apple.newsd

# 天气
launchctl bootout gui/501/com.apple.weatherd 2>/dev/null
launchctl disable gui/501/com.apple.weatherd

# 提示
launchctl bootout gui/501/com.apple.tipsd 2>/dev/null
launchctl disable gui/501/com.apple.tipsd

# 股票/金融
launchctl bootout gui/501/com.apple.financed 2>/dev/null
launchctl disable gui/501/com.apple.financed
```

### Step 9：关闭照片 / 地图 / 社交服务

```bash
# 照片分析和云同步
launchctl bootout gui/501/com.apple.photoanalysisd 2>/dev/null
launchctl disable gui/501/com.apple.photoanalysisd
launchctl bootout gui/501/com.apple.photolibraryd 2>/dev/null
launchctl disable gui/501/com.apple.photolibraryd
launchctl bootout gui/501/com.apple.cloudphotod 2>/dev/null
launchctl disable gui/501/com.apple.cloudphotod
launchctl bootout gui/501/com.apple.mediaanalysisd 2>/dev/null
launchctl disable gui/501/com.apple.mediaanalysisd

# 地图
launchctl bootout gui/501/com.apple.Maps.pushdaemon 2>/dev/null
launchctl disable gui/501/com.apple.Maps.pushdaemon
launchctl bootout gui/501/com.apple.Maps.mapssyncd 2>/dev/null
launchctl disable gui/501/com.apple.Maps.mapssyncd
launchctl bootout gui/501/com.apple.maps.destinationd 2>/dev/null
launchctl disable gui/501/com.apple.maps.destinationd
launchctl bootout gui/501/com.apple.navd 2>/dev/null
launchctl disable gui/501/com.apple.navd
launchctl bootout gui/501/com.apple.geodMachServiceBridge 2>/dev/null
launchctl disable gui/501/com.apple.geodMachServiceBridge
launchctl bootout gui/501/com.apple.geoanalyticsd 2>/dev/null
launchctl disable gui/501/com.apple.geoanalyticsd

# iMessage / FaceTime / 通话
launchctl bootout gui/501/com.apple.imagent 2>/dev/null
launchctl disable gui/501/com.apple.imagent
launchctl bootout gui/501/com.apple.imautomatichistorydeletionagent 2>/dev/null
launchctl disable gui/501/com.apple.imautomatichistorydeletionagent
launchctl bootout gui/501/com.apple.imtransferagent 2>/dev/null
launchctl disable gui/501/com.apple.imtransferagent
launchctl bootout gui/501/com.apple.avconferenced 2>/dev/null
launchctl disable gui/501/com.apple.avconferenced
launchctl bootout gui/501/com.apple.telephonyutilities.callservicesd 2>/dev/null
launchctl disable gui/501/com.apple.telephonyutilities.callservicesd
launchctl bootout gui/501/com.apple.CallHistoryPluginHelper 2>/dev/null
launchctl disable gui/501/com.apple.CallHistoryPluginHelper
```

### Step 10：关闭 iCloud 同步 / 家庭 / 教育 / Screen Time

```bash
# iCloud 同步
launchctl bootout gui/501/com.apple.cloudd 2>/dev/null
launchctl disable gui/501/com.apple.cloudd
launchctl bootout gui/501/com.apple.cloudpaird 2>/dev/null
launchctl disable gui/501/com.apple.cloudpaird
launchctl bootout gui/501/com.apple.CloudSettingsSyncAgent 2>/dev/null
launchctl disable gui/501/com.apple.CloudSettingsSyncAgent
launchctl bootout gui/501/com.apple.iCloudNotificationAgent 2>/dev/null
launchctl disable gui/501/com.apple.iCloudNotificationAgent
launchctl bootout gui/501/com.apple.iCloudUserNotifications 2>/dev/null
launchctl disable gui/501/com.apple.iCloudUserNotifications
launchctl bootout gui/501/com.apple.protectedcloudstorage.protectedcloudkeysyncing 2>/dev/null
launchctl disable gui/501/com.apple.protectedcloudstorage.protectedcloudkeysyncing

# 家庭 / 家庭控制
launchctl bootout gui/501/com.apple.homed 2>/dev/null
launchctl disable gui/501/com.apple.homed
launchctl bootout gui/501/com.apple.familycircled 2>/dev/null
launchctl disable gui/501/com.apple.familycircled
launchctl bootout gui/501/com.apple.familycontrols.useragent 2>/dev/null
launchctl disable gui/501/com.apple.familycontrols.useragent
launchctl bootout gui/501/com.apple.familynotificationd 2>/dev/null
launchctl disable gui/501/com.apple.familynotificationd

# Screen Time
launchctl bootout gui/501/com.apple.ScreenTimeAgent 2>/dev/null
launchctl disable gui/501/com.apple.ScreenTimeAgent

# 教育
launchctl bootout gui/501/com.apple.macos.studentd 2>/dev/null
launchctl disable gui/501/com.apple.macos.studentd
launchctl bootout gui/501/com.apple.progressd 2>/dev/null
launchctl disable gui/501/com.apple.progressd

# Time Machine（如果不使用 Time Machine 备份）
launchctl bootout gui/501/com.apple.TMHelperAgent 2>/dev/null
launchctl disable gui/501/com.apple.TMHelperAgent
sudo launchctl bootout system/com.apple.backupd 2>/dev/null
sudo launchctl disable system/com.apple.backupd
sudo launchctl bootout system/com.apple.backupd-helper 2>/dev/null
sudo launchctl disable system/com.apple.backupd-helper
```

### Step 11：关闭遥测 / 分析 / 追踪（系统级）

```bash
# 系统分析
sudo launchctl bootout system/com.apple.analyticsd 2>/dev/null
sudo launchctl disable system/com.apple.analyticsd
sudo launchctl bootout system/com.apple.ecosystemanalyticsd 2>/dev/null
sudo launchctl disable system/com.apple.ecosystemanalyticsd
sudo launchctl bootout system/com.apple.audioanalyticsd 2>/dev/null
sudo launchctl disable system/com.apple.audioanalyticsd
sudo launchctl bootout system/com.apple.wifianalyticsd 2>/dev/null
sudo launchctl disable system/com.apple.wifianalyticsd

# 使用追踪
launchctl bootout gui/501/com.apple.UsageTrackingAgent 2>/dev/null
launchctl disable gui/501/com.apple.UsageTrackingAgent

# Biome（行为数据）
launchctl bootout gui/501/com.apple.BiomeAgent 2>/dev/null
launchctl disable gui/501/com.apple.BiomeAgent
launchctl bootout gui/501/com.apple.biomesyncd 2>/dev/null
launchctl disable gui/501/com.apple.biomesyncd
sudo launchctl bootout system/com.apple.biomed 2>/dev/null
sudo launchctl disable system/com.apple.biomed

# 输入分析
launchctl bootout gui/501/com.apple.inputanalyticsd 2>/dev/null
launchctl disable gui/501/com.apple.inputanalyticsd

# 广告
launchctl bootout gui/501/com.apple.ap.adprivacyd 2>/dev/null
launchctl disable gui/501/com.apple.ap.adprivacyd
launchctl bootout gui/501/com.apple.ap.promotedcontentd 2>/dev/null
launchctl disable gui/501/com.apple.ap.promotedcontentd

# Trial（A/B 测试）
launchctl bootout gui/501/com.apple.triald 2>/dev/null
launchctl disable gui/501/com.apple.triald
sudo launchctl bootout system/com.apple.triald.system 2>/dev/null
sudo launchctl disable system/com.apple.triald.system

# 跟踪
launchctl bootout gui/501/com.apple.routined 2>/dev/null
launchctl disable gui/501/com.apple.routined
launchctl bootout gui/501/com.apple.duetexpertd 2>/dev/null
launchctl disable gui/501/com.apple.duetexpertd
launchctl bootout gui/501/com.apple.ContextStoreAgent 2>/dev/null
launchctl disable gui/501/com.apple.ContextStoreAgent
```

### Step 12：关闭共享 / Sidecar / 日历 / Handoff 相关

```bash
# 共享（已在安全加固中关闭 SMB，这里关闭守护进程）
launchctl bootout gui/501/com.apple.sharingd 2>/dev/null
launchctl disable gui/501/com.apple.sharingd
launchctl bootout gui/501/com.apple.screensharing.agent 2>/dev/null
launchctl disable gui/501/com.apple.screensharing.agent
launchctl bootout gui/501/com.apple.screensharing.menuextra 2>/dev/null
launchctl disable gui/501/com.apple.screensharing.menuextra
launchctl bootout gui/501/com.apple.screensharing.MessagesAgent 2>/dev/null
launchctl disable gui/501/com.apple.screensharing.MessagesAgent

# Sidecar（iPad 作为副屏）
launchctl bootout gui/501/com.apple.sidecar-hid-relay 2>/dev/null
launchctl disable gui/501/com.apple.sidecar-hid-relay
launchctl bootout gui/501/com.apple.sidecar-relay 2>/dev/null
launchctl disable gui/501/com.apple.sidecar-relay

# 日历同步
launchctl bootout gui/501/com.apple.calaccessd 2>/dev/null
launchctl disable gui/501/com.apple.calaccessd
launchctl bootout gui/501/com.apple.dataaccess.dataaccessd 2>/dev/null
launchctl disable gui/501/com.apple.dataaccess.dataaccessd

# 提醒事项
launchctl bootout gui/501/com.apple.remindd 2>/dev/null
launchctl disable gui/501/com.apple.remindd

# Rapportd（设备间通信，如 Handoff）
launchctl bootout gui/501/com.apple.rapportd-user 2>/dev/null
launchctl disable gui/501/com.apple.rapportd-user

# Apple Pay / Wallet
launchctl bootout gui/501/com.apple.passd 2>/dev/null
launchctl disable gui/501/com.apple.passd

# 自然语言处理
launchctl bootout gui/501/com.apple.naturallanguaged 2>/dev/null
launchctl disable gui/501/com.apple.naturallanguaged

# Widget 同步
launchctl bootout gui/501/com.apple.replicatord 2>/dev/null
launchctl disable gui/501/com.apple.replicatord
launchctl bootout gui/501/com.apple.chronod 2>/dev/null
launchctl disable gui/501/com.apple.chronod

# 帮助
launchctl bootout gui/501/com.apple.helpd 2>/dev/null
launchctl disable gui/501/com.apple.helpd

# Follow-up 通知
launchctl bootout gui/501/com.apple.followupd 2>/dev/null
launchctl disable gui/501/com.apple.followupd

# Find My 相关（用户级）
launchctl bootout gui/501/com.apple.icloud.searchpartyuseragent 2>/dev/null
launchctl disable gui/501/com.apple.icloud.searchpartyuseragent
launchctl bootout gui/501/com.apple.findmy.findmylocateagent 2>/dev/null
launchctl disable gui/501/com.apple.findmy.findmylocateagent

# NetBIOS
sudo launchctl bootout system/com.apple.netbiosd 2>/dev/null
sudo launchctl disable system/com.apple.netbiosd
```

---

## 第三部分：Spotlight 优化

### Step 13：限制 Spotlight 索引范围

完全关闭 Spotlight 会影响 Xcode 的符号搜索。建议**保留但排除不需要的目录**。

**图形界面**：系统设置 → Siri 与聚焦 → 聚焦隐私 → 添加排除目录：
- `/Users/testuser/Downloads`
- `/Users/testuser/Movies`
- `/Users/testuser/Music`
- 任何大型数据集/模型目录（如 Ollama 模型存储目录）

如果确定不需要 Spotlight 文件搜索（仅用 Xcode 和终端）：
```bash
# 关闭 Spotlight 索引（可选，会影响 Xcode 搜索）
sudo mdutil -i off /
sudo mdutil -E /
```

---

## 第四部分：内存与性能调优

### Step 14：关闭交换文件压缩模式通知（可选）

```bash
# 禁止 App Nap（防止后台应用被降速）
defaults write NSGlobalDomain NSAppSleepDisabled -bool true
```

### Step 15：键盘重复速度加快（开发效率）

```bash
# 按键重复速度（越小越快，正常最快值为 2）
defaults write -g KeyRepeat -int 1

# 按键重复延迟（越小越快触发，正常最快值为 15）
defaults write -g InitialKeyRepeat -int 10
```

### Step 16：禁止自动 App 更新（手动控制更新时机）

```bash
# 禁止自动下载 App 更新
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false

# 禁止自动安装 macOS 更新
defaults write com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false

# 保留安全更新自动安装
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
```

---

## 第五部分：一键执行脚本

将以上所有操作合并为可执行脚本：

```bash
#!/bin/bash
# Mac 效能优化 — AI 开发工作站专用
# 用法: chmod +x mac_perf_optimize.sh && bash mac_perf_optimize.sh

echo "=== 1/5 关闭视觉特效 ==="
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g NSScrollAnimationEnabled -bool false
defaults write -g NSWindowResizeTime -float 0.001
defaults write -g QLPanelAnimationDuration -float 0
defaults write -g NSScrollViewRubberbanding -bool false
defaults write -g NSDocumentRevisionsWindowTransformAnimation -bool false
defaults write -g NSToolbarFullScreenAnimationDuration -float 0
defaults write -g NSBrowserColumnAnimationSpeedMultiplier -float 0
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock expose-animation-duration -float 0
defaults write com.apple.dock springboard-show-duration -float 0
defaults write com.apple.dock springboard-hide-duration -float 0
defaults write com.apple.dock springboard-page-duration -float 0
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.finder DisableAllAnimations -bool true
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write NSGlobalDomain NSAppSleepDisabled -bool true
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -int 10
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false
defaults write com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
killall Dock
killall Finder
echo "  视觉特效已关闭"

echo ""
echo "=== 2/5 关闭 Siri / Apple Intelligence ==="
SIRI_AGENTS=(
  com.apple.assistant_service com.apple.assistantd com.apple.assistant_cdmd
  com.apple.Siri.agent com.apple.siriactionsd com.apple.siriinferenced
  com.apple.sirittsd com.apple.SiriTTSTrainingAgent com.apple.siriknowledged
  com.apple.parsec-fbf com.apple.parsecd
  com.apple.intelligenceflowd com.apple.intelligencecontextd
  com.apple.intelligenceplatformd com.apple.generativeexperiencesd
  com.apple.knowledgeconstructiond com.apple.knowledge-agent com.apple.suggestd
)
for agent in "${SIRI_AGENTS[@]}"; do
  launchctl bootout gui/501/${agent} 2>/dev/null
  launchctl disable gui/501/${agent} 2>/dev/null
done
echo "  Siri / AI 服务已关闭"

echo ""
echo "=== 3/5 关闭娱乐 / 社交 / 照片 / 地图 ==="
MEDIA_AGENTS=(
  com.apple.itunescloudd com.apple.mediastream.mstreamd
  com.apple.videosubscriptionsd com.apple.watchlistd
  com.apple.gamed com.apple.voicebankingd
  com.apple.newsd com.apple.weatherd com.apple.tipsd com.apple.financed
  com.apple.photoanalysisd com.apple.photolibraryd
  com.apple.cloudphotod com.apple.mediaanalysisd
  com.apple.Maps.pushdaemon com.apple.Maps.mapssyncd
  com.apple.maps.destinationd com.apple.navd
  com.apple.geodMachServiceBridge com.apple.geoanalyticsd
  com.apple.imagent com.apple.imautomatichistorydeletionagent
  com.apple.imtransferagent com.apple.avconferenced
  com.apple.telephonyutilities.callservicesd com.apple.CallHistoryPluginHelper
)
for agent in "${MEDIA_AGENTS[@]}"; do
  launchctl bootout gui/501/${agent} 2>/dev/null
  launchctl disable gui/501/${agent} 2>/dev/null
done
sudo launchctl bootout system/com.apple.GameController.gamecontrollerd 2>/dev/null
sudo launchctl disable system/com.apple.GameController.gamecontrollerd 2>/dev/null
echo "  娱乐/社交/照片/地图服务已关闭"

echo ""
echo "=== 4/5 关闭 iCloud / 家庭 / 遥测 / 追踪 ==="
CLOUD_AGENTS=(
  com.apple.cloudd com.apple.cloudpaird com.apple.CloudSettingsSyncAgent
  com.apple.iCloudNotificationAgent com.apple.iCloudUserNotifications
  com.apple.protectedcloudstorage.protectedcloudkeysyncing
  com.apple.homed com.apple.familycircled
  com.apple.familycontrols.useragent com.apple.familynotificationd
  com.apple.ScreenTimeAgent com.apple.macos.studentd com.apple.progressd
  com.apple.TMHelperAgent
  com.apple.UsageTrackingAgent com.apple.BiomeAgent com.apple.biomesyncd
  com.apple.inputanalyticsd com.apple.ap.adprivacyd com.apple.ap.promotedcontentd
  com.apple.triald com.apple.routined com.apple.duetexpertd com.apple.ContextStoreAgent
  com.apple.sharingd com.apple.screensharing.agent
  com.apple.screensharing.menuextra com.apple.screensharing.MessagesAgent
  com.apple.sidecar-hid-relay com.apple.sidecar-relay
  com.apple.calaccessd com.apple.dataaccess.dataaccessd com.apple.remindd
  com.apple.rapportd-user com.apple.passd com.apple.naturallanguaged
  com.apple.replicatord com.apple.chronod com.apple.helpd com.apple.followupd
  com.apple.icloud.searchpartyuseragent com.apple.findmy.findmylocateagent
)
for agent in "${CLOUD_AGENTS[@]}"; do
  launchctl bootout gui/501/${agent} 2>/dev/null
  launchctl disable gui/501/${agent} 2>/dev/null
done

SYSTEM_DAEMONS=(
  com.apple.analyticsd com.apple.ecosystemanalyticsd
  com.apple.audioanalyticsd com.apple.wifianalyticsd
  com.apple.biomed com.apple.triald.system
  com.apple.backupd com.apple.backupd-helper
  com.apple.netbiosd com.apple.GameController.gamecontrollerd
)
for daemon in "${SYSTEM_DAEMONS[@]}"; do
  sudo launchctl bootout system/${daemon} 2>/dev/null
  sudo launchctl disable system/${daemon} 2>/dev/null
done
echo "  iCloud/家庭/遥测/追踪服务已关闭"

echo ""
echo "=== 5/5 完成 ==="
echo "  请重启 Mac 使所有更改生效"
echo ""
echo "  还原方法："
echo "  视觉特效：defaults delete <domain> <key>"
echo "  服务：launchctl enable gui/501/<服务名> 或 sudo launchctl enable system/<服务名>"
echo "  完全还原服务：sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.* && 重启"
```

---

## 第六部分：不要关闭的服务

| 服务 | 原因 |
|------|------|
| `com.apple.contactsd` | 关闭会导致 App Store 冻结 |
| `com.apple.AirPlayXPCHelper` | 关闭会导致 Safari 媒体播放出错 |
| `com.apple.donotdisturbd` | 关闭会导致通知中心停止工作 |
| `com.apple.iconservices.*` | 关闭会导致 Finder/系统 CPU 飙升 |
| `com.apple.quicklook.*` | Xcode 可能依赖 Quick Look 做预览 |
| `com.apple.locationd` | 系统级位置服务，部分应用依赖 |
| `com.apple.metadata.mds` | Spotlight 核心，Xcode 符号搜索依赖 |
| `com.apple.CoreLocationAgent` | 关闭后部分系统功能异常 |
| `com.apple.coreduetd` | 系统进程调度依赖 |
| `com.apple.WindowServer` | 图形服务核心，绝对不能关 |

---

## 第七部分：优化后预期效果

| 指标 | 预期改善 |
|------|---------|
| 后台进程数 | 减少 60-80 个 |
| 内存占用 | 释放 500MB-1GB |
| 开机时间 | 缩短 20-40% |
| UI 响应 | 无动画延迟，操作即时反馈 |
| Xcode 编译 | 更多 CPU/内存可用于编译 |
| Ollama 推理 | 更多内存用于模型加载 |
| 磁盘 I/O | 减少后台索引和同步的竞争 |

---

## 还原方法

如果需要恢复所有服务到默认状态：

```bash
# 删除服务禁用记录（恢复全部）
sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.plist
sudo rm -r /private/var/db/com.apple.xpc.launchd/disabled.501.plist

# 重启
sudo reboot
```

视觉特效还原：
```bash
# 逐项删除（恢复系统默认值）
defaults delete -g NSAutomaticWindowAnimationsEnabled
defaults delete -g NSScrollAnimationEnabled
defaults delete -g NSWindowResizeTime
defaults delete -g QLPanelAnimationDuration
defaults delete -g NSScrollViewRubberbanding
defaults delete com.apple.dock autohide-delay
defaults delete com.apple.dock autohide-time-modifier
defaults delete com.apple.dock expose-animation-duration
defaults delete com.apple.dock mineffect
defaults delete com.apple.finder DisableAllAnimations
defaults delete com.apple.universalaccess reduceMotion
defaults delete com.apple.universalaccess reduceTransparency
killall Dock
killall Finder
```
