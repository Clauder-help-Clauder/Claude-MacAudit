# MacAudit 系统审查报告

| 项目 | 值 |
|------|----|
| 生成时间 | 2026-04-23T18:35:17Z |
| 系统版本 | macOS Tahoe 26 (26.0.0) |
| 设备类型 | 台式机 |
| MacAudit | v0.1.5 |

## 摘要

| 指标 | 数量 |
|------|:----:|
| 总计 | 400 |
| 通过 | 117 |
| 失败 | 54 |
| 警告 | 70 |
| 信息 | 146 |
| 跳过 | 13 |
| 错误 | 0 |
| 耗时 | 4.8s |

## 系统信息 (12 项)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| i | SAFE | macOS 版本 | 26.0 |
| i | SAFE | 硬件型号 | VirtualMac2,1 |
| i | SAFE | 内核版本 | 25.0.0 |
| i | SAFE | CPU 架构 | arm64 |
| i | SAFE | 内存大小 | 4 GB |
| i | SAFE | 磁盘空间 | 31Gi |
| i | SAFE | 主机名 | <vm-hostname> |
| i | SAFE | 当前用户 | <vm-user> |
| i | SAFE | 运行时间 | 2:10 |
| i | SAFE | 内存压力 | 1 |
| i | SAFE | APFS 快照数 | 1 |
| i | SAFE | 登录项 | 0 |

## 网络安全机制及调优 (44 项, 22 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | SIP 状态 | enabled |
| ✓ | SAFE | Gatekeeper | assessments enabled |
| ✗ | SAFE | 防火墙全局状态 | disabled |
| ✓ | SAFE | 防火墙隐身模式 | enabled |
| ✓ | SAFE | 防火墙签名应用 | enabled |
| i | SAFE | 防火墙应用列表 | 8 |
| ✗ | SAFE | FileVault 状态 | FileVault is Off. |
| i | SAFE | FileVault 恢复密钥 | disabled |
| ✓ | SAFE | 锁屏密码 | 1 |
| ✓ | SAFE | 锁屏延迟 | 0 |
| ✗ | SAFE | 自动登录 | Password:__NOT_SET__ |
| i | SAFE | 系统扩展 | 0 |
| i | SAFE | 第三方 kext | 1 |
| i | SAFE | 第三方 LaunchAgents | 0 |
| i | SAFE | XProtect 版本 | 5287.000000 |
| ✗ | SAFE | SSH 远程登录 | enabled |
| ✗ | SAFE | 远程 Apple Events | unknown |
| ✓ | SAFE | AirPlay 接收端 | 0 |
| ✗ | SAFE | SMB 共享点数 | 2 |
| i | SAFE | 监听端口数 | 1 |
| i | SAFE | 活跃网络接口 | 8 |
| i | SAFE | DNS 服务器 | <vm-gateway>,<vm-gateway> |
| i | SAFE | Surge Fake IP | 0 |
| ✗ | SAFE | IPv6 全局地址 | 1 |
| i | SAFE | Surge Dashboard | N/A |
| ✗ | SAFE | Wi-Fi IPv6 |  |
| i | SAFE | Wi-Fi HTTP 代理 | N/A |
| ✗ | SAFE | TCP 发送缓冲区 | 131072 |
| ✗ | SAFE | TCP 接收缓冲区 | 131072 |
| ✗ | SAFE | TCP 自动接收上限 | 4194304 |
| ✗ | SAFE | TCP 自动发送上限 | 4194304 |
| ✗ | SAFE | TCP MSS 默认值 | 512 |
| ✗ | SAFE | 延迟 ACK | 3 |
| ✗ | SAFE | Socket 缓冲区上限 | 6291456 |
| ✗ | SAFE | 窗口缩放因子 | 3 |
| ✗ | SAFE | 本地慢启动拥塞窗口 | 8 |
| ✓ | SAFE | SACK 启用 | 1 |
| ✗ | SAFE | TCP 保活探测 | 0 |
| ✗ | SAFE | TCP MSL | 15000 |
| ✗ | MEDIUM | TCP 黑洞 | 0 |
| ✗ | MEDIUM | UDP 黑洞 | 0 |
| ✗ | MEDIUM | IPv6 路由通告 | 1 |
| ✓ | MEDIUM | IPv6 转发 | 0 |
| i | SAFE | sysctl 持久化 plist | missing |

## 隐私与遥测 (17 项, 1 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | 诊断数据提交 | 0 |
| ✓ | SAFE | 崩溃报告弹窗 | none |
| ✓ | SAFE | Siri 主开关 | 0 |
| ✓ | SAFE | Siri 数据共享 | 0 |
| ✓ | SAFE | Siri 菜单栏 | 0 |
| ✓ | SAFE | 个性化广告 | 0 |
| ✓ | SAFE | iCloud 使用追踪 | 0 |
| ✓ | SAFE | iCloud UDC 自动化 | 0 |
| ✗ | SAFE | mDNS 多播广告 | 0 |
| i | SAFE | Captive Portal 检测 | 0 |
| ✓ | SAFE | 网络卷 .DS_Store | 1 |
| ✓ | SAFE | USB 卷 .DS_Store | 1 |
| ✓ | SAFE | AirDrop 状态 | 1 |
| ✓ | SAFE | 照片面部识别 | 0 |
| ✓ | SAFE | Safari 网络搜索 | 0 |
| ✓ | SAFE | Safari 搜索建议 | 1 |
| ✓ | SAFE | Spotlight 建议 | 1 |

## 视觉动画优化 (43 项, 3 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | 窗口动画 | 0 |
| ✓ | SAFE | 窗口缩放速度 | 0.001 |
| ✓ | SAFE | 全屏工具栏动画 | 0 |
| ✓ | SAFE | 文档版本动画 | 0 |
| ✓ | SAFE | 浏览器列动画 | 0 |
| ✓ | SAFE | 滚动动画 | 0 |
| ✓ | SAFE | 橡皮筋回弹 | 0 |
| ✓ | SAFE | Quick Look 动画 | 0 |
| ✓ | SAFE | 工具提示延迟 | 0 |
| ✓ | SAFE | 弹簧加载延迟 | 0 |
| ✓ | SAFE | App Nap 禁用 | 1 |
| ✓ | SAFE | 键盘重复速度 | 1 |
| ✓ | SAFE | 键盘重复延迟 | 10 |
| ✗ | SAFE | 减少动态效果 | not set |
| ✗ | SAFE | 减少透明度 | not set |
| ✓ | SAFE | Dock 隐藏延迟 | 0 |
| ✓ | SAFE | Dock 隐藏动画 | 0 |
| ✓ | SAFE | 启动弹跳动画 | 0 |
| ✓ | SAFE | Dock 放大效果 | 0 |
| ✓ | SAFE | Mission Control 动画 | 0.1 |
| ✓ | SAFE | Launchpad 显示动画 | 0 |
| ✓ | SAFE | Launchpad 隐藏动画 | 0 |
| ✓ | SAFE | Launchpad 翻页动画 | 0 |
| ✓ | SAFE | 最小化效果 | scale |
| ✓ | SAFE | Dock 图标尺寸 | 36 |
| ✓ | SAFE | 最近应用 | 0 |
| ✓ | SAFE | 热角-左上 | 0 |
| ✓ | SAFE | 热角-右上 | 0 |
| ✓ | SAFE | 热角-左下 | 0 |
| ✓ | SAFE | 热角-右下 | 0 |
| ✓ | SAFE | Finder 动画 | 1 |
| ✓ | SAFE | 应用确认弹窗 | 0 |
| ✓ | SAFE | TM 新磁盘提示 | 1 |
| ✓ | SAFE | NowPlaying 状态栏 | 0 |
| ✓ | SAFE | 显示文件扩展名 | 1 |
| ✓ | SAFE | 文件夹优先排序 | 1 |
| ✓ | SAFE | 截图阴影 | 1 |
| ✓ | SAFE | 屏保空闲时间 | 0 |
| ✓ | SAFE | 截图格式 | png |
| ✗ | SAFE | Liquid Glass 模糊 | not set |
| ✓ | SAFE | Stage Manager 点击桌面 | 0 |
| ✓ | SAFE | 自动下载更新 | 0 |
| ✓ | SAFE | 自动安装更新 | 0 |

## 服务状态 (76 项, 68 警告)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | assistant_service | disabled |
| ✓ | SAFE | assistantd | disabled |
| ! | SAFE | assistant_cdmd | 未管理 |
| ✓ | SAFE | Siri.agent | disabled |
| ✓ | SAFE | siriactionsd | disabled |
| ! | SAFE | siriinferenced | 未管理 |
| ! | SAFE | sirittsd | 未管理 |
| ! | SAFE | SiriTTSTrainingAgent | 未管理 |
| ! | SAFE | siriknowledged | 未管理 |
| ! | SAFE | parsec-fbf | 未管理 |
| ! | SAFE | parsecd | 未管理 |
| ! | SAFE | intelligenceflowd | 未管理 |
| ! | SAFE | intelligencecontextd | 未管理 |
| ! | SAFE | intelligenceplatformd | 未管理 |
| ! | SAFE | knowledgeconstructiond | 未管理 |
| ! | SAFE | generativeexperiencesd | 未管理 |
| ! | SAFE | knowledge-agent | 未管理 |
| ! | SAFE | suggestd | 未管理 |
| ! | SAFE | naturallanguaged | 未管理 |
| ! | SAFE | proactived | 未管理 |
| ! | SAFE | milod | 未管理 |
| ! | SAFE | corespeechd | 未管理 |
| ! | SAFE | watchlistd | 未管理 |
| ✓ | SAFE | gamed | disabled |
| ! | SAFE | voicebankingd | 未管理 |
| ✓ | SAFE | newsd | disabled |
| ✓ | SAFE | weatherd | disabled |
| ! | SAFE | tipsd | 未管理 |
| ! | SAFE | financed | 未管理 |
| ! | SAFE | mediaanalysisd | 未管理 |
| ! | SAFE | shazamd | 未管理 |
| ! | SAFE | sportsd | 未管理 |
| ! | SAFE | homeenergyd | 未管理 |
| ! | SAFE | translationd | 未管理 |
| ! | SAFE | AMPDownloadAgent | 未管理 |
| ! | SAFE | photoanalysisd | 未管理 |
| ! | SAFE | Maps.pushdaemon | 未管理 |
| ! | SAFE | Maps.mapssyncd | 未管理 |
| ! | SAFE | maps.destinationd | 未管理 |
| ! | SAFE | navd | 未管理 |
| ! | SAFE | geodMachServiceBridge | 未管理 |
| ! | SAFE | geoanalyticsd | 未管理 |
| ! | SAFE | imautomatichistorydeletionagent | 未管理 |
| ! | SAFE | GameController.gamecontrollerd | 未管理 |
| ! | SAFE | iCloudNotificationAgent | 未管理 |
| ! | SAFE | iCloudUserNotifications | 未管理 |
| ! | SAFE | familycircled | 未管理 |
| ! | SAFE | familycontrols.useragent | 未管理 |
| ! | SAFE | familynotificationd | 未管理 |
| ! | SAFE | ScreenTimeAgent | 未管理 |
| ! | SAFE | macos.studentd | 未管理 |
| ! | SAFE | progressd | 未管理 |
| ! | SAFE | TMHelperAgent | 未管理 |
| ✓ | SAFE | UsageTrackingAgent | disabled |
| ! | SAFE | BiomeAgent | 未管理 |
| ! | SAFE | biomesyncd | 未管理 |
| ! | SAFE | inputanalyticsd | 未管理 |
| ! | SAFE | ap.adprivacyd | 未管理 |
| ! | SAFE | ap.promotedcontentd | 未管理 |
| ! | SAFE | triald | 未管理 |
| ! | SAFE | routined | 未管理 |
| ! | SAFE | duetexpertd | 未管理 |
| ! | SAFE | ContextStoreAgent | 未管理 |
| ! | SAFE | analyticsd | 未管理 |
| ! | SAFE | ecosystemanalyticsd | 未管理 |
| ! | SAFE | audioanalyticsd | 未管理 |
| ! | SAFE | wifianalyticsd | 未管理 |
| ! | SAFE | biomed | 未管理 |
| ! | SAFE | triald.system | 未管理 |
| ! | SAFE | screensharing.agent | 未管理 |
| ! | SAFE | screensharing.menuextra | 未管理 |
| ! | SAFE | screensharing.MessagesAgent | 未管理 |
| ! | SAFE | replicatord | 未管理 |
| ! | SAFE | helpd | 未管理 |
| ! | SAFE | followupd | 未管理 |
| ! | SAFE | icloud.searchpartyuseragent | 未管理 |

## 电源配置 (21 项, 10 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✗ | SAFE | 接电-系统休眠 | 1 |
| ✗ | SAFE | 接电-磁盘休眠 | 10 |
| ✓ | SAFE | 接电-显示器关闭 | 10 |
| ✓ | SAFE | 接电-待机 | 0 |
| ✗ | SAFE | 接电-Power Nap | 1 |
| ✗ | SAFE | 接电-节能模式 |  |
| ✗ | SAFE | 断电自动重启 |  |
| ✗ | SAFE | 网络唤醒 (AC) |  |
| ✗ | SAFE | SMS 突发唤醒（关闭） |  |
| i | SAFE | powermetrics 工具 | /usr/bin/powermetrics |
| i | SAFE | caffeinate 运行 | N/A |
| i | SAFE | caffeinate 系统级 | missing |
| i | SAFE | caffeinate 用户级 | missing |
| ✓ | SAFE | 定时关机计划 | 0 |
| i | SAFE | 屏保空闲时间 | not set |
| i | SAFE | 文件描述符限制 | 256 |
| i | SAFE | 内存压力级别 | 1 |
| ✗ | SAFE | Wi-Fi 接电唤醒 |  |
| ✗ | SAFE | 休眠模式 |  |
| i | SAFE | Amphetamine（防休眠工具） | not installed |
| ✗ | SAFE | 服务器模式（一键设定） | 1 |

## 终端环境 (19 项, 1 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | 默认 Shell | /bin/zsh |
| i | SAFE | HTTPS_PROXY | not set |
| i | SAFE | HTTP_PROXY | not set |
| i | SAFE | all_proxy_on 函数 | 0 |
| i | SAFE | all_proxy_off 函数 | 0 |
| i | SAFE | HOMEBREW_NO_ANALYTICS | not set |
| i | SAFE | Git user.name | not set |
| i | SAFE | Git user.email | not set |
| i | SAFE | SSH config | missing |
| i | SAFE | SSH ControlMaster | N/A |
| ✗ | SAFE | ulimit -n | 2560 |
| i | SAFE | ulimit -u | 1333 |
| ✓ | MEDIUM | 危险别名检测 | 0 |
| i | SAFE | LANG 语言环境 | en_US.UTF-8 |
| i | SAFE | LC_ALL 语言覆盖 | en_US.UTF-8 |
| i | SAFE | macOS 系统语言 | en-US |
| ✓ | SAFE | zsh_history 中文命令 | 0 |
| i | SAFE | maxfiles 持久化 | missing |
| i | SAFE | dotfiles 数量 | 4 |

## AI服务调优 (53 项, 15 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | 禁止关闭非必要流量（风控风险） | not set |
| ✓ | SAFE | 禁止关闭反馈调查（风控风险） | not set |
| ✓ | SAFE | 禁止关闭遥测总开关（极高风险） | not set |
| ✓ | SAFE | ANTHROPIC_BASE_URL 未自定义（服务端危险变量） | not set |
| ✓ | SAFE | NODE_TLS_REJECT_UNAUTHORIZED 未禁用（服务端危险变量） | not set |
| ✓ | SAFE | OTel 遥测未启用 | not set |
| ✓ | SAFE | Prompt 日志未开启 | not set |
| ✓ | SAFE | 工具调用日志未开启 | not set |
| ✗ | SAFE | Claude Code 安全环境变量（A组汇总） | not set |
| ✓ | SAFE | 代理 DNS 解析 | 1 |
| ✓ | SAFE | 流监控看门狗 | 1 |
| ✓ | SAFE | 子进程凭据清洗 | 1 |
| ✓ | SAFE | 流空闲超时 | 1 |
| i | SAFE | 隐藏升级命令（低影响） | not set |
| i | SAFE | DeviceId 永久设备指纹 | N/A |
| i | SAFE | git user.email 身份泄露 | not set |
| ✗ | SAFE | npm 源地理信号 | not set |
| i | SAFE | 时区环境信号 | PDT |
| i | SAFE | LANG 语言环境信号 | en_US.UTF-8 |
| i | SAFE | LC_ALL 语言覆盖信号 | en_US.UTF-8 |
| i | SAFE | macOS 系统语言首选项 | en-US |
| ✗ | SAFE | HTTPS_PROXY 强制出口代理 | not set |
| i | SAFE | all_proxy_on 函数 | 0 |
| i | SAFE | all_proxy_off 函数 | 0 |
| ✗ | SAFE | 沙盒代理端口 | 0 |
| ✗ | SAFE | 沙盒域名白名单 | 0 |
| ✗ | SAFE | 仅允许托管域名 | 0 |
| i | SAFE | Surge Fake IP DNS | 0 |
| ✗ | SAFE | Surge TUN 接口 | 8 |
| ✗ | SAFE | IPv6 全局地址 | 1 |
| ✗ | SAFE | Wi-Fi IPv6 |  |
| ✗ | SAFE | mDNS 多播 | 0 |
| i | SAFE | Captive Portal | <vm-user>’s Virtual Machine not set |
| ✗ | SAFE | IPv6 路由通告 | 1 |
| ✓ | SAFE | IPv6 转发 | 0 |
| ✗ | SAFE | 防火墙开启 | disabled |
| ✓ | SAFE | 防火墙隐身 | enabled |
| i | SAFE | 防火墙签名 | enabled |
| i | SAFE | LuLu 安装 | not installed |
| i | SAFE | KnockKnock 安装 | not installed |
| i | SAFE | Surge Dashboard 绑定 | N/A |
| ✓ | SAFE | Apple 诊断数据提交 | 0 |
| ✓ | SAFE | 崩溃报告弹窗 | none |
| ✓ | SAFE | Apple 个性化广告 | 0 |
| ✓ | SAFE | iCloud 使用追踪 | 0 |
| ✓ | SAFE | iCloud UDC 自动化 | 0 |
| ✓ | SAFE | NO_PROXY 本地排除 | not set |
| ✗ | SAFE | all_proxy_on 含 NO_PROXY 排除 | 0 |
| i | SAFE | Help improve Claude (对话训练开关) | not set |
| i | SAFE | Claude Code 版本 | not installed |
| ✗ | SAFE | 全部接口 IPv6 状态 | 3 |
| ✓ | SAFE | 防火墙已下载签名应用 | enabled |
| ✗ | SAFE | Surge WebRTC STUN 拦截 | 0 |

## 开发工具 (66 项, 2 失败)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| i | SAFE | Xcode CLT | not installed |
| i | SAFE | Clang 版本 | N/A |
| i | SAFE | Xcode 版本 | N/A |
| i | SAFE | Homebrew | N/A |
| i | SAFE | Homebrew 路径 | not found |
| i | SAFE | Homebrew analytics | N/A |
| i | SAFE | brew 路径检查 | N/A |
| i | SAFE | nvm | not found |
| i | SAFE | Node.js | not installed |
| i | SAFE | npm | not installed |
| i | SAFE | Bun | not installed |
| i | SAFE | TypeScript | not installed |
| i | SAFE | pyenv | not installed |
| i | SAFE | Python | not installed |
| i | SAFE | uv | not installed |
| i | SAFE | Rust | not installed |
| i | SAFE | Cargo | not installed |
| i | SAFE | Go | not installed |
| i | SAFE | Java | The operation couldn’t be completed. Unable to locate a Java Runtime. |
| i | SAFE | MLX 框架 | not installed |
| i | SAFE | Rust 组件 | 0 |
| i | SAFE | Git | not installed |
| i | SAFE | git-lfs | not installed |
| i | SAFE | GitHub CLI | N/A |
| i | SAFE | lazygit | N/A |
| i | SAFE | delta | not installed |
| i | SAFE | GIT_PAGER | not set |
| i | SAFE | git safe.directory 重复 | 0 |
| i | SAFE | git 全局配置项数 | 0 |
| i | SAFE | ripgrep | N/A |
| i | SAFE | fzf | not installed |
| i | SAFE | jq | jq-1.7.1-apple |
| i | SAFE | bat | not installed |
| i | SAFE | eza | N/A |
| i | SAFE | htop | N/A |
| i | SAFE | ncdu | not installed |
| i | SAFE | wget | N/A |
| i | SAFE | fd | not installed |
| i | SAFE | yq | not installed |
| i | SAFE | tree | not installed |
| i | SAFE | lazydocker | N/A |
| i | SAFE | OrbStack | N/A |
| i | SAFE | Docker | not installed |
| i | SAFE | Ollama | not installed |
| i | SAFE | OLLAMA_GPU_LAYERS | not set |
| i | SAFE | OLLAMA_MAX_LOADED_MODELS | not set |
| i | SAFE | OLLAMA_NUM_PARALLEL | not set |
| i | SAFE | OLLAMA_MAX_QUEUE | not set |
| i | SAFE | llama.cpp | installed |
| i | SAFE | Claude Code | N/A |
| i | SAFE | Codex CLI | N/A |
| i | SAFE | OpenCode | N/A |
| i | SAFE | Gemini CLI | N/A |
| i | SAFE | Xcode 清理 plist | missing |
| i | SAFE | Ollama Metal GPU | N/A |
| i | SAFE | brew formula 数 | 0 |
| i | SAFE | brew cask 数 | 0 |
| i | SAFE | brew formula 列表 | N/A |
| i | SAFE | brew cask 列表 | N/A |
| ✗ | SAFE | ulimit -n (文件描述符) | 2560 |
| ✗ | SAFE | ulimit -u (进程数) | 1333 |
| i | SAFE | JAVA_HOME | not set |
| i | SAFE | Swift | N/A |
| i | SAFE | Deno | N/A |
| i | SAFE | pnpm | not installed |
| i | SAFE | Yarn | not installed |

## IP 质量检测 (23 项, 2 警告)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| i | SAFE | 公网 IPv4 | 45.40.60.181 |
| i | SAFE | 公网 IPv6 | 不可用 |
| i | SAFE | 本地网络接口 | <vm-ip> |
| i | SAFE | DNS 服务器 | <vm-gateway> |
| i | SAFE | 代理配置 | 无代理 |
| i | SAFE | 默认网关 | <vm-gateway> |
| i | SAFE | 反向 DNS | 无记录 |
| i | SAFE | Whois 组织 | Zenlayer Inc |
| i | SAFE | Whois 国家 | US |
| i | SAFE | 所在国家 | Japan (JP) |
| i | SAFE | 所在城市 | Tokyo, Tokyo To |
| i | SAFE | 时区 | Asia/Tokyo |
| i | SAFE | ASN | AS21859 (Zenlayer Inc) |
| i | SAFE | ISP | ZENLA-1 |
| ✓ | SAFE | 代理检测 | 否 |
| ✓ | SAFE | VPN 检测 | 否 |
| ✓ | SAFE | Tor 检测 | 否 |
| ! | SAFE | 数据中心检测 | 是 |
| i | SAFE | IP 类型 | hosting |
| ! | SAFE | 托管检测 | 是 |
| ✓ | SAFE | DNSBL 黑名单 | 干净 13/13 |
| ✓ | SAFE | SMTP Port 25 | 开放 |
| ✓ | SAFE | SMTP Port 587 | 开放 |

## Chrome 浏览器 (13 项)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ⊘ | SAFE | Chrome 安装状态 | N/A |
| ⊘ | MEDIUM | WebRTC IP 防泄露 | N/A |
| ⊘ | MEDIUM | Chrome 内置 DoH | N/A |
| ⊘ | MEDIUM | Chrome 内置 DNS 客户端 | N/A |
| ⊘ | SAFE | Chrome 遥测上报 | N/A |
| ⊘ | SAFE | Safe Browsing 扩展上报 | N/A |
| ⊘ | SAFE | Chrome 网络预加载 | N/A |
| ⊘ | SAFE | Chrome 搜索建议 | N/A |
| ⊘ | SAFE | Chrome 翻译服务 | N/A |
| ⊘ | SAFE | Chrome 云端拼写检查 | N/A |
| ⊘ | SAFE | Chrome 扩展旁加载 | N/A |
| ⊘ | SAFE | Chrome Google 账号登录 | N/A |
| ⊘ | SAFE | Chrome 策略生效验证 | N/A |

## Safari 浏览器 (13 项)

| 状态 | 风险 | 检测项 | 值 |
|:----:|:----:|--------|----|
| ✓ | SAFE | Safari 网页搜索上报 | 0 |
| ✓ | SAFE | Safari 搜索建议 | 1 |
| ✓ | SAFE | Safari 预加载顶部结果 | 0 |
| ✓ | SAFE | Safari 欺诈网站警告 | 1 |
| ✓ | SAFE | Safari 自动打开下载 | 0 |
| ✓ | SAFE | Safari 显示完整 URL | 1 |
| ✓ | SAFE | Safari 扩展自动更新 | 1 |
| ✓ | SAFE | Safari 阻止弹窗 | 0 |
| ✓ | SAFE | Safari 地址自动填充 | 0 |
| ✓ | SAFE | Safari 信用卡自动填充 | 0 |
| ✓ | SAFE | Safari 私有浏览指纹保护 | 1 |
| ✓ | SAFE | Safari 常规浏览指纹保护 | 1 |
| i | SAFE | Safari IP 隐藏 | not set |

## 可修复项摘要

> 使用 `macaudit --fix` 自动修复 safe/low 风险项，或使用交互式菜单进行分级优化。

| 模块 | 检测项 | 实际值 | 期望值 |
|------|--------|--------|--------|
| network_security | TCP 黑洞 | 0 | 2 |
| network_security | UDP 黑洞 | 0 | 1 |
| network_security | IPv6 路由通告 | 1 | 0 |
| network_security | 防火墙全局状态 | disabled | enabled |
| network_security | FileVault 状态 | FileVault is Off. | FileVault is On. |
| network_security | 自动登录 | Password:__NOT_SET__ | disabled |
| network_security | SSH 远程登录 | enabled | disabled |
| network_security | 远程 Apple Events | unknown | disabled |
| network_security | SMB 共享点数 | 2 | 0 |
| network_security | IPv6 全局地址 | 1 | 0 |
| network_security | Wi-Fi IPv6 |  | Off |
| network_security | TCP 发送缓冲区 | 131072 | 1048576 |
| network_security | TCP 接收缓冲区 | 131072 | 1048576 |
| network_security | TCP 自动接收上限 | 4194304 | 33554432 |
| network_security | TCP 自动发送上限 | 4194304 | 33554432 |
| network_security | TCP MSS 默认值 | 512 | 1460 |
| network_security | 延迟 ACK | 3 | 0 |
| network_security | Socket 缓冲区上限 | 6291456 | 16777216 |
| network_security | 窗口缩放因子 | 3 | 8 |
| network_security | 本地慢启动拥塞窗口 | 8 | 20 |
| network_security | TCP 保活探测 | 0 | 1 |
| network_security | TCP MSL | 15000 | 5000 |
| privacy | mDNS 多播广告 | 0 | 1 |
| animation | 减少动态效果 | not set | 1 |
| animation | 减少透明度 | not set | 1 |
| animation | Liquid Glass 模糊 | not set | 1 |
| power | 接电-系统休眠 | 1 | 0 |
| power | 接电-磁盘休眠 | 10 | 0 |
| power | 接电-Power Nap | 1 | 0 |
| power | 接电-节能模式 |  | 0 |
| power | 断电自动重启 |  | 1 |
| power | 网络唤醒 (AC) |  | 1 |
| power | SMS 突发唤醒（关闭） |  | 0 |
| power | Wi-Fi 接电唤醒 |  | 1 |
| power | 休眠模式 |  | 0 |
| power | 服务器模式（一键设定） | 1 | 0 |
| shell | ulimit -n | 2560 | 65536 |
| claude | Claude Code 安全环境变量（A组汇总） | not set | 1 |
| claude | npm 源地理信号 | not set | https://registry.npmjs.org/ |
| claude | HTTPS_PROXY 强制出口代理 | not set | set |
| claude | 沙盒代理端口 | 0 | 1 |
| claude | 沙盒域名白名单 | 0 | 1 |
| claude | 仅允许托管域名 | 0 | 1 |
| claude | Surge TUN 接口 | 8 | 1 |
| claude | IPv6 全局地址 | 1 | 0 |
| claude | Wi-Fi IPv6 |  | Off |
| claude | mDNS 多播 | 0 | 1 |
| claude | IPv6 路由通告 | 1 | 0 |
| claude | 防火墙开启 | disabled | enabled |
| claude | all_proxy_on 含 NO_PROXY 排除 | 0 | 1 |
| claude | 全部接口 IPv6 状态 | 3 | 0 |
| claude | Surge WebRTC STUN 拦截 | 0 | 1 |
| dev | ulimit -n (文件描述符) | 2560 | 65536 |
| dev | ulimit -u (进程数) | 1333 | 2048 |

