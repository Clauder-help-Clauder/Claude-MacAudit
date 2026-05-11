# MacAudit — 软件功能全量说明书
> 版本：v0.1.5 | 目标平台：macOS 15 Sequoia / macOS 26 Tahoe | 架构：arm64 + x86_64 Universal
> 文档用途：深度调研团队反向调研 — 功能、逻辑、需求合理性评估

---

## 文档导读

本文档以**分子级颗粒度**逐项列出 MacAudit 的每一个功能检测项，格式统一为：

```
### 功能名称
- **检测内容**：检测什么
- **益处**：开启/配置该项带来的实际好处
- **理由**：为什么需要检测这一项（技术原因 / 安全原因 / 性能原因）
- **检测命令**：实际执行的 shell 命令
- **期望值**：通过判定标准
- **修复命令**：（如有）一键修复
```

---

## 全局架构说明

MacAudit 由 **12 个审计模块**构成，每个模块对应一个系统关注领域：

| 模块 ID | 模块名称 | 检测项数（约） | 是否计入评分 |
|---------|---------|------------|----------|
| M1 system_info | 系统信息 | 12 | 否（信息类） |
| M2+M3+M8 network_security | 网络安全机制及调优 | 46 | 是 |
| M4 privacy | 隐私与遥测 | 17 | 是 |
| M5 animation | 视觉动画优化 | 43 | 否（建议类） |
| M6 services | 服务状态 | ~70 | 否（建议类） |
| M7 power | 电源配置 | 20 | 是 |
| M9 shell | 终端环境 | 17 | 是 |
| M10 claude | AI 服务调优 | 53 | 是 |
| M11 dev | 开发工具 | 50+ | 否（信息类） |
| M13 ip_quality | IP 质量检测 | 23 | 是 |
| M14 chrome | Chrome 浏览器 | 13 | 是 |
| M15 safari | Safari 浏览器 | 12 | 是 |

**评分规则**：
- 不计入评分的模块：services（M6）、dev（M11）、animation（M5）
- 不计入评分的状态：.skip、.info
- 用户手动标记 SKIP 的检测项不计入

---

## M1 — 系统信息模块

> 定位：信息收集类，全部为 .info 状态，不判 pass/fail，不计入系统评分。

### M1-1：macOS 版本
- **检测内容**：当前系统版本号（如 15.4.1）
- **益处**：确认是否运行在受支持的版本上；提醒用户安装安全补丁
- **理由**：Apple 每年发布多个安全更新，旧版本存在已知漏洞；开发工具（Claude Code、Ollama 等）也对最低系统版本有要求
- **检测命令**：`sw_vers -productVersion`

### M1-2：硬件型号
- **检测内容**：Mac 硬件标识符（如 Mac15,3 = MacBook Pro M3）
- **益处**：确认是否为 Apple Silicon 机型；判断 AI 推理加速能力
- **理由**：Apple Silicon（M 系列）与 Intel 在 Metal GPU 加速、统一内存架构上有本质差异，直接影响本地 AI 模型推理效率
- **检测命令**：`sysctl -n hw.model`

### M1-3：内核版本
- **检测内容**：Darwin XNU 内核版本（如 24.x = Sequoia，25.x = Tahoe）
- **益处**：确认内核版本与已知安全补丁的对应关系
- **理由**：内核版本决定了 sysctl 参数可用性、网络栈行为差异（部分 M8 调优参数在特定内核版本才生效）
- **检测命令**：`uname -r`

### M1-4：CPU 架构
- **检测内容**：CPU 架构（arm64 或 x86_64）
- **益处**：确认是否为 Apple Silicon，判断 Metal GPU 加速是否可用
- **理由**：Apple Silicon 使 Ollama 本地 LLM 推理效率比 Intel Mac 提升 5-10 倍；arm64 架构支持 MLX 框架（Tahoe 专属）
- **检测命令**：`uname -m`
- **期望值**：`arm64`

### M1-5：内存大小
- **检测内容**：物理统一内存总量（GB）
- **益处**：评估能运行的本地 AI 模型规模
- **理由**：Apple Silicon 统一内存 CPU/GPU 共享，运行 7B 模型需 16GB+，70B 模型需 64GB+，不足时推理速度会极度劣化
- **检测命令**：`echo "$(( $(sysctl -n hw.memsize) / 1073741824 )) GB"`

### M1-6：磁盘空间
- **检测内容**：根目录可用磁盘空间
- **益处**：确认有足够空间用于系统更新、模型下载、构建缓存
- **理由**：磁盘不足会导致系统更新失败、LLM 模型无法下载、Xcode DerivedData 积累导致构建失败
- **检测命令**：`df -h / | tail -1 | awk '{print $4}'`

### M1-7：主机名
- **检测内容**：当前 hostname 输出
- **益处**：识别是否使用了含真实身份信息的默认主机名
- **理由**：macOS 默认主机名常为 "John's MacBook"，会在 mDNS 广播、SSH 日志、网络嗅探中暴露用户真实姓名和设备型号
- **检测命令**：`hostname`

### M1-8：当前用户名
- **检测内容**：whoami 输出
- **益处**：识别用户名是否含真实姓名（影响文件路径身份暴露）
- **理由**：/Users/johndoe/ 这类路径在日志、错误信息、Stack Trace 中会直接暴露身份；Claude Code 日志也会包含路径
- **检测命令**：`whoami`

### M1-9：系统运行时间
- **检测内容**：系统连续运行时间（uptime）
- **益处**：识别是否超过 30 天未重启（安全补丁可能未生效）
- **理由**：部分 macOS 安全更新（内核补丁）需要重启才能真正激活；内存泄漏在长期运行后积累明显
- **检测命令**：`uptime | sed 's/.*up //' | sed 's/,.*//'`

### M1-10：内存压力级别
- **检测内容**：系统内存压力等级（0=正常，1=警告，2=紧急）
- **益处**：实时了解系统内存健康状态；触发时指导用户采取缓解措施
- **理由**：本地 AI 推理（Ollama/MLX）是内存消耗大户，内存压力过高会导致模型推理极慢甚至崩溃
- **检测命令**：`sysctl -n kern.memorystatus_vm_pressure_level`

### M1-11：APFS 快照数
- **检测内容**：Time Machine 在本地磁盘创建的 APFS 快照数量
- **益处**：识别隐性磁盘占用（每个快照可能占数 GB）
- **理由**：APFS 本地快照是 Time Machine 的本地缓存机制，用户通常不知道其存在，它会悄悄消耗大量磁盘空间
- **检测命令**：`tmutil listlocalsnapshots / 2>/dev/null | wc -l | tr -d ' '`
- **修复命令**：`tmutil deletelocalsnapshots /`

### M1-12：登录项数量
- **检测内容**：用户级 LaunchAgents 目录文件数（开机自启项）
- **益处**：识别过多登录项对启动速度和资源的影响
- **理由**：每个登录项都在启动时消耗 CPU/内存；恶意软件常通过登录项实现持久化；超过 10 个应逐一审查
- **检测命令**：`ls ~/Library/LaunchAgents/ 2>/dev/null | wc -l | tr -d ' '`

---

## M2 — 安全机制检测（网络安全模块 A 部分）

> 定位：系统核心安全防线，全部计入评分，检测 SIP/Gatekeeper/FileVault 等核心安全开关。

### M2-1：SIP 状态（System Integrity Protection）
- **检测内容**：SIP 保护是否开启（enabled/disabled）
- **益处**：防止恶意代码修改系统文件、内核扩展、受保护目录（/System、/usr 等）
- **理由**：SIP 是 macOS 安全体系的最后一道防线。关闭后，攻击者可修改系统二进制文件、持久化恶意代码。开发调试时可能临时关闭，但日常使用必须开启
- **检测命令**：`csrutil status 2>/dev/null | grep -o 'enabled\|disabled'`
- **期望值**：`enabled`

### M2-2：Gatekeeper（应用公证检查）
- **检测内容**：Gatekeeper 是否开启（assessments enabled）
- **益处**：阻止运行未经 Apple 公证的应用程序，防止恶意软件伪装成正常应用运行
- **理由**：Gatekeeper 验证应用的开发者签名和 Apple 公证状态。关闭后，任何未签名程序都可运行，是供应链攻击的常见突破口
- **检测命令**：`spctl --status 2>/dev/null | head -1`
- **期望值**：`assessments enabled`
- **修复命令**：`sudo spctl --master-enable`

### M2-3：防火墙全局状态
- **检测内容**：macOS 应用层防火墙是否全局开启
- **益处**：阻止未授权的入站网络连接，防止本机端口被外部直接访问
- **理由**：macOS 防火墙是应用层防火墙（ALF），基于进程控制入站连接。关闭后，所有监听端口（包括恶意进程打开的端口）对网络均可见
- **检测命令**：`/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -o 'enabled\|disabled'`
- **期望值**：`enabled`
- **修复命令**：`sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on`

### M2-4：防火墙隐身模式
- **检测内容**：防火墙隐身模式（Stealth Mode）是否开启
- **益处**：不响应来自网络的 ICMP ping 探测和 TCP/UDP 端口扫描，使本机在网络中"不可见"
- **理由**：隐身模式让攻击者的端口扫描工具（nmap 等）无法探测到本机存在，增加攻击难度
- **检测命令**：`/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -oi 'enabled\|disabled' | head -1`
- **期望值**：`enabled`
- **修复命令**：`sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on`

### M2-5：防火墙签名应用自动通过
- **检测内容**：已签名应用是否自动被防火墙允许连接
- **益处**：Claude Code、Ollama 等经过 Apple 签名的工具无需手动添加防火墙白名单即可联网
- **理由**：如果关闭此项，每次安装新的合法工具都需要手动在防火墙配置中批准，造成使用摩擦；开启后只有有效代码签名的应用才自动获得通过权限
- **检测命令**：`/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null | grep -oi 'ENABLED\|DISABLED' | head -1 | tr '[:upper:]' '[:lower:]'`
- **期望值**：`enabled`
- **修复命令**：`sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on`

### M2-6：防火墙应用列表
- **检测内容**：防火墙中已配置的应用条目数（信息类）
- **益处**：了解哪些应用被单独配置了防火墙规则
- **理由**：防火墙应用列表越长，说明有越多应用被手动干预，可能存在意外放行或意外拦截的情况
- **检测命令**：`/usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | grep -c 'ALF'`

### M2-7：FileVault 状态（磁盘加密）
- **检测内容**：FileVault 全盘加密是否开启
- **益处**：即使 Mac 被盗或被物理访问，磁盘数据在未解锁前完全无法读取
- **理由**：未加密的磁盘可通过目标磁盘模式（Target Disk Mode）或拆卸硬盘直接读取所有数据。开发者的代码库、API Keys、密码文件等均会暴露
- **检测命令**：`fdesetup status 2>/dev/null | head -1`
- **期望值**：`FileVault is On.`

### M2-8：FileVault 恢复密钥
- **检测内容**：是否已设置个人恢复密钥（Personal Recovery Key）
- **益处**：忘记登录密码时可通过恢复密钥解锁磁盘，防止数据永久丢失
- **理由**：FileVault 加密的磁盘在无恢复密钥的情况下密码遗忘=数据永久丢失；恢复密钥应安全存储在密码管理器中
- **检测命令**：`fdesetup haspersonalrecoverykey 2>/dev/null | grep -o 'true\|false'`

### M2-9：锁屏密码要求
- **检测内容**：唤醒屏保后是否要求密码（askForPassword = 1）
- **益处**：短暂离开时保护系统不被物理接触访问
- **理由**：没有锁屏密码要求意味着任何人走近屏幕晃动鼠标即可直接使用你的系统，是最基础的物理安全要求
- **检测命令**：`defaults read com.apple.screensaver askForPassword 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`defaults write com.apple.screensaver askForPassword -bool true`

### M2-10：锁屏密码延迟
- **检测内容**：唤醒后要求输入密码的延迟时间（期望值 0 = 立即）
- **益处**：屏幕一锁即需密码，防止延迟窗口内被他人访问
- **理由**：即使开启了锁屏密码，如果延迟设为 5 分钟，攻击者在 5 分钟内晃动鼠标仍可免密进入系统
- **检测命令**：`defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.screensaver askForPasswordDelay -int 0`

### M2-11：自动登录状态
- **检测内容**：系统是否开启了无密码自动登录
- **益处**：防止任何人开机后直接无密码进入系统
- **理由**：自动登录是最严重的物理安全漏洞之一，Mac 重启后任何人都可直接使用。笔记本被盗后数据立即完全暴露
- **检测命令**：`defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo 'disabled'`
- **期望值**：`disabled`
- **修复命令**：`sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser`

### M2-12：系统扩展数量
- **检测内容**：已激活的系统扩展（System Extension）数量
- **益处**：了解有多少第三方系统扩展在内核层运行
- **理由**：系统扩展在最高权限层运行，恶意系统扩展可完全控制系统；定期审查来源可疑的扩展
- **检测命令**：`systemextensionsctl list 2>/dev/null | grep -c 'activated'`

### M2-13：第三方内核扩展（kext）
- **检测内容**：非 Apple 内核扩展数量
- **益处**：识别可能存在安全风险的第三方内核扩展
- **理由**：kext（内核扩展）运行在内核空间，拥有最高权限。过时或恶意的 kext 是严重的安全风险，也是系统崩溃的常见原因
- **检测命令**：`kextstat 2>/dev/null | grep -cv com.apple`

### M2-14：第三方 LaunchAgents 总数
- **检测内容**：用户目录、/Library 和 LaunchDaemons 中的第三方启动项总数
- **益处**：评估攻击面大小，发现可能的恶意持久化项
- **理由**：LaunchAgents/Daemons 是恶意软件持久化的标准手段，定期审查数量异常增长
- **检测命令**：`(ls ~/Library/LaunchAgents/ 2>/dev/null; ls /Library/LaunchAgents/ 2>/dev/null; ls /Library/LaunchDaemons/ 2>/dev/null) | wc -l | tr -d ' '`

### M2-15：XProtect 版本
- **检测内容**：苹果内置恶意软件扫描数据库版本
- **益处**：确认系统恶意软件防护数据库是否保持最新
- **理由**：XProtect 是 macOS 的内置反病毒机制，Apple 会不断更新其病毒特征库；版本过旧意味着无法识别新型恶意软件
- **检测命令**：`/usr/libexec/PlistBuddy -c 'Print :Version' /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist 2>/dev/null || echo 'N/A'`

---

## M3 — 网络安全检测（网络安全模块 B 部分）

> 定位：检测暴露的网络服务、入站风险、IPv6 泄露等，全部计入评分。

### M3-1：SSH 远程登录状态
- **检测内容**：sshd 服务是否被 launchctl 禁用（期望 true=禁用）
- **益处**：关闭不需要远程 SSH 时，阻止来自网络的 SSH 登录尝试，消除暴力破解攻击面
- **理由**：SSH 是最常见的远程攻击入口，未使用时应完全禁用。如需使用应结合 SSH Key 认证并限制来源 IP
- **检测命令**：`launchctl print-disabled system/ 2>/dev/null | grep sshd | grep -o 'true\|false' || echo 'unknown'`

### M3-2：远程 Apple Events
- **检测内容**：Apple Remote Events（eppc）服务是否禁用
- **益处**：防止远程主机通过 Apple Script 控制本机应用
- **理由**：Apple Events 允许远程机器向本机应用发送脚本命令，是老旧的网络管理协议，现代场景几乎不需要，应关闭
- **检测命令**：`launchctl print-disabled system/ 2>/dev/null | grep eppc | grep -o 'true\|false' || echo 'unknown'`

### M3-3：AirPlay 接收端状态
- **检测内容**：本机是否作为 AirPlay 接收端开放端口 5000
- **益处**：关闭后局域网内其他设备无法向本机投屏，减少局域网攻击面
- **理由**：AirPlay 接收端在局域网内广播自身存在，任何同网络设备都可发起连接请求；办公网络中关闭可减少意外暴露
- **检测命令**：`lsof -nP -iTCP:5000 -sTCP:LISTEN 2>/dev/null | grep -c ControlCe`
- **期望值**：`0`

### M3-4：SMB 共享点数量
- **检测内容**：当前配置的 SMB 文件共享点数量
- **益处**：无文件共享需求时归零，防止局域网其他设备访问本机文件
- **理由**：SMB 协议历史上有大量安全漏洞（EternalBlue 等），在办公网络内误开文件共享可导致数据泄露
- **检测命令**：`sharing -l 2>/dev/null | grep -c 'name:'`
- **期望值**：`0`

### M3-5：当前监听端口数
- **检测内容**：TCP 监听端口总数（信息类）
- **益处**：了解系统当前暴露的网络入口数量
- **理由**：每个监听端口都是潜在的攻击面；监听端口数量突然增加可能是恶意软件或误操作的信号
- **检测命令**：`lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | tail -n +2 | wc -l | tr -d ' '`

### M3-6：活跃网络接口数
- **检测内容**：当前 UP 状态的网络接口数（信息类）
- **益处**：识别非预期的活跃网络接口（如意外开启的热点、VPN tunnel 等）
- **理由**：过多的活跃网络接口可能意味着系统在多个网络中同时暴露，增加安全风险
- **检测命令**：`ifconfig 2>/dev/null | grep -c 'flags=.*UP'`

### M3-7：DNS 服务器地址
- **检测内容**：当前系统 DNS 服务器 IP 地址列表
- **益处**：确认 DNS 服务器是否为预期值（如代理软件的 Fake IP 地址）
- **理由**：DNS 是所有网络请求的第一步，DNS 被劫持可导致流量被重定向到恶意服务器；使用代理时 DNS 应由代理软件（如 Surge）统一接管
- **检测命令**：`scutil --dns 2>/dev/null | grep 'nameserver\[0\]' | head -3 | awk '{print $3}' | paste -sd ',' -`

### M3-8：Surge Fake IP DNS
- **检测内容**：DNS 中是否包含 Surge 的 Fake IP 地址（198.18.0.2）
- **益处**：确认 Surge 增强模式（Enhanced Mode）正确接管了 DNS 解析
- **理由**：Surge 增强模式通过 Fake IP 技术将所有 DNS 请求路由到自身，防止 DNS 泄露。此项为 0 说明 Surge 未正确拦截 DNS
- **检测命令**：`scutil --dns 2>/dev/null | grep -c '198.18.0.2'`

### M3-9：IPv6 全局地址数量
- **检测内容**：系统是否存在全局 IPv6 地址（非 fe80 本地链路地址）
- **益处**：防止流量通过 IPv6 直连目标服务器绕过代理（IPv6 泄露）
- **理由**：代理软件通常只代理 IPv4 流量。如果系统有全局 IPv6 地址，支持 IPv6 的服务（Google、Cloudflare 等）会直接使用 IPv6 连接，完全绕过代理出口
- **检测命令**：`ifconfig 2>/dev/null | grep inet6 | grep -v 'fe80\|::1\|%lo' | wc -l | tr -d ' '`
- **期望值**：`0`
- **修复命令**：`sudo networksetup -setv6off 'Wi-Fi'`

### M3-10：Surge Dashboard 端口监听
- **检测内容**：Surge Dashboard 端口（6170）是否在监听（信息类）
- **益处**：确认 Surge 代理软件是否正在运行
- **理由**：Surge 是本工具重度依赖的代理管理软件；6170 端口监听说明 Surge 服务正常运行

### M3-11：Wi-Fi IPv6 状态
- **检测内容**：Wi-Fi 接口 IPv6 配置是否关闭
- **益处**：彻底阻断通过 Wi-Fi 接口的 IPv6 通信，防止代理绕过
- **理由**：即使全局 IPv6 地址不存在，Wi-Fi 仍可能通过路由器广告（RA）自动配置 IPv6。关闭接口级 IPv6 是更彻底的防护
- **检测命令**：`networksetup -getinfo 'Wi-Fi' 2>/dev/null | grep '^IPv6:' | awk '{print $2}'`
- **期望值**：`Off`
- **修复命令**：`sudo networksetup -setv6off 'Wi-Fi'`

### M3-12：Wi-Fi HTTP 代理状态
- **检测内容**：Wi-Fi 接口的系统 HTTP 代理是否已配置
- **益处**：确认系统代理设置是否与代理软件配置一致
- **理由**：系统 HTTP 代理设置影响不使用 HTTPS_PROXY 环境变量的 GUI 应用；代理软件通常会自动设置此项

---

## M8 — 网络内核调优（网络安全模块 C 部分）

> 定位：TCP/IP 内核参数优化，主要针对 AI API 调用场景（高带宽、长连接、低延迟要求），全部计入评分。

### M8-1：TCP 发送缓冲区（net.inet.tcp.sendspace）
- **检测内容**：TCP 发送缓冲区大小（期望 1MB = 1048576 字节）
- **益处**：显著提升大文件传输速度和 Claude Code / AI API 流式响应的吞吐量
- **理由**：macOS 默认 128KB 缓冲区在高延迟代理链路（如跨国代理）下会成为瓶颈，1MB 缓冲区可充分利用可用带宽
- **检测命令**：`sysctl -n net.inet.tcp.sendspace 2>/dev/null || echo 'not set'`
- **期望值**：`1048576`
- **修复命令**：`sudo sysctl -w net.inet.tcp.sendspace=1048576`

### M8-2：TCP 接收缓冲区（net.inet.tcp.recvspace）
- **检测内容**：TCP 接收缓冲区大小（期望 1MB）
- **益处**：改善高延迟网络（代理链路）下的下载吞吐量，减少 AI API 响应接收延迟
- **理由**：接收缓冲区太小在高带宽延迟网络下会频繁触发窗口更新，导致实际吞吐远低于理论值
- **检测命令**：`sysctl -n net.inet.tcp.recvspace 2>/dev/null || echo 'not set'`
- **期望值**：`1048576`
- **修复命令**：`sudo sysctl -w net.inet.tcp.recvspace=1048576`

### M8-3：TCP 自动接收上限（net.inet.tcp.autorcvbufmax）
- **检测内容**：TCP 自动调节接收缓冲区的最大值（期望 32MB）
- **益处**：允许内核在高速连接时自动将接收缓冲区扩大到 32MB，充分利用高带宽
- **理由**：macOS 会根据网络条件自动调节缓冲区，但上限太低会限制高速连接的潜力
- **检测命令**：`sysctl -n net.inet.tcp.autorcvbufmax 2>/dev/null || echo 'not set'`
- **期望值**：`33554432`
- **修复命令**：`sudo sysctl -w net.inet.tcp.autorcvbufmax=33554432`

### M8-4：TCP 自动发送上限（net.inet.tcp.autosndbufmax）
- **检测内容**：TCP 自动调节发送缓冲区的最大值（期望 32MB）
- **益处**：允许内核在上传密集场景（代码推送、大文件上传）时自动扩大发送缓冲区
- **理由**：同 M8-3，发送方缓冲区上限制约了上行吞吐量的上限
- **检测命令**：`sysctl -n net.inet.tcp.autosndbufmax 2>/dev/null || echo 'not set'`
- **期望值**：`33554432`
- **修复命令**：`sudo sysctl -w net.inet.tcp.autosndbufmax=33554432`

### M8-5：TCP 最大报文段大小（net.inet.tcp.mssdflt）
- **检测内容**：TCP MSS 默认值（期望 1460 字节，标准以太网值）
- **益处**：确保 TCP 分段大小与网络 MTU 匹配，避免不必要的 IP 分片开销
- **理由**：MSS = MTU - IP头(20) - TCP头(20)，以太网标准值 1460。使用 VPN/代理时可能需要降至 1360 避免分片
- **检测命令**：`sysctl -n net.inet.tcp.mssdflt 2>/dev/null || echo 'not set'`
- **期望值**：`1460`
- **修复命令**：`sudo sysctl -w net.inet.tcp.mssdflt=1460`

### M8-6：延迟 ACK 禁用（net.inet.tcp.delayed_ack）
- **检测内容**：TCP 延迟 ACK 是否禁用（期望值 0 = 禁用）
- **益处**：降低 Claude Code 流式响应、实时通信的往返时延（RTT）
- **理由**：延迟 ACK 会将 ACK 合并延迟最多 200ms 发送，这对 AI 流式输出等实时性要求高的场景有明显的延迟增加
- **检测命令**：`sysctl -n net.inet.tcp.delayed_ack 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`sudo sysctl -w net.inet.tcp.delayed_ack=0`

### M8-7：Socket 缓冲区总上限（kern.ipc.maxsockbuf）
- **检测内容**：单个 Socket 可使用的最大缓冲区（期望 16MB）
- **益处**：允许单个高性能连接使用更大缓冲区，改善 AI API 大型响应的接收性能
- **理由**：macOS 默认 4MB 上限，在接收大型 AI 模型推理响应（如 Opus 长文本）时成为瓶颈
- **检测命令**：`sysctl -n kern.ipc.maxsockbuf 2>/dev/null || echo 'not set'`
- **期望值**：`16777216`
- **修复命令**：`sudo sysctl -w kern.ipc.maxsockbuf=16777216`

### M8-8：TCP 窗口缩放因子（net.inet.tcp.win_scale_factor）
- **检测内容**：TCP 窗口缩放因子（RFC 1323，期望值 8）
- **益处**：在高带宽高延迟网络（如跨洋代理）中实现最大吞吐量
- **理由**：TCP 原始窗口最大 65535 字节，不足以填满高带宽链路。缩放因子 8 允许窗口扩大到 16MB，适合高延迟代理场景
- **检测命令**：`sysctl -n net.inet.tcp.win_scale_factor 2>/dev/null || echo 'not set'`
- **期望值**：`8`
- **修复命令**：`sudo sysctl -w net.inet.tcp.win_scale_factor=8`

### M8-9：本地网络慢启动窗口（net.inet.tcp.local_slowstart_flightsize）
- **检测内容**：本地网络 TCP 慢启动初始拥塞窗口（期望 20 数据包）
- **益处**：加快局域网内（如 NAS、本地 Docker）数据传输的初始速度
- **理由**：默认值太小导致局域网传输初始阶段速度缓慢，提高至 20 可以在可靠的局域网环境中更快达到最大速率
- **检测命令**：`sysctl -n net.inet.tcp.local_slowstart_flightsize 2>/dev/null || echo 'not set'`
- **期望值**：`20`
- **修复命令**：`sudo sysctl -w net.inet.tcp.local_slowstart_flightsize=20`

### M8-10：SACK 选择性确认（net.inet.tcp.sack）
- **检测内容**：TCP 选择性确认（SACK，RFC 2018）是否启用
- **益处**：丢包重传更精准，只重传丢失的数据包，不重传已收到的数据包，大幅提升丢包场景下的性能
- **理由**：代理链路通常比直连有更高丢包率，SACK 让丢包恢复效率提升数倍
- **检测命令**：`sysctl -n net.inet.tcp.sack 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`sudo sysctl -w net.inet.tcp.sack=1`

### M8-11：TCP 保活探测（net.inet.tcp.always_keepalive）
- **检测内容**：是否对所有 TCP 连接启用保活探测（期望 1 = 开启）
- **益处**：防止 Claude Code MCP 长连接、SSH 连接被防火墙/NAT 因空闲超时静默断开
- **理由**：代理和 NAT 设备通常对空闲连接设有超时（30-60 分钟），保活探测定期发送心跳包维持连接状态
- **检测命令**：`sysctl -n net.inet.tcp.always_keepalive 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`sudo sysctl -w net.inet.tcp.always_keepalive=1`

### M8-12：TCP MSL 时间（net.inet.tcp.msl）
- **检测内容**：TCP 最大报文生存时间（MSL，期望 5000ms）
- **益处**：加快 TIME_WAIT 状态回收，减少端口占用，改善高并发短连接场景（如 API 频繁调用）
- **理由**：默认 15 秒 MSL 意味着每个关闭的连接的端口被占用 30 秒（2×MSL），在密集 API 调用时可能耗尽可用端口
- **检测命令**：`sysctl -n net.inet.tcp.msl 2>/dev/null || echo 'not set'`
- **期望值**：`5000`
- **修复命令**：`sudo sysctl -w net.inet.tcp.msl=5000`

### M8-13：TCP 黑洞模式（net.inet.tcp.blackhole）
- **检测内容**：对未监听端口的 TCP 连接是否静默丢弃（期望值 2 = 完全黑洞）
- **益处**：防止端口扫描工具通过 RST 响应探测本机开放端口
- **理由**：标准行为是向未监听端口发送 RST，攻击者可据此推断端口状态；黑洞模式不响应，让扫描器无法区分"关闭"和"过滤"
- **检测命令**：`sysctl -n net.inet.tcp.blackhole 2>/dev/null || echo 'not set'`
- **期望值**：`2`
- **修复命令**：`sudo sysctl -w net.inet.tcp.blackhole=2`

### M8-14：UDP 黑洞模式（net.inet.udp.blackhole）
- **检测内容**：对未监听端口的 UDP 数据包是否静默丢弃（期望值 1）
- **益处**：防止 UDP 端口扫描
- **理由**：与 TCP 黑洞同理，UDP 黑洞防止通过 ICMP Port Unreachable 响应探测 UDP 端口状态
- **检测命令**：`sysctl -n net.inet.udp.blackhole 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`sudo sysctl -w net.inet.udp.blackhole=1`

### M8-15：IPv6 路由通告接受（net.inet6.ip6.accept_rtadv）
- **检测内容**：是否禁止接受 IPv6 路由通告（Router Advertisement）
- **益处**：防止路由器广告自动配置 IPv6 路由，从而阻断 IPv6 直连绕过代理出口
- **理由**：IPv6 路由通告是 IPv6 地址自动配置的基础，关闭后网络接口不会自动获得全局 IPv6 地址
- **注意**：此 sysctl 参数在 macOS 上为只读，正确做法是通过 networksetup 关闭接口 IPv6
- **检测命令**：`sysctl -n net.inet6.ip6.accept_rtadv 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`networksetup -listallnetworkservices | ... | sudo networksetup -setv6off "$svc"`

### M8-16：IPv6 数据包转发（net.inet6.ip6.forwarding）
- **检测内容**：IPv6 数据包转发功能是否禁用（期望值 0）
- **益处**：防止本机成为 IPv6 网络中继节点
- **理由**：普通工作站不应启用 IPv6 转发，否则可能被利用为网络跳板，将流量从一个接口转发到另一个接口
- **注意**：同上，macOS 上只读 sysctl，需通过 networksetup 管理
- **检测命令**：`sysctl -n net.inet6.ip6.forwarding 2>/dev/null || echo 'not set'`
- **期望值**：`0`

### M8-17：sysctl 持久化 plist
- **检测内容**：/Library/LaunchDaemons/com.server.sysctl.plist 是否存在
- **益处**：确保 M8-1 至 M8-14 的所有 sysctl 调优参数在重启后依然生效
- **理由**：sysctl -w 命令只对当前运行时有效，重启后恢复默认值。只有通过 LaunchDaemon 才能实现持久化
- **检测命令**：`test -f /Library/LaunchDaemons/com.server.sysctl.plist && echo 'exists' || echo 'missing'`

---

## M4 — 隐私与遥测模块

> 定位：检测 Apple 系统级遥测和隐私数据采集开关，全部计入评分。

### M4-1：诊断数据自动提交
- **检测内容**：是否禁止自动向 Apple 提交诊断数据（com.apple.SubmitDiagInfo AutoSubmit）
- **益处**：减少个人使用习惯和设备信息上报，防止敏感操作数据泄露给 Apple
- **理由**：诊断数据包含应用崩溃日志、性能数据、使用频率统计，这些数据可能包含文件路径、用户名等个人信息
- **检测命令**：`defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false`

### M4-2：崩溃报告弹窗类型
- **检测内容**：崩溃报告对话框类型是否设为 none（不弹窗）
- **益处**：应用崩溃时不再弹出"向 Apple 发送报告"对话框，避免无意中提交含敏感信息的崩溃日志
- **理由**：崩溃报告包含应用堆栈、本地文件路径、环境变量（可能含 API Keys）等敏感信息
- **检测命令**：`defaults read com.apple.CrashReporter DialogType 2>/dev/null || echo 'not set'`
- **期望值**：`none`
- **修复命令**：`defaults write com.apple.CrashReporter DialogType -string none`

### M4-3：Siri 主开关
- **检测内容**：Siri 助手是否完全禁用（Assistant Enabled = 0）
- **益处**：Siri 不再在后台监听语音、不将查询发送到 Apple 服务器、不建立个人化数据档案
- **理由**：Siri 会将语音片段上传到 Apple 服务器进行处理和改进，对隐私敏感的工作场合应完全禁用
- **检测命令**：`defaults read com.apple.assistant.support 'Assistant Enabled' 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.assistant.support 'Assistant Enabled' -bool false`

### M4-4：Siri 数据共享
- **检测内容**：Siri 学习数据共享是否关闭（Siri Data Sharing Opt-In Status = 0）
- **益处**：即使使用 Siri，也不将使用数据用于 Apple 模型训练
- **理由**：Siri 数据共享将语音样本和搜索历史用于改进 Apple 的 AI 模型，属于用户行为数据的主动贡献
- **检测命令**：`defaults read com.apple.assistant.support 'Siri Data Sharing Opt-In Status' 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.assistant.support 'Siri Data Sharing Opt-In Status' -int 0`

### M4-5：Siri 菜单栏图标
- **检测内容**：Siri 图标是否从菜单栏隐藏（StatusMenuVisible = 0）
- **益处**：减少误触发 Siri 的概率；菜单栏更简洁
- **理由**：菜单栏 Siri 图标容易被误触发，特别是在键盘快捷键操作时
- **检测命令**：`defaults read com.apple.Siri StatusMenuVisible 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.Siri StatusMenuVisible -bool false`

### M4-6：Apple 个性化广告
- **检测内容**：是否禁止 Apple 基于设备行为投放个性化广告
- **益处**：不被 Apple 广告系统追踪和分类，App Store 等平台广告不再基于个人行为定制
- **理由**：Apple 通过 IDFA（设备广告标识符）追踪应用内行为，关闭后广告系统无法建立个人化档案
- **检测命令**：`defaults read com.apple.AdLib allowApplePersonalizedAdvertising 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false`

### M4-7：iCloud 使用追踪（CoreDonations）
- **检测内容**：是否禁止 iCloud 使用频率统计数据上报（CoreDonationsEnabled = 0）
- **益处**：减少设备使用习惯上报到 iCloud 服务器
- **理由**：CoreDonations 机制统计用户使用各功能的频率和时间，用于 Apple 产品改进，属于行为追踪
- **检测命令**：`defaults read com.apple.UsageTracking CoreDonationsEnabled 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false`

### M4-8：iCloud UDC 自动化追踪
- **检测内容**：是否禁止 iCloud 用户数据收集（UDC）自动化（UDCAutomationEnabled = 0）
- **益处**：与 M4-7 配合，进一步减少 iCloud 的行为数据采集
- **理由**：UDC 是 Apple 更广泛的用户数据收集框架的一部分
- **检测命令**：`defaults read com.apple.UsageTracking UDCAutomationEnabled 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false`

### M4-9：mDNS 多播广告
- **检测内容**：是否禁止 mDNS 多播广告（NoMulticastAdvertisements = 1）
- **益处**：本机不在局域网内广播主机名、设备名称和运行中的服务，减少网络身份暴露
- **理由**：mDNS 通过多播（224.0.0.251:5353）广播设备存在，局域网内任何设备都可看到你的 MacBook 名称和开放服务
- **检测命令**：`defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements 2>/dev/null || echo '0'`
- **期望值**：`1`
- **修复命令**：`sudo defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements -bool true && sudo launchctl stop com.apple.mDNSResponder && sudo launchctl start com.apple.mDNSResponder`

### M4-10：Captive Portal 自动检测
- **检测内容**：是否禁用 Captive Portal 自动弹窗（连接 Wi-Fi 时的强制门户检测）
- **益处**：防止连接网络时自动触发 HTTP 请求（未走代理），泄露真实 IP 和设备信息
- **理由**：Captive Portal 检测会向固定 URL 发送 HTTP 请求，在代理未启动时这个请求直连目标，暴露真实 IP 和系统标识
- **检测命令**：`scutil --get ComputerName 2>/dev/null && defaults read /Library/Preferences/SystemConfiguration/CaptiveNetworkSupport Active 2>/dev/null || echo 'not set'`

### M4-11：网络卷 .DS_Store 文件写入
- **检测内容**：是否禁止在网络存储卷上写入 .DS_Store 文件（DSDontWriteNetworkStores = 1）
- **益处**：不在 NAS、服务器、共享网盘上留下 macOS 文件夹元数据；避免 .DS_Store 向他人泄露目录结构
- **理由**：.DS_Store 文件记录文件夹的图标位置、背景图、窗口大小，在共享网络存储上会被其他用户看到，也可能被 Web 服务器公开暴露
- **检测命令**：`defaults read com.apple.desktopservices DSDontWriteNetworkStores 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true`

### M4-12：USB 卷 .DS_Store 文件写入
- **检测内容**：是否禁止在 USB 存储设备上写入 .DS_Store 文件（DSDontWriteUSBStores = 1）
- **益处**：U 盘在其他操作系统（Windows/Linux）上不会显示无用的 macOS 系统文件
- **理由**：分享 U 盘时 .DS_Store 文件会暴露 macOS 环境信息和目录结构，影响文件分享的专业性
- **检测命令**：`defaults read com.apple.desktopservices DSDontWriteUSBStores 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true`

### M4-13：AirDrop 状态
- **检测内容**：是否禁用 AirDrop（DisableAirDrop = 1）
- **益处**：防止局域网/蓝牙范围内的设备发现本机并发送文件
- **理由**：AirDrop 使本机在一定范围内可被发现，有研究证明可利用 AirDrop 的 BTLE 协议进行设备追踪；不需要时应关闭
- **检测命令**：`defaults read com.apple.NetworkBrowser DisableAirDrop 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`defaults write com.apple.NetworkBrowser DisableAirDrop -bool true`

### M4-14：照片面部识别分析
- **检测内容**：是否禁用照片库 AI 分析（面部识别、场景识别）
- **益处**：减少后台 CPU 占用；避免本机存储面部识别数据
- **理由**：照片分析在后台持续运行，处理大型照片库时显著消耗 CPU，影响 AI 推理任务的性能
- **检测命令**：`defaults read com.apple.photoanalysisd enabled 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.photoanalysisd enabled -bool false`

### M4-15：Safari 网络搜索
- **检测内容**：是否禁止 Safari 地址栏内容发送到 Apple（UniversalSearchEnabled = 0）
- **益处**：地址栏输入内容不实时发送到 Apple 服务器，防止搜索内容泄露
- **理由**：Safari 默认将地址栏输入实时发送到 Apple 以提供建议，这意味着每次输入 URL 和搜索词都被上传
- **检测命令**：`defaults read com.apple.Safari UniversalSearchEnabled 2>/dev/null || echo 'not set'`
- **期望值**：`0`
- **修复命令**：`defaults write com.apple.Safari UniversalSearchEnabled -bool false`

### M4-16：Safari 搜索建议
- **检测内容**：是否抑制 Safari 搜索建议（SuppressSearchSuggestions = 1）
- **益处**：减少搜索关键词实时上传到 Apple/Bing 等搜索引擎服务器
- **理由**：搜索建议功能每次按键都向服务器发送查询，即使不回车提交，输入的内容已被记录
- **检测命令**：`defaults read com.apple.Safari SuppressSearchSuggestions 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`defaults write com.apple.Safari SuppressSearchSuggestions -bool true`

### M4-17：Spotlight 搜索建议
- **检测内容**：是否禁用 Spotlight 网络搜索建议（LookupSuggestionsDisabled = 1）
- **益处**：本地文件搜索不再同时向 Apple 服务器发送查询，防止文件名和搜索意图泄露
- **理由**：Spotlight 默认将搜索词发送到 Apple 服务器以提供 Siri 知识和 Web 建议，即使你只是搜索本地文件
- **检测命令**：`defaults read com.apple.lookup.shared LookupSuggestionsDisabled 2>/dev/null || echo 'not set'`
- **期望值**：`1`
- **修复命令**：`defaults write com.apple.lookup.shared LookupSuggestionsDisabled -bool true`

---

## M5 — 视觉动画优化模块

> 定位：macOS defaults 参数调优，43 项检测，不计入评分（建议类）。分为通用动画、Dock 优化、Finder、Sequoia/Tahoe 专属、系统行为五大类。

### M5-A：通用动画与交互优化（16 项）

#### M5-1：窗口动画（NSAutomaticWindowAnimationsEnabled）
- **检测内容**：窗口自动展开/收起动画是否禁用
- **益处**：Sheets、Popovers、下拉面板立即响应，无滑入延迟
- **理由**：窗口动画是 macOS 最常见的 UI 延迟来源，对高频使用开发工具的用户影响显著

#### M5-2：窗口缩放速度（NSWindowResizeTime）
- **检测内容**：窗口大小调整动画时间（期望 0.001 秒）
- **益处**：拖拽调整窗口大小几乎即时完成
- **理由**：默认 0.2 秒的动画在调整多个窗口布局时造成累积的感知延迟

#### M5-3：全屏工具栏动画（NSToolbarFullScreenAnimationDuration）
- **检测内容**：进入/退出全屏时工具栏动画时间（期望 0 秒）
- **益处**：全屏切换即时完成，提升多窗口工作流效率
- **理由**：频繁在全屏和窗口模式间切换（如 VSCode ↔ Terminal）时，动画延迟造成明显的工作流中断感

#### M5-4：文档版本动画
- **检测内容**：文档版本历史的 3D 翻转动画（期望禁用）
- **益处**：直接显示版本列表，无 3D 动画过渡
- **理由**：3D 翻转动画是视觉特效，对功能没有实际意义，仅增加等待时间

#### M5-5：Finder 列视图动画
- **检测内容**：Finder 列视图切换时的列滑入动画倍率（期望 0 = 禁用）
- **益处**：Finder 列导航立即响应，大型目录树浏览更流畅
- **理由**：Finder 是开发者使用频率最高的系统应用之一，每次导航都有动画延迟会显著降低效率

#### M5-6：滚动动画（NSScrollAnimationEnabled）
- **检测内容**：按 Home/End 键时的平滑滚动动画（期望禁用）
- **益处**：跳转到文档顶部/底部立即到位，无过渡动画
- **理由**：在代码编辑器中频繁跳转时，滚动动画打断视线焦点

#### M5-7：橡皮筋回弹（NSScrollViewRubberbanding）
- **检测内容**：滚动超出内容边界时的弹性回弹动画（期望禁用）
- **益处**：减少误操作感和晕屏感，节省 GPU 渲染资源
- **理由**：回弹动画在触控板快速滑动时容易产生，对不需要此 iOS 风格效果的用户是纯干扰

#### M5-8：Quick Look 动画（QLPanelAnimationDuration）
- **检测内容**：按空格键触发 Quick Look 的淡入/淡出时间（期望 0 秒）
- **益处**：文件预览即时显示和关闭
- **理由**：快速浏览大量文件时（如审查设计稿、截图），动画延迟在每次预览时积累

#### M5-9：工具提示延迟（NSInitialToolTipDelay）
- **检测内容**：鼠标悬停显示 Tooltip 的等待时间（期望 0 毫秒）
- **益处**：立即显示工具提示，提高界面探索效率
- **理由**：默认 750ms 延迟让不熟悉界面的用户需要长时间等待才能看到功能说明

#### M5-10：弹簧加载延迟（com.apple.springing.delay）
- **检测内容**：拖拽到文件夹时自动弹出内容的等待时间（期望 0 秒）
- **益处**：拖拽文件整理时，目标文件夹立即弹开
- **理由**：开发者整理文件时频繁需要拖拽到多级嵌套文件夹，延迟使操作效率大幅下降

#### M5-11：App Nap 禁用（NSAppSleepDisabled）
- **检测内容**：是否禁止系统对后台不活跃应用降低优先级（期望 1 = 禁用 App Nap）
- **益处**：Ollama 服务、Claude Code 后台任务、MCP 服务器等 AI 工具不会被意外暂停
- **理由**：App Nap 会将后台应用降频或暂停，Ollama 模型推理服务被暂停后首次请求有几秒延迟
- **重要性**：⚠ AI 工具用户的关键配置

#### M5-12：键盘重复速度（KeyRepeat）
- **检测内容**：按住按键后的重复触发速率（期望 1 = 最快）
- **益处**：Vim 键位导航、代码编辑中的光标移动明显更快
- **理由**：macOS 默认键盘重复率对开发者偏慢，特别是使用 hjkl 风格导航时需要快速移动光标

#### M5-13：键盘重复延迟（InitialKeyRepeat）
- **检测内容**：按住按键触发重复输入的初始延迟（期望 10 = 最短）
- **益处**：减少开始重复输入前的等待感
- **理由**：初始延迟偏长导致按住键后感觉反应迟钝

#### M5-14：减少动态效果（reduceMotion）
- **检测内容**：是否启用系统级减少动画模式（受 TCC 保护，需手动设置）
- **益处**：全屏切换、通知弹出等大幅动画变为交叉淡化，视觉疲劳降低；低端 GPU 场景性能提升
- **理由**：macOS 的动画特效对集成 GPU 有持续渲染压力，AI 密集工作时 GPU 资源应优先用于计算
- **注意**：命令行无法修改，需在系统设置 → 辅助功能 → 显示 中开启

#### M5-15：减少透明度（reduceTransparency）
- **检测内容**：是否关闭菜单栏、Dock、侧边栏的毛玻璃效果（受 TCC 保护，需手动设置）
- **益处**：显著降低 GPU 连续渲染负担；界面纯色背景文字对比度更高
- **理由**：毛玻璃效果需要 GPU 持续渲染背景模糊，在运行 Ollama 推理时会与 AI 任务竞争 GPU
- **注意**：命令行无法修改，需在系统设置 → 辅助功能 → 显示 中开启

### M5-B：Dock 优化（11 项）

#### M5-16：Dock 隐藏延迟（autohide-delay）
- **检测内容**：鼠标移到 Dock 区域触发显示的延迟（期望 0 秒）
- **益处**：Dock 立即弹出，不需要在边缘等待

#### M5-17：Dock 隐藏动画（autohide-time-modifier）
- **检测内容**：Dock 滑入/滑出动画时间（期望 0 = 无动画）
- **益处**：Dock 出入无动画，屏幕空间切换即时完成

#### M5-18：应用启动弹跳动画（launchanim）
- **检测内容**：点击 Dock 启动应用时的弹跳动画（期望 0 = 禁用）
- **益处**：点击后应用安静启动，无烦人的图标弹跳干扰

#### M5-19：Dock 图标放大效果（magnification）
- **检测内容**：Dock 图标悬停放大（期望 0 = 禁用）
- **益处**：节省 GPU 资源，避免 Dock 区域的视觉抖动

#### M5-20：Mission Control 动画速度（expose-animation-duration）
- **检测内容**：Mission Control 展开动画时间（期望 0.1 秒）
- **益处**：三指上滑显示所有窗口的速度明显加快

#### M5-21~24：Launchpad 动画（springboard-show/hide/page-duration）
- **检测内容**：Launchpad 打开、关闭、翻页动画时间（期望 0 秒）
- **益处**：Launchpad 所有动画即时完成

#### M5-25：最小化效果（mineffect = scale）
- **检测内容**：窗口最小化到 Dock 的动画效果（期望 scale，而非 genie）
- **益处**：scale 效果比 genie 精灵灯效果执行更快、GPU 消耗更小

#### M5-26：Dock 图标尺寸（tilesize = 36）
- **检测内容**：Dock 图标像素大小（期望 36px）
- **益处**：更紧凑的 Dock 在屏幕上留出更多工作空间

#### M5-27：隐藏最近使用应用区域（show-recents = 0）
- **检测内容**：Dock 末尾最近使用应用分区（期望隐藏）
- **益处**：Dock 只显示手动固定的应用，更整洁；减少动态区域带来的视觉不稳定

#### M5-28~31：热角禁用（wvous-tl/tr/bl/br-corner = 0）
- **检测内容**：四个屏幕角的热角触发功能（期望全部禁用）
- **益处**：防止鼠标移到屏幕角时意外触发 Mission Control、睡眠、锁屏等操作
- **理由**：开发者使用外接鼠标时极易误触热角，造成工作流中断

### M5-C：Finder 与系统行为优化（7 项）

#### M5-32：Finder 动画（DisableAllAnimations）
- **检测内容**：Finder 内所有动画（期望禁用）
- **益处**：文件操作全部立即响应，Finder 更像专业工具而非演示软件

#### M5-33：应用隔离确认弹窗（LSQuarantine）
- **检测内容**：下载应用首次运行的安全确认弹窗（期望禁用，适合开发测试场景）
- **益处**：开发测试时频繁安装未公证应用无需反复点确认
- **理由**：⚠ 安全注意：禁用后需自行判断应用来源可信度，仅推荐开发测试环境使用

#### M5-34：Time Machine 新磁盘提示（DoNotOfferNewDisksForBackup）
- **检测内容**：插入外置磁盘时是否弹出 Time Machine 询问（期望禁用）
- **益处**：插入 U 盘不再被 Time Machine 提示打断

#### M5-35：NowPlaying 菜单栏图标隐藏
- **检测内容**：菜单栏正在播放媒体控件（期望隐藏）
- **益处**：节省菜单栏空间，减少视觉干扰

#### M5-36：文件扩展名显示（AppleShowAllExtensions）
- **检测内容**：是否始终显示文件扩展名（期望显示）
- **益处**：防止双扩展名攻击（如 photo.jpg.app 显示为 photo.jpg 诱使点击）
- **理由**：安全价值：恶意文件常使用双扩展名伪装，显示扩展名可有效识别

#### M5-37：文件夹优先排序（_FXSortFoldersFirst）
- **检测内容**：Finder 排序时文件夹是否置顶（期望 1 = 是）
- **益处**：目录导航更直观，符合大多数开发者的文件管理习惯

#### M5-38：截图阴影禁用（disable-shadow）
- **检测内容**：截图窗口时是否包含阴影（期望禁用）
- **益处**：截图文件更小；边缘干净，无半透明白边，适合直接用于文档和分享

#### M5-39：屏保空闲时间（idleTime = 0）
- **检测内容**：屏保启动前的空闲时间（期望 0 = 不启动屏保）
- **益处**：开发机/服务器不会因屏保中断长时间运行的 AI 推理、构建任务

#### M5-40：截图格式（type = png）
- **检测内容**：系统截图保存格式（期望 png = 无损）
- **益处**：截图质量最高，适合后续编辑和分享

### M5-D：Sequoia 专属优化（2 项）

#### M5-41：焦点环动画（NSUseAnimatedFocusRing，Sequoia 专属）
- **检测内容**：键盘焦点指示器的缩放动画（期望禁用）
- **益处**：焦点环立即显示，无缩放过渡

#### M5-42：禁止自动终止（NSDisableAutomaticTermination，Sequoia 专属）
- **检测内容**：是否禁止 macOS 在内存紧张时自动终止后台暂停的应用
- **益处**：Ollama、MCP 服务器等 AI 后台服务不会被系统意外终止
- **理由**：⚠ Sequoia 重要：Apple Intelligence 占用大量内存，Automatic Termination 机制在 Sequoia 下更积极

### M5-E：Tahoe 专属优化（2 项）

#### M5-43：Liquid Glass 模糊（reduceBlurring，Tahoe 专属）
- **检测内容**：是否减少 Tahoe 的 Liquid Glass 动态毛玻璃效果
- **益处**：明显降低 GPU 连续渲染负担；电池寿命改善约 5-15%
- **理由**：Liquid Glass 是 macOS 26 Tahoe 的核心视觉设计，但其动态模糊效果对 GPU 有持续压力

#### M5-44：Stage Manager 点击桌面行为（Tahoe 专属）
- **检测内容**：在 Stage Manager 模式下点击桌面是否隐藏所有窗口（期望禁用）
- **益处**：防止在 Tahoe 的透明界面中误点桌面区域触发 Show Desktop

### M5-E：软件更新控制（2 项）

#### M5-45：自动下载更新（AutomaticDownload = 0）
- **检测内容**：macOS 是否在后台自动下载更新（期望禁用）
- **益处**：自行控制更新时机，防止大型更新下载占用带宽影响 AI API 调用速度

#### M5-46：自动安装更新（AutomaticallyInstallMacOSUpdates = 0）
- **检测内容**：macOS 是否自动安装并重启（期望禁用）
- **益处**：防止系统在运行 AI 推理、构建任务时意外重启，造成工作丢失

---

## M6 — 服务状态模块

> 定位：检测 ~70 个 launchd 用户服务是否被禁用，不计入评分（建议类）。分 7 大分组。

### M6 总体说明
- **检测逻辑**：通过 `launchctl print-disabled gui/$(id -u)` 一次性获取所有服务的禁用状态，对比每个服务是否 `disabled=true`
- **期望状态**：所有列出的服务均为 `disabled`（true）
- **修复模式**：`launchctl disable gui/$(id -u)/<service> && launchctl bootout gui/$(id -u)/<service>`
- **益处通用**：禁用不需要的后台服务可减少 CPU/内存占用，减少数据采集，降低攻击面

### M6-A 组：Siri/AI 类服务（22 项）
> 这些服务支撑 Apple Siri 和 Apple Intelligence 功能，对不使用这些功能的用户全部可安全禁用

| 服务名 | 功能 | 禁用益处 |
|--------|------|---------|
| com.apple.assistant_service | Siri 核心请求处理 | 停止响应语音指令，节省 CPU |
| com.apple.assistantd | Siri 后台守护进程 | 终止常驻内存进程，释放 RAM |
| com.apple.assistant_cdmd | Siri 多设备上下文匹配 | 停止跨设备数据同步 |
| com.apple.Siri.agent | 响应"嘿 Siri"唤醒词 | 停止麦克风持续监听 |
| com.apple.siriactionsd | Siri 快捷指令动作执行引擎 | 减少后台任务调度 |
| com.apple.siriinferenced | 预测用户下一步操作的意图引擎 | 停止行为预测数据采集 |
| com.apple.sirittsd | Siri 语音合成（TTS） | 停止不需要的 TTS 后台服务 |
| com.apple.SiriTTSTrainingAgent | 收集语音样本改善 Siri | ⚠ 停止语音样本采集上报 |
| com.apple.siriknowledged | 存储个人化 Siri 上下文 | 停止个人数据本地存储和同步 |
| com.apple.parsec-fbf | 联邦学习框架（本地 AI 训练） | ⚠ 停止本地 ML 训练任务占用 GPU |
| com.apple.parsecd | 自然语言解析 | 停止后台 NLP 处理 |
| com.apple.intelligenceflowd | Apple Intelligence 流程调度（Sequoia+） | 禁用 Apple AI 特性 |
| com.apple.intelligencecontextd | Apple Intelligence 上下文感知（Sequoia+） | 停止上下文数据采集 |
| com.apple.intelligenceplatformd | Apple Intelligence 平台基础服务（Sequoia+） | 禁用 Apple AI 平台 |
| com.apple.knowledgeconstructiond | 从行为构建本地知识图谱（Sequoia+） | 停止行为知识图谱构建 |
| com.apple.generativeexperiencesd | 生成式 AI 功能体验（Sequoia+） | 禁用 Apple 生成式 AI 功能 |
| com.apple.knowledge-agent | 个人知识索引（Spotlight 支撑） | 停止个人知识库索引 |
| com.apple.suggestd | Siri 建议推送 | 停止各处的预测性内容推送 |
| com.apple.naturallanguaged | 系统级自然语言处理后台 | 停止后台 NLP 服务 |
| com.apple.proactived | 主动式 Siri 建议（Sequoia+） | 停止主动推送引擎 |
| com.apple.milod | 机器学习模型本地推理优化（Sequoia+） | 停止不需要的 ML 推理服务 |
| com.apple.corespeechd | 核心语音识别框架（Sequoia+） | 停止语音识别后台守护进程 |

### M6-B 组：媒体/娱乐类服务（13 项）
> 适用于不使用 Apple 媒体服务的用户

| 服务名 | 功能 | 禁用益处 |
|--------|------|---------|
| com.apple.watchlistd | Apple TV 想看列表同步 | 停止视频服务后台同步 |
| com.apple.gamed | Game Center 游戏成就 | 游戏相关服务，纯开发机可禁用 |
| com.apple.voicebankingd | 辅助功能个性化语音库 | 停止辅助语音服务 |
| com.apple.newsd | Apple News 后台刷新 | 停止新闻内容定期抓取 |
| com.apple.weatherd | 系统天气数据获取 | 停止位置+天气数据请求 |
| com.apple.tipsd | macOS 使用技巧推送 | 停止不需要的系统通知 |
| com.apple.financed | Apple 股票/金融数据同步 | 停止金融数据后台请求 |
| com.apple.mediaanalysisd | 媒体文件内容分析 | 停止音视频文件 AI 扫描占用 CPU |
| com.apple.shazamd | Shazam 音乐识别（Sequoia+） | 停止麦克风监听和音乐识别 |
| com.apple.sportsd | Apple 体育赛事数据（Sequoia+） | 停止体育数据后台同步 |
| com.apple.homeenergyd | 家庭能源管理（Sequoia+） | 停止电价感知数据请求 |
| com.apple.translationd | 系统翻译语言包下载（Sequoia+） | 停止后台语言包更新 |
| com.apple.AMPDownloadAgent | Apple Music 后台下载 | 停止音乐离线下载任务 |

### M6-C 组：照片/地图/社交类（9 项）
> 适用于不使用 Apple 地图和照片同步的用户

| 服务名 | 功能 | 禁用益处 |
|--------|------|---------|
| com.apple.photoanalysisd | 照片 AI 分析（人物/场景识别） | ⚠ 停止 AI 扫描和 GPU/CPU 占用 |
| com.apple.Maps.pushdaemon | 地图路况推送通知 | 停止位置相关推送 |
| com.apple.Maps.mapssyncd | 地图收藏 iCloud 同步 | 停止地图历史数据同步 |
| com.apple.maps.destinationd | 目的地预测与路线缓存 | 停止位置行为预测 |
| com.apple.navd | 导航引擎后台路线计算 | 停止不需要的后台导航 |
| com.apple.geodMachServiceBridge | 地理位置服务 Mach 桥接 | 减少位置服务调用 |
| com.apple.geoanalyticsd | 位置使用行为统计上报 | ⚠ 停止位置行为数据上报 |
| com.apple.imautomatichistorydeletionagent | iMessage 消息自动删除 | 停止消息自动清理任务 |
| com.apple.GameController.gamecontrollerd | 游戏手柄驱动 | 无游戏手柄时可禁用 |

### M6-D 组：iCloud/家庭类（9 项）
> 适用于不使用家庭共享功能的用户

| 服务名 | 功能 | 禁用益处 |
|--------|------|---------|
| com.apple.iCloudNotificationAgent | iCloud 变更推送接收 | 减少 iCloud 轮询 |
| com.apple.iCloudUserNotifications | iCloud 用户通知展示 | 减少 iCloud 通知 |
| com.apple.familycircled | 家人共享圈位置共享 | 停止位置数据共享 |
| com.apple.familycontrols.useragent | 家长控制策略执行 | 无子女设备时可禁用 |
| com.apple.familynotificationd | 家人共享变更通知 | 停止家庭通知 |
| com.apple.ScreenTimeAgent | 屏幕使用时间统计 | 停止使用时间追踪 |
| com.apple.macos.studentd | 课堂 App 学生端管理 | 非学生设备可禁用 |
| com.apple.progressd | 学习进度追踪上报 | 停止学习数据上报 |
| com.apple.TMHelperAgent | Time Machine 备份监控 | 不使用 Time Machine 时禁用 |

### M6-E 组：遥测/分析类（15 项）
> ⚠ 最重要的隐私保护分组，强烈建议全部禁用

| 服务名 | 功能 | 禁用益处 |
|--------|------|---------|
| com.apple.UsageTrackingAgent | 追踪 App 使用频率上报 Apple | ⚠ 停止使用行为上报 |
| com.apple.BiomeAgent | 用户行为生物特征数据采集 | ⚠ 停止生物特征采集 |
| com.apple.biomesyncd | 生物行为数据跨设备同步 | 停止行为数据同步 |
| com.apple.inputanalyticsd | 键盘输入习惯分析采集 | ⚠ 停止键盘行为采集 |
| com.apple.ap.adprivacyd | 广告隐私归因处理 | 停止广告追踪基础服务 |
| com.apple.ap.promotedcontentd | App Store 推广内容个性化 | 停止个性化广告推送 |
| com.apple.triald | A/B 测试框架（实验功能分发） | 停止成为 Apple 测试实验对象 |
| com.apple.routined | 学习日常作息规律供 Siri 预测 | ⚠ 停止生活作息模式追踪 |
| com.apple.duetexpertd | AI 专家系统优化建议 | 停止 AI 使用优化采集 |
| com.apple.ContextStoreAgent | 用户活动上下文存储 | 停止上下文行为记录 |
| com.apple.analyticsd | 系统诊断数据采集上报 | ⚠ 停止系统诊断上报 |
| com.apple.ecosystemanalyticsd | Apple 生态系统跨设备使用分析 | 停止多设备使用分析 |
| com.apple.audioanalyticsd | 麦克风与音频环境分析 | ⚠ 停止麦克风环境采集 |
| com.apple.wifianalyticsd | Wi-Fi 连接质量行为统计 | 停止网络使用统计 |
| com.apple.biomed | 健康传感器数据采集 | 停止健康数据采集 |
| com.apple.triald.system | 系统级 A/B 测试框架 | 停止系统级实验分发 |

### M6-F 组：共享/Handoff 类（7 项）
> 适用于不使用屏幕共享和设备接力的用户

| 服务名 | 功能 | 禁用益处 |
|--------|------|---------|
| com.apple.screensharing.agent | 屏幕共享代理 | 停止响应远程屏幕共享请求 |
| com.apple.screensharing.menuextra | 屏幕共享菜单栏图标 | 移除菜单栏图标 |
| com.apple.screensharing.MessagesAgent | iMessage 发起屏幕共享 | 停止通过消息触发屏幕共享 |
| com.apple.replicatord | 设备间内容复制同步 | 停止跨设备剪贴板同步 |
| com.apple.helpd | macOS 帮助查看器 | 停止不常用的帮助服务 |
| com.apple.followupd | 跨设备任务接力（Handoff） | 停止设备间接力功能 |
| com.apple.icloud.searchpartyuseragent | "查找"网络设备定位代理 | 停止参与查找网络数据上报 |

---

## M7 — 电源配置模块

> 定位：pmset 电源管理参数优化，针对长时间运行 AI 任务的"服务器模式"配置，全部计入评分。

### M7-1：接电-系统休眠（sleep = 0）
- **检测内容**：接电时系统自动休眠延迟（期望 0 = 永不休眠）
- **益处**：AI 推理、模型训练、SSH 任务不会因系统休眠中断
- **理由**：AI 训练任务常运行数小时，系统休眠会直接终止进程，所有进度丢失
- **修复命令**：`sudo pmset -c sleep 0`

### M7-2：接电-磁盘休眠（disksleep = 0）
- **检测内容**：接电时磁盘自动休眠延迟（期望 0 = 禁用）
- **益处**：防止磁盘休眠带来的数据库访问延迟（SSD 唤醒仍需几百毫秒）
- **理由**：Ollama 模型文件存储在磁盘，磁盘休眠后首次模型加载有明显延迟
- **修复命令**：`sudo pmset -c disksleep 0`

### M7-3：接电-显示器关闭（displaysleep = 10）
- **检测内容**：接电时显示器关闭延迟（期望 10 分钟）
- **益处**：10 分钟空闲后自动关闭显示器节省电力，不干扰工作
- **修复命令**：`sudo pmset -c displaysleep 10`

### M7-4：接电-待机模式（standby = 0）
- **检测内容**：接电时进入深度待机（Standby）的延迟（期望 0 = 禁用待机）
- **益处**：防止系统进入 Standby（将内存写入磁盘并断电），恢复时间长达数十秒
- **理由**：Standby 本为省电设计，接电时无需省电，禁用后系统响应更快
- **修复命令**：`sudo pmset -c standby 0`

### M7-5：接电-Power Nap（powernap = 0）
- **检测内容**：接电时 Power Nap 后台唤醒（期望 0 = 禁用）
- **益处**：系统休眠期间不会定期唤醒处理邮件/iCloud 同步，节省资源
- **修复命令**：`sudo pmset -c powernap 0`

### M7-6：接电-节能模式（lowpowermode = 0）
- **检测内容**：接电时低功耗模式（期望 0 = 全功率）
- **益处**：接电时 CPU/GPU 全功率运行，AI 推理速度最快
- **理由**：低功耗模式会降频，接电时无需节能，AI 任务应全功率运行
- **修复命令**：`sudo pmset -c lowpowermode 0`

### M7-7~11：电池配置（笔记本专属，5 项）
- **检测内容**：电池供电时的休眠、磁盘、显示器、待机、Power Nap 配置
- **益处**：笔记本用作移动服务器时合盖任务不中断
- **理由**：开发者用笔记本当服务器运行 AI 任务时，电池配置直接影响任务连续性

### M7-12：断电自动重启（autorestart = 1）
- **检测内容**：断电恢复后是否自动重启（期望 1 = 是）
- **益处**：短暂停电后 Mac 自动恢复，服务自动继续运行
- **理由**：服务器场景必须配置，否则停电后机器不会自动开机，所有服务都需要手动恢复
- **修复命令**：`sudo pmset -a autorestart 1`

### M7-13：网络唤醒（womp = 1）
- **检测内容**：是否允许通过 Magic Packet 远程唤醒本机（期望 1 = 开启）
- **益处**：可通过局域网远程唤醒关机/睡眠中的 Mac，方便远程管理
- **修复命令**：`sudo pmset -a womp 1`

### M7-14：SMS 突发唤醒（sms = 0）
- **检测内容**：突发数据唤醒（Sudden Motion Sensor）是否关闭（期望 0）
- **益处**：SSD 设备不需要此防跌落保护，减少不必要的唤醒事件
- **修复命令**：`sudo pmset -a sms 0`

### M7-15：powermetrics 工具存在
- **检测内容**：/usr/bin/powermetrics 是否可用（信息类）
- **益处**：可用于监测 AI 任务的 CPU/GPU 功耗
- **理由**：powermetrics 是 macOS 内置的精确功耗分析工具，可量化 Ollama/MLX 推理任务的能耗

### M7-16：caffeinate 进程检测
- **检测内容**：caffeinate 是否在后台运行（防止系统休眠的工具）
- **益处**：确认当前系统是否有额外的防休眠保障
- **修复命令**：`caffeinate -dims &`（后台运行）

### M7-17：caffeinate 系统级 LaunchDaemon
- **检测内容**：/Library/LaunchDaemons/com.server.caffeinate.plist 是否存在
- **益处**：开机自动运行 caffeinate，确保系统永不休眠
- **理由**：仅运行 caffeinate 进程会在重启后失效，LaunchDaemon 确保持久化

### M7-18：caffeinate 用户级 LaunchAgent
- **检测内容**：~/Library/LaunchAgents/com.user.caffeinate.plist 是否存在
- **益处**：登录后自动运行用户级 caffeinate
- **理由**：与系统级 LaunchDaemon 配合，在用户会话层面也确保防休眠保障

### M7-19：定时关机计划（期望 0）
- **检测内容**：是否存在 pmset 定时关机任务（期望 0 = 无计划）
- **益处**：确认无意外的定时关机任务会中断正在运行的 AI 任务
- **修复命令**：`sudo pmset schedule cancelall`

### M7-20：内存压力级别
- **检测内容**：`kern.memorystatus_vm_pressure_level`（信息类，与 M1-10 相同）
- **益处**：在电源配置上下文中提醒内存压力情况
- **理由**：内存压力与电源管理密切相关，高压力状态下系统更可能触发 Standby

### M7-21：文件描述符限制（launchctl limit maxfiles）
- **检测内容**：launchctl 级别的 maxfiles 限制（信息类）
- **益处**：了解系统层面的文件句柄上限
- **理由**：AI 工具（Claude Code、MCP 服务器）使用大量文件句柄，系统级限制决定了实际上限

### M7-22：Wi-Fi 接电唤醒
- **检测内容**：接电时 Wi-Fi 网络唤醒（womp）
- **益处**：可通过 Wi-Fi 远程唤醒接电的 Mac
- **修复命令**：`sudo pmset -c womp 1`

### M7-23：Wi-Fi 电池唤醒（笔记本专属）
- **检测内容**：电池供电时 Wi-Fi 唤醒能力
- **益处**：移动服务器场景下可远程唤醒

### M7-24：休眠模式（hibernatemode）
- **检测内容**：休眠模式（笔记本期望 3 = Safe Sleep，台式机期望 0 = 禁用休眠）
- **益处**：笔记本安全保存内存状态；台式机禁用休眠使恢复速度最快
- **修复命令**：笔记本 `sudo pmset -a hibernatemode 3`；台式机 `sudo pmset -a hibernatemode 0`

### M7-25：合盖不唤醒（lidwake = 0，笔记本专属）
- **检测内容**：合盖后是否因开盖自动唤醒（期望 0 = 不唤醒）
- **益处**：配合 caffeinate，合盖后任务继续运行
- **理由**：开发者用笔记本当服务器时，合盖运行是常见使用模式

### M7-26：Amphetamine 安装状态
- **检测内容**：防休眠工具 Amphetamine.app 是否安装（信息类）
- **益处**：GUI 防休眠工具，比 caffeinate 更灵活易用

### M7-27：服务器模式一键汇总
- **检测内容**：通过检查 sleep=0 验证是否已应用服务器模式配置
- **修复命令**：`sudo pmset -a sleep 0 disksleep 0 displaysleep 10 standby 0 powernap 0 lowpowermode 0 autorestart 1 womp 1 sms 0 lidwake 0 hibernatemode 0 && caffeinate -dims &`

---

## M9 — 终端环境模块

> 定位：检测 Shell 配置、代理设置、SSH 优化、安全配置，全部计入评分。

### M9-1：默认 Shell 类型
- **检测内容**：$SHELL 是否为 /bin/zsh
- **益处**：确保使用 macOS 推荐的默认 Shell，保证工具链兼容性
- **理由**：Bash 在 macOS Catalina 之后已被 zsh 替代为默认 Shell；Claude Code 和大量现代工具依赖 zsh 的特性
- **检测命令**：`echo $SHELL`
- **期望值**：`/bin/zsh`
- **修复命令**：`chsh -s /bin/zsh`

### M9-2：HTTPS_PROXY 环境变量
- **检测内容**：HTTPS_PROXY 是否已设置（信息类）
- **益处**：Claude Code、curl、wget 等 CLI 工具的出站流量通过代理路由
- **理由**：Claude Code 访问 Anthropic API 需要代理支持，HTTPS_PROXY 是最通用的代理配置方式
- **检测命令**：`echo ${HTTPS_PROXY:-not set}`

### M9-3：HTTP_PROXY 环境变量
- **检测内容**：HTTP_PROXY 是否已设置（信息类）
- **益处**：HTTP 协议流量也通过代理路由（与 HTTPS_PROXY 配合）
- **理由**：部分工具（npm 等）只识别小写的 http_proxy，建议同时设置大小写两种形式

### M9-4：all_proxy_on 函数
- **检测内容**：~/.zshrc 是否包含 all_proxy_on 一键开启代理函数
- **益处**：终端中执行 `all_proxy_on` 即可一次性设置所有代理环境变量，包括 NO_PROXY 排除列表
- **理由**：手动设置 6 个代理变量（http/https/all，大小写两种）容易遗漏；函数封装保证设置完整性

### M9-5：all_proxy_off 函数
- **检测内容**：~/.zshrc 是否包含 all_proxy_off 关闭代理函数
- **益处**：访问国内服务时快速关闭代理，避免走代理带来的延迟
- **理由**：代理开关不一致会导致混乱；成对的 on/off 函数确保代理状态始终明确

### M9-6：Homebrew 遥测关闭（HOMEBREW_NO_ANALYTICS）
- **检测内容**：是否设置 HOMEBREW_NO_ANALYTICS=1 或通过 brew analytics off 关闭
- **益处**：Homebrew 不再向 Google Analytics 上报安装的软件包和错误信息
- **理由**：Homebrew 默认收集匿名遥测，包括安装的 formula 名称，这会向 Google 透露你安装的所有工具
- **修复命令**：`brew analytics off && echo 'export HOMEBREW_NO_ANALYTICS=1' >> ~/.zshrc`

### M9-7：Git user.name 配置
- **检测内容**：Git 全局用户名是否已设置（信息类）
- **益处**：确保 Git 提交记录包含正确的作者信息
- **理由**：⚠ Claude Code 会读取 git user.name 并上报到 GrowthBook 作为身份信号，应确保与账号身份一致

### M9-8：Git user.email 配置
- **检测内容**：Git 全局邮箱是否已设置（信息类）
- **益处**：确保 Git 提交包含正确邮箱
- **理由**：⚠ 重要：Claude Code 会读取 git user.email 并上报，即使未使用 OAuth 登录。这是容易被忽略的身份泄露点

### M9-9：SSH config 文件存在
- **检测内容**：~/.ssh/config 是否存在
- **益处**：SSH 连接配置可实现连接复用、保活包、自动密钥选择等优化
- **理由**：没有 SSH config 文件意味着每次连接都需要重复认证；ControlMaster 选项可复用已有连接，大幅提升效率
- **修复命令**：创建含 ControlMaster/ServerAliveInterval 的基础 SSH config

### M9-10：SSH ControlMaster 配置
- **检测内容**：~/.ssh/config 中是否包含 ControlMaster 配置
- **益处**：多个 SSH 连接复用同一 TCP 连接，避免重复认证，批量操作速度显著提升
- **理由**：Claude Code 在执行远程操作时可能多次建立 SSH 连接，ControlMaster 可减少认证开销

### M9-11：文件描述符上限（ulimit -n）
- **检测内容**：当前 session 的文件描述符上限（期望 65536）
- **益处**：避免 Claude Code 高并发操作触发 "Too many open files" 错误
- **理由**：macOS 默认值 256 极低，Claude Code 同时打开多个文件、MCP 连接、并行构建时很容易超出
- **检测命令**：`ulimit -n`
- **期望值**：`65536`
- **修复命令**：`ulimit -n 65536 && echo 'ulimit -n 65536' >> ~/.zshrc`

### M9-12：进程数上限（ulimit -u）
- **检测内容**：最大进程数（信息类）
- **益处**：了解系统进程上限，确保大型构建任务不会因进程数限制失败
- **理由**：多模型推理（多个 Ollama 实例）、大型 npm 项目（spawn 大量子进程）需要足够的进程数上限

### M9-13：危险别名检测（dangerously-skip-permissions）
- **检测内容**：~/.zshrc 和 ~/.zprofile 中是否包含 'dangerously' 字样的配置
- **益处**：识别可能绕过 Claude Code 权限检查的危险配置
- **理由**：`alias claude='claude --dangerously-skip-permissions'` 允许 Claude Code 执行任意系统命令而无需确认，是重大安全风险
- **检测命令**：`grep -c 'dangerously' ~/.zshrc ~/.zprofile 2>/dev/null`
- **期望值**：`0`
- **修复命令**：`sed -i '' '/dangerously/d' ~/.zshrc ~/.zprofile`

### M9-14：LANG 语言环境（信息类）
- **检测内容**：LANG 环境变量的值（信息类）
- **益处**：确认 Shell 语言设置是否与代理 IP 地区一致，避免身份特征暴露
- **理由**：LANG=zh_CN.UTF-8 是强地理信号，即使代理 IP 在美国，语言设置暴露了中文区域特征

### M9-15：LC_ALL 语言覆盖（信息类）
- **检测内容**：LC_ALL 环境变量（信息类）
- **益处**：LC_ALL 优先级高于 LANG，确认其与预期地区一致
- **理由**：LC_ALL 若设为 zh_CN.UTF-8 会覆盖所有 LC_* 设置，即使 LANG 已修正也会被覆盖

### M9-16：macOS 系统语言首选（信息类）
- **检测内容**：AppleLanguages 列表第一项（信息类）
- **益处**：确认浏览器 User-Agent 中的 Accept-Language 不会暴露中文区域
- **理由**：浏览器语言偏好来自系统语言设置，中文排首位时所有 HTTP 请求都会携带 zh-CN 的语言标识

### M9-17：zsh_history 中文命令数
- **检测内容**：~/.zsh_history 中含中文字符的命令记录数（期望 0）
- **益处**：减少 Shell 历史对语言特征的暴露
- **理由**：含中文字符的 Shell 历史命令是明确的语言/地区标识，可能在历史上报或日志中泄露
- **期望值**：`0`
- **修复命令**：Python 脚本过滤中文行

### M9-18：maxfiles 持久化 LaunchDaemon
- **检测内容**：/Library/LaunchDaemons/limit.maxfiles.plist 是否存在
- **益处**：确保 ulimit -n 65536 在重启后依然生效（通过 LaunchDaemon 持久化）
- **理由**：ulimit 命令只在当前 session 有效，重启后恢复 256 的默认值，需要 LaunchDaemon 实现跨重启持久化

### M9-19：dotfiles 数量
- **检测内容**：主目录中隐藏配置文件（dotfiles）的总数（信息类）
- **益处**：提示定期审查 dotfiles，防止残留配置暴露个人信息或占用磁盘
- **理由**：.netrc 含密码、.npmrc 含 Token、旧工具的 rc 文件等都是潜在信息泄露点

---

## M10 — AI 服务调优模块

> 定位：Claude Code 专项安全态势检测，包含风险变量检测、代理配置、网络防护、遥测控制，计入评分。共约 53 项检测。

### M10 模块架构说明
本模块分为 9 个 MARK 区：
1. 风险信号检测（B 组：危险变量 — 检测后期望"不存在"）
2. 危险环境变量（服务端标记为危险）
3. 安全基线（A 组：正向检测）
4. 环境信号检测（身份/地理信号）
5. 代理配置
6. 网络防护（代理/IPv6/防火墙）
7. 防火墙和安全工具
8. macOS 遥测禁用
9. 代理辅助检测

### M10-B 组：风险变量反向检测（3 项）
> 这些变量**不应该**被设置，设置后反而会增加风险

#### M10-1：禁止关闭非必要流量（CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC）
- **检测内容**：此环境变量是否**未**被设置（期望 "not set"）
- **益处**：避免触发风控系统的"地区特征"标签；保持 Opus 4.6、Fast Mode、Remote Control 等付费功能正常运行
- **理由**：
  - 原因 1（贝叶斯标签）：关闭遥测的教程几乎只在中文社区传播，风控系统可通过此特征推断地区
  - 原因 2（功能失效）：设置后触发链 `DISABLE_NONESSENTIAL_TRAFFIC → isAnalyticsDisabled → isGrowthBookEnabled=false`，导致付费功能 Feature Flag 全部失效，且无任何报错提示
  - 原因 3（掩盖无效）：每个 API 请求自身的 Attribution Header 和 cch Attestation 仍然发送
- **检测命令**：`echo ${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-not set}`
- **期望值**：`not set`
- **修复命令**：`sed -i '' '/export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=/d' ~/.zshrc && source ~/.zshrc`

#### M10-2：禁止关闭反馈调查（CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY）
- **检测内容**：是否**未**设置禁用反馈调查（期望 "not set"）
- **益处**：避免增加风控系统的地域风险标签
- **理由**：与 M10-1 同属遥测关闭链路，风控系统将两者视为同一类型的异常行为
- **期望值**：`not set`

#### M10-3：禁止关闭遥测总开关（DISABLE_TELEMETRY）
- **检测内容**：是否**未**设置遥测总关闭（期望 "not set"）
- **益处**：保持 GrowthBook Feature Flag 系统正常，所有付费功能可用
- **理由**：⚠ 极高风险：与 DISABLE_NONESSENTIAL_TRAFFIC 效果相同，GrowthBook 被完全禁用后自动成为风控系统中的异常用户
- **期望值**：`not set`

### M10-C 组：危险环境变量（5 项）

#### M10-4：ANTHROPIC_BASE_URL 未自定义
- **检测内容**：是否**未**设置 ANTHROPIC_BASE_URL（期望 "not set"）
- **益处**：避免被服务端 Remote Managed Settings 模块标记为"危险环境变量"用户
- **理由**：自定义 API 基础 URL 会通过 GrowthBook 的 apiBaseUrlHost 字段上报，触发服务端特别关注
- **期望值**：`not set`

#### M10-5：NODE_TLS_REJECT_UNAUTHORIZED 未禁用
- **检测内容**：是否**未**设置 TLS 证书验证禁用（期望 "not set"）
- **益处**：保持正常 TLS 证书验证，避免被服务端标记为危险环境变量用户
- **理由**：设置 NODE_TLS_REJECT_UNAUTHORIZED=0 跳过 TLS 验证既是安全风险，也会被服务端识别为异常配置
- **期望值**：`not set`

#### M10-6：OpenTelemetry 遥测未开启
- **检测内容**：是否**未**设置 CLAUDE_CODE_ENABLE_TELEMETRY（期望 "not set"）
- **益处**：不收集 OpenTelemetry 遥测数据（默认关闭，不需要主动设置）
- **期望值**：`not set`

#### M10-7：Prompt 日志未开启（OTEL_LOG_USER_PROMPTS）
- **检测内容**：是否**未**设置 Prompt 内容上传（期望 "not set"）
- **益处**：⚠ 极高隐私风险防护：防止用户 Prompt 文本被上传到遥测系统
- **理由**：设置后所有用户输入的 Prompt 内容都会被上传，是严重的隐私泄露
- **期望值**：`not set`

#### M10-8：工具调用日志未开启（OTEL_LOG_TOOL_CONTENT）
- **检测内容**：是否**未**设置工具调用内容上传（期望 "not set"）
- **益处**：防止所有工具调用（含文件内容）被上传到遥测系统
- **期望值**：`not set`

### M10-A 组：安全环境变量正向检测（4 项 + 1 汇总）

#### M10-9：代理 DNS 解析（CLAUDE_CODE_PROXY_RESOLVES_HOSTS）
- **检测内容**：是否设置 = 1（期望 "1"）
- **益处**：配合 HTTPS_PROXY，让代理软件接管 DNS 解析，防止 DNS 泄露暴露真实 IP
- **理由**：未设置时即使 HTTPS_PROXY 生效，DNS 查询仍可能直接发送到系统 DNS 服务器
- **期望值**：`1`
- **修复命令**：`echo 'export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1' >> ~/.zshrc`

#### M10-10：流监控看门狗（CLAUDE_ENABLE_STREAM_WATCHDOG）
- **检测内容**：是否设置 = 1（期望 "1"）
- **益处**：检测 Claude Code 流式响应停止后自动恢复连接
- **期望值**：`1`

#### M10-11：子进程凭据清洗（CLAUDE_CODE_SUBPROCESS_ENV_SCRUB）
- **检测内容**：是否设置 = 1（期望 "1"）
- **益处**：防止 Claude Code 启动的子进程（如 shell 命令）继承 API Key 等凭据
- **理由**：Claude Code 在执行 shell 命令时，若子进程继承了 ANTHROPIC_API_KEY，第三方工具可读取该 Key
- **期望值**：`1`

#### M10-12：流空闲超时（CLAUDE_STREAM_IDLE_TIMEOUT_MS）
- **检测内容**：是否设置 = 90000（90 秒）
- **益处**：90 秒无响应后自动超时重连，防止 Claude Code 在代理断线时无限等待
- **期望值**：`90000`

### M10-D 组：环境身份/地理信号检测（7 项）

#### M10-13：DeviceId 永久设备指纹
- **检测内容**：~/.claude.json 中的 deviceId 是否存在（信息类）
- **益处**：了解设备指纹机制，在封号时知道需要清理
- **理由**：deviceId 是跨账号永久设备指纹（64 字符随机十六进制），被封账号的 deviceId 会关联新账号，导致新账号风险评分拉满

#### M10-14：git user.email 身份泄露
- **检测内容**：git 全局邮箱（信息类）
- **益处**：了解 Claude Code 会采集哪些身份信息
- **理由**：Claude Code 读取 git config user.email 并上报到 GrowthBook，即使未用 OAuth 登录，邮箱也会被采集

#### M10-15：npm 源地理信号
- **检测内容**：npm registry 是否为官方源（期望 https://registry.npmjs.org/）
- **益处**：避免使用国内镜像源被识别为地理信号
- **理由**：npmmirror/tuna 等国内镜像是强地理位置信号，Claude Code 会探测已安装包管理器信息
- **期望值**：`https://registry.npmjs.org/`
- **修复命令**：`npm config set registry https://registry.npmjs.org/`

#### M10-16：时区环境信号（TZ）
- **检测内容**：TZ 环境变量（信息类）
- **益处**：识别时区与代理 IP 地区的一致性
- **理由**：IP 在美国/日本但 TZ=Asia/Shanghai 是最常见的地理信号穿帮

#### M10-17：LANG 语言环境信号
- **检测内容**：LANG 变量（信息类）
- **益处**：识别是否包含 zh_CN/zh_TW 等中文区域特征
- **理由**：LANG 含中文是直接的地区特征暴露

#### M10-18：LC_ALL 语言覆盖信号
- **检测内容**：LC_ALL 变量（信息类）
- **益处**：LC_ALL 优先级最高，若设为中文覆盖所有语言设置

#### M10-19：macOS 系统语言首选项
- **检测内容**：AppleLanguages 列表（信息类）
- **益处**：浏览器 User-Agent 的语言偏好来自系统语言，中文排首位即暴露地区

### M10-E 组：代理配置（3 项）

#### M10-20：HTTPS_PROXY 强制出口代理
- **检测内容**：HTTPS_PROXY 是否已设置（期望 "set"）
- **益处**：确保 Claude Code 所有 HTTPS 请求通过代理出口，不直连 Anthropic 服务器
- **检测命令**：`test -n "$HTTPS_PROXY" && echo 'set' || echo 'not set'`
- **期望值**：`set`

#### M10-21：all_proxy_on 函数（交叉引用 M9）
- **检测内容**：~/.zshrc 中 all_proxy_on 函数行数（交叉引用 M9-4）
- **益处**：与 M9-4 共享信息，避免重复配置

#### M10-22：all_proxy_off 函数（交叉引用 M9）
- **检测内容**：~/.zshrc 中 all_proxy_off 函数行数（交叉引用 M9-5）

### M10-F 组：Claude Code 沙盒配置（3 项）

#### M10-23：沙盒代理端口（network.httpProxyPort）
- **检测内容**：~/.claude/settings.json 中是否配置了沙盒内代理端口
- **益处**：Claude Code 沙盒内的工具调用也会通过指定代理端口
- **理由**：沙盒代理端口与系统环境变量 HTTPS_PROXY 互为补充，确保所有网络请求都经过代理

#### M10-24：沙盒域名白名单（network.allowedDomains）
- **检测内容**：~/.claude/settings.json 中是否配置了域名白名单
- **益处**：限制 Claude Code 只能访问 anthropic.com 等授权域名，防止工具调用访问其他服务器

#### M10-25：仅允许托管域名（network.allowManagedDomainsOnly）
- **检测内容**：是否开启仅托管域名访问限制
- **益处**：最严格的网络隔离，Claude Code 无法访问白名单外的任何域名

### M10-G 组：Surge 代理软件检测（5 项）

#### M10-26：Surge Fake IP DNS（交叉引用 M3）
- **检测内容**：是否有 198.18.0.2 的 Fake IP DNS（Surge 增强模式指标）

#### M10-27：Surge TUN 接口
- **检测内容**：是否存在 utun 接口（Surge TUN 模式接管系统流量的标志）
- **益处**：确认 Surge 增强模式正确运行，所有流量通过 TUN 接口路由

#### M10-28：IPv6 全局地址（交叉引用 M3）
- **检测内容**：全局 IPv6 地址数（期望 0）

#### M10-29：Wi-Fi IPv6（交叉引用 M3）
- **检测内容**：Wi-Fi 接口 IPv6 状态

#### M10-30：mDNS 多播（交叉引用 M4）
- **检测内容**：mDNS 多播广告禁用状态

### M10-G 组（续）：网络防护补充（5 项）

#### M10-31：Captive Portal（交叉引用 M4）
- **检测内容**：Captive Portal 检测状态

#### M10-32：IPv6 路由通告（交叉引用 M8）
- **检测内容**：net.inet6.ip6.accept_rtadv 状态

#### M10-33：IPv6 数据包转发（交叉引用 M8）
- **检测内容**：net.inet6.ip6.forwarding 状态

### M10-H 组：防火墙和安全工具（5 项）

#### M10-34：防火墙开启（交叉引用 M2）
#### M10-35：防火墙隐身（交叉引用 M2）
#### M10-36：防火墙签名（交叉引用 M2）

#### M10-37：LuLu 安装状态
- **检测内容**：/Applications/LuLu.app 是否存在
- **益处**：LuLu 是开源出站防火墙，可以拦截和监控所有应用的出站网络连接，阻止未授权联网
- **理由**：macOS 内置防火墙只控制入站，不控制出站；LuLu 补充了出站防火墙能力

#### M10-38：KnockKnock 安装状态
- **检测内容**：/Applications/KnockKnock.app 是否存在
- **益处**：KnockKnock 扫描所有开机自启动项，发现恶意软件持久化机制
- **理由**：恶意软件检测工具，可以发现通过 LaunchAgents/Daemons 持久化的威胁

#### M10-39：Surge Dashboard 绑定（交叉引用 M3）

### M10-I 组：macOS 遥测禁用（5 项，与 M4 交叉）
Apple 遥测关闭（与 Claude 风控无关，纯粹的 Apple 系统遥测）：

#### M10-40：Apple 诊断数据提交（交叉引用 M4-1）
#### M10-41：崩溃报告弹窗（交叉引用 M4-2）
#### M10-42：Apple 个性化广告（交叉引用 M4-6）
#### M10-43：iCloud 使用追踪（交叉引用 M4-7）
#### M10-44：iCloud UDC 自动化（交叉引用 M4-8）

### M10-J 组：代理辅助检测（2 项）

#### M10-45：NO_PROXY 本地地址排除
- **检测内容**：NO_PROXY 是否包含 localhost（期望 "localhost"）
- **益处**：本地服务（localhost、127.0.0.1、192.168.x.x）的请求不经过代理，避免本地服务访问失败
- **理由**：代理配置不设 NO_PROXY 会导致本地 HTTP 服务（如 Ollama 11434、本地 Web 服务）的请求也走代理，造成连接失败
- **期望值**：`localhost`
- **修复命令**：设置 NO_PROXY 排除列表到 ~/.zshrc

#### M10-46：all_proxy_on 函数含 NO_PROXY 设置
- **检测内容**：~/.zshrc 中的 all_proxy_on 函数是否包含 NO_PROXY 设置
- **益处**：确保代理开启时也设置正确的排除列表，防止本地服务请求走代理

### M10-K 组：其他检测（5 项）

#### M10-47：Help improve Claude（对话训练开关）
- **检测内容**：~/.claude/settings.json 中 enableTraining 是否为 true
- **益处**：关闭后对话内容不用于 Anthropic 模型训练（数据保留 5 年）
- **理由**：默认 true 意味着每次对话都可能被用于 Claude 模型训练，涉及代码库、商业逻辑等敏感内容

#### M10-48：Claude Code 版本
- **检测内容**：claude --version（信息类）
- **益处**：确认当前版本，识别是否有重要更新

#### M10-49：全部接口 IPv6 状态
- **检测内容**：所有网络接口中 IPv6 未关闭的接口数（期望 0）
- **益处**：彻底确认所有接口均已关闭 IPv6

#### M10-50：防火墙已下载签名应用
- **检测内容**：已签名的下载应用是否自动通过防火墙（交叉引用 M2）

#### M10-51：Surge WebRTC STUN 拦截
- **检测内容**：Surge 配置文件中是否包含 STUN 协议拦截规则
- **益处**：WebRTC STUN 请求会绕过代理直连 STUN 服务器，泄露真实 IP；拦截规则阻止此行为
- **理由**：视频会议、P2P 应用使用 WebRTC STUN 建立直连，这些请求会绕过代理，暴露真实 IP 给对端

---

## M11 — 开发工具模块

> 定位：检测开发工具链的安装状态和配置，不计入评分（信息类）。约 50+ 项检测。支持 Sequoia/Tahoe 专属项。

### M11-A 组：基础工具链（7 项）

#### M11-1：Xcode Command Line Tools
- **检测内容**：xcode-select -p 是否返回有效路径
- **益处**：编译 Swift/C/C++/ObjC 代码；Homebrew 依赖的基础组件
- **理由**：几乎所有 macOS 开发工具都依赖 Xcode CLT，没有它 Homebrew 无法安装大多数包
- **修复命令**：`xcode-select --install`

#### M11-2：Clang 编译器版本
- **检测内容**：Clang 版本号（信息类）
- **益处**：确认 C/C++/ObjC 编译器版本

#### M11-3：Xcode 版本（完整版）
- **检测内容**：xcodebuild 版本（信息类）
- **益处**：确认完整 Xcode 是否安装（与 CLT 的区别）

#### M11-4：Homebrew 版本
- **检测内容**：brew --version
- **益处**：确认 macOS 最流行的包管理器是否安装
- **修复命令**：`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

#### M11-5：Homebrew 路径
- **检测内容**：which brew 路径（信息类）
- **益处**：确认 Homebrew 是否安装在正确位置（Apple Silicon: /opt/homebrew/bin/brew）

#### M11-6：Homebrew analytics 状态
- **检测内容**：brew analytics 是否关闭
- **益处**：不向 Google Analytics 上报安装的包名和错误信息
- **修复命令**：`brew analytics off`

#### M11-7：Homebrew prefix 路径
- **检测内容**：brew --prefix 路径（信息类）
- **益处**：确认 Homebrew 安装前缀（Apple Silicon: /opt/homebrew，Intel: /usr/local）

### M11-B 组：编程语言运行时（11 项）

#### M11-8：nvm（Node Version Manager）
- **检测内容**：~/.nvm/nvm.sh 是否存在
- **益处**：管理多个 Node.js 版本，项目间随时切换；Claude Code 需要 Node 18+
- **修复命令**：`curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash`

#### M11-9：Node.js 版本
- **检测内容**：node -v 版本号
- **益处**：Claude Code 及大多数 AI CLI 工具依赖 Node.js
- **理由**：Claude Code 要求 Node 18+，建议 v20/v22 LTS
- **修复命令**：`nvm install --lts`

#### M11-10：npm 版本
- **检测内容**：npm -v 版本号
- **益处**：Node 包管理器，安装 Claude Code 等 CLI 工具
- **修复命令**：`npm install -g npm@latest`

#### M11-11：Bun 版本
- **检测内容**：bun --version
- **益处**：比 npm install 快 20-100 倍的现代 JS 运行时，Apple Silicon 高度优化
- **修复命令**：`curl -fsSL https://bun.sh/install | bash`

#### M11-12：TypeScript 编译器（tsc）
- **检测内容**：tsc --version
- **益处**：Claude Code 及大量 AI 工具使用 TypeScript 编写，需要全局 tsc 进行类型检查
- **修复命令**：`npm install -g typescript`

#### M11-13：pyenv（Python 版本管理）
- **检测内容**：pyenv --version
- **益处**：管理多个 Python 版本，避免系统 Python 被污染
- **修复命令**：`brew install pyenv`

#### M11-14：Python 3 版本
- **检测内容**：python3 --version
- **益处**：PyTorch/MLX/LangChain 等 AI/ML 工具依赖 Python
- **修复命令**：`brew install python@3.12`

#### M11-15：uv（超快 Python 包管理器）
- **检测内容**：uv --version
- **益处**：比 pip 快 10-100 倍，MCP 服务器 Python 依赖推荐用 uv 安装
- **修复命令**：`curl -LsSf https://astral.sh/uv/install.sh | sh`

#### M11-16：Rust 编译器（rustc）
- **检测内容**：rustc --version
- **益处**：部分 MCP 工具和高性能 CLI 工具（ripgrep、fd 等）用 Rust 编写
- **修复命令**：`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y`

#### M11-17：Cargo（Rust 包管理器）
- **检测内容**：cargo --version
- **益处**：安装 Rust 生态工具（如 cargo install ripgrep）
- **理由**：随 Rust 安装，确认 PATH 包含 ~/.cargo/bin

#### M11-18：Go 版本
- **检测内容**：go version
- **益处**：部分 MCP 服务器和开发工具使用 Go 编写
- **修复命令**：`brew install go`

#### M11-19：Java 版本
- **检测内容**：java -version
- **益处**：Spring Boot、部分 AI 工具依赖
- **修复命令**：`brew install --cask temurin@21`

#### M11-20：Swift 版本
- **检测内容**：swift --version（信息类）
- **益处**：确认本项目（MacAudit）的编译环境版本

### M11-C 组：Sequoia 专属运行时（2 项）

#### M11-21：pyenv 编译依赖（Sequoia 专属）
- **检测内容**：openssl/readline/zlib/xz 等依赖是否通过 Homebrew 安装
- **益处**：Sequoia 下 pyenv 编译 Python 源码所需的依赖
- **理由**：缺少这些依赖会导致 pyenv install 失败（无法编译 Python 扩展模块）
- **修复命令**：`brew install openssl readline zlib xz`

#### M11-22：OrbStack 版本（Sequoia 专属）
- **检测内容**：orb version 是否 >= 2.0.4
- **益处**：OrbStack 2.0.4+ 完全兼容 macOS 15 Sequoia（旧版容器网络异常）
- **修复命令**：`brew install --cask orbstack`

### M11-D 组：Tahoe 专属（1 项）

#### M11-23：MLX 框架（Tahoe 专属）
- **检测内容**：python3 -c 'import mlx; print(mlx.__version__)' 是否成功
- **益处**：Apple Silicon 专属 ML 框架，在 Tahoe 上有系统深度集成，性能超越 Ollama
- **修复命令**：`pip install mlx`

### M11-E 组：Rust 组件（1 项）

#### M11-24：Rust 工具链组件数
- **检测内容**：rustup component list --installed 的数量
- **益处**：确认 rust-src、rust-analyzer、clippy、rustfmt 等开发必要组件已安装
- **修复命令**：`rustup component add rust-src rust-analyzer clippy rustfmt`

### M11-F 组：Git 工具链（7 项）

#### M11-25：Git 版本
- **检测内容**：git --version
- **益处**：系统自带版本较旧，Homebrew 版本功能更完整
- **修复命令**：`brew install git`

#### M11-26：git-lfs（大文件存储）
- **检测内容**：git lfs version
- **益处**：从 HuggingFace 克隆 AI 模型仓库时必须启用 LFS
- **修复命令**：`brew install git-lfs && git lfs install`

#### M11-27：GitHub CLI（gh）
- **检测内容**：gh --version
- **益处**：命令行操作 GitHub PR/Issue/Release；Claude Code 执行 GitHub 操作的依赖工具
- **修复命令**：`brew install gh`

#### M11-28：lazygit
- **检测内容**：lazygit --version
- **益处**：终端 Git 可视化 TUI，支持 diff 查看、暂存区管理、交互式 rebase
- **修复命令**：`brew install lazygit`

#### M11-29：delta（Git diff 美化）
- **检测内容**：delta --version
- **益处**：Git diff 语法高亮、行号显示、并排对比，替代默认单调输出
- **修复命令**：`brew install git-delta && git config --global core.pager delta`

#### M11-30：GIT_PAGER 配置
- **检测内容**：GIT_PAGER 环境变量（信息类）
- **益处**：确认 git 输出的分页器配置

#### M11-31：git safe.directory 重复条目数
- **检测内容**：git config --global --list | grep -c safe.directory
- **益处**：大量重复条目会拖慢每次 git 命令的启动速度
- **修复命令**：`git config --global --unset-all safe.directory 2>/dev/null; git config --global --add safe.directory '*'`

#### M11-32：git 全局配置项总数
- **检测内容**：git config --global --list 行数（信息类）
- **益处**：了解 git 全局配置的完整程度

### M11-G 组：效率工具（11 项）

#### M11-33：ripgrep（rg）
- **检测内容**：rg --version
- **益处**：比 grep 快 10-100 倍；**Claude Code 内部大量使用 rg 进行代码搜索**
- **理由**：Claude Code 的代码检索功能直接调用 rg，这是 Claude Code 的**性能关键依赖**
- **修复命令**：`brew install ripgrep`

#### M11-34：fzf（模糊搜索）
- **检测内容**：fzf --version
- **益处**：Ctrl+R 命令历史模糊搜索、Ctrl+T 文件路径搜索，大幅提升终端效率
- **修复命令**：`brew install fzf && $(brew --prefix)/opt/fzf/install`

#### M11-35：jq（JSON 处理）
- **检测内容**：jq --version
- **益处**：处理 Claude API 响应数据；调试 JSON 格式的配置和响应
- **修复命令**：`brew install jq`

#### M11-36：bat（cat 替代）
- **检测内容**：bat --version
- **益处**：查看文件时有语法高亮、行号、Git 变更标记
- **修复命令**：`brew install bat`

#### M11-37：eza（ls 替代）
- **检测内容**：eza --version
- **益处**：彩色输出、图标显示、Git 状态集成
- **修复命令**：`brew install eza`

#### M11-38：htop（进程监控）
- **检测内容**：htop --version
- **益处**：交互式进程监控，监测 AI 任务资源消耗
- **修复命令**：`brew install htop`

#### M11-39：ncdu（磁盘分析）
- **检测内容**：ncdu --version
- **益处**：交互式磁盘占用分析，快速找出占用大量空间的 node_modules、Docker 镜像、LLM 模型
- **修复命令**：`brew install ncdu`

#### M11-40：wget
- **检测内容**：wget --version
- **益处**：支持断点续传和递归下载（curl 的功能补充）
- **修复命令**：`brew install wget`

#### M11-41：fd（find 替代）
- **检测内容**：fd --version
- **益处**：比 find 快 2-10 倍，默认遵守 .gitignore
- **修复命令**：`brew install fd`

#### M11-42：yq（YAML/JSON 处理）
- **检测内容**：yq --version
- **益处**：处理 Kubernetes YAML、Docker Compose、GitHub Actions 配置
- **修复命令**：`brew install yq`

#### M11-43：tree（目录可视化）
- **检测内容**：tree --version
- **益处**：快速查看项目结构，Claude Code 中 `tree -L 2 --gitignore` 常用
- **修复命令**：`brew install tree`

#### M11-44：lazydocker
- **检测内容**：lazydocker version
- **益处**：Docker 容器可视化 TUI，实时查看日志、管理容器
- **修复命令**：`brew install lazydocker`

### M11-H 组：容器/AI 工具（8 项）

#### M11-45：OrbStack
- **检测内容**：orb version
- **益处**：性能最佳的 macOS Docker 容器运行时（启动 <2 秒，内存 <300MB）
- **理由**：相比 Docker Desktop 启动慢 10 倍、内存占用高 3-5 倍，OrbStack 是开发者的最优选择
- **修复命令**：`brew install --cask orbstack`

#### M11-46：Docker CLI
- **检测内容**：docker --version
- **益处**：容器化开发环境，隔离 AI 工具运行环境

#### M11-47：Ollama
- **检测内容**：ollama --version
- **益处**：本地 LLM 运行框架，支持在 MacBook 上运行 Llama/Mistral/Phi 等模型，Apple Silicon Metal GPU 加速
- **修复命令**：`brew install ollama`

#### M11-48：OLLAMA_GPU_LAYERS 环境变量
- **检测内容**：是否设置 OLLAMA_GPU_LAYERS=-1（全部 GPU 层）
- **益处**：Apple Silicon 全部层加载到 GPU，推理速度最高
- **理由**：未设置时 Ollama 可能使用混合 CPU/GPU 模式，性能不如全 GPU

#### M11-49：OLLAMA_MAX_LOADED_MODELS 环境变量
- **检测内容**：是否设置最大加载模型数
- **益处**：多模型并行时减少模型切换延迟（32GB RAM 推荐设为 2）

#### M11-50：OLLAMA_NUM_PARALLEL 环境变量
- **检测内容**：是否设置并发请求数
- **益处**：多用户/多应用同时请求时减少等待

#### M11-51：OLLAMA_MAX_QUEUE 环境变量
- **检测内容**：最大队列长度（信息类）
- **益处**：了解 Ollama 的请求队列配置

#### M11-52：Ollama Metal GPU 加速
- **检测内容**：系统是否支持 Metal GPU（信息类）
- **益处**：确认 Apple Silicon Metal 加速对 Ollama 可用

#### M11-53：llama.cpp
- **检测内容**：是否通过 Homebrew 安装 llama.cpp
- **益处**：比 Ollama 更轻量的 LLM 推理引擎，支持 OpenAI 兼容 API 服务器
- **修复命令**：`brew install llama.cpp`

### M11-I 组：AI CLI 工具（4 项）

#### M11-54：Claude Code（claude）
- **检测内容**：claude --version
- **益处**：Anthropic 官方 AI 编程助手 CLI，本工具的运行环境
- **修复命令**：`npm install -g @anthropic-ai/claude-code`

#### M11-55：Codex CLI（OpenAI）
- **检测内容**：codex --version
- **益处**：与 Claude Code 多 AI 协作（ask codex 命令）
- **修复命令**：`npm install -g @openai/codex`

#### M11-56：OpenCode
- **检测内容**：opencode version
- **益处**：开源 AI 编程 CLI，支持多 LLM 提供商

#### M11-57：Gemini CLI（Google）
- **检测内容**：gemini --version
- **益处**：与 Claude Code 协作，可在 Claude Code 中通过 `/ask gemini` 获取 Gemini 意见
- **修复命令**：`npm install -g @google/gemini-cli`

### M11-J 组：系统配置（5 项）

#### M11-58：Xcode 清理 plist
- **检测内容**：~/Library/LaunchAgents/com.user.xcode-cleanup.plist 是否存在
- **益处**：每周自动清理 30 天以上的 Xcode DerivedData 缓存，防止磁盘被消耗数十 GB
- **理由**：Xcode 构建缓存会持续增长，开发者通常忘记手动清理

#### M11-59：ulimit -n（文件描述符）
- **检测内容**：当前 ulimit -n（期望 65536，与 M9-11 交叉）
- **益处**：确认 AI 工具运行所需的文件描述符上限

#### M11-60：ulimit -u（进程数）
- **检测内容**：当前 ulimit -u
- **益处**：确认进程数上限是否满足多模型并行需求

#### M11-61：JAVA_HOME 环境变量
- **检测内容**：$JAVA_HOME 是否设置
- **益处**：Maven/Gradle 等 Java 工具依赖 JAVA_HOME

#### M11-62：brew formula 数量
- **检测内容**：brew list --formula | wc -l（信息类）
- **益处**：了解已安装 CLI 工具数量

#### M11-63：brew cask 数量
- **检测内容**：brew list --cask | wc -l（信息类）
- **益处**：了解已安装 GUI 应用数量

#### M11-64：brew formula 列表
- **检测内容**：brew list --formula | head -20（信息类）
- **益处**：快速了解已安装的主要 CLI 工具

#### M11-65：brew cask 列表
- **检测内容**：brew list --cask | head -20（信息类）
- **益处**：快速了解已安装的主要 GUI 应用

#### M11-66：Deno 版本
- **检测内容**：deno --version
- **益处**：安全的 TypeScript 运行时；部分 MCP 服务器使用 Deno 运行
- **修复命令**：`brew install deno`

#### M11-67：pnpm 版本
- **检测内容**：pnpm --version
- **益处**：节省 60% 磁盘空间的 Node 包管理器，通过硬链接共享 node_modules
- **修复命令**：`npm install -g pnpm`

#### M11-68：Yarn 版本
- **检测内容**：yarn --version
- **益处**：Facebook 出品的 Node 包管理器，部分项目使用 Yarn
- **修复命令**：`npm install -g yarn`

---

## M13 — IP 质量检测模块

> 定位：检测当前出口 IP 的质量和风险等级，23 项检测，计入评分。分 4 个阶段执行，支持离线降级。

### M13 执行流程说明
1. **网络预检**：curl ifconfig.me，确认网络可达性
2. **Phase A（本地检测，9 项）**：并行获取本地网络信息，不依赖公网 API
3. **Phase B（GeoIP API，11 项）**：并行查询 ip-api.com 和 ipapi.is
4. **Phase C（DNSBL，1 项）**：查询 13 个 DNS 黑名单（可并行）
5. **Phase D（邮件端口，2 项）**：TCP 连接测试 SMTP 端口

### M13-Phase A：本地 IP 信息检测（9 项）

#### M13-1：公网 IPv4 地址
- **检测内容**：curl ifconfig.me 获取的公网 IPv4 地址
- **益处**：了解当前出口 IP，验证代理是否正确工作
- **理由**：这是所有后续 Phase B/C/D 检测的基础，公网 IP 决定了风险评估的标的

#### M13-2：公网 IPv6 地址
- **检测内容**：curl ipv6.icanhazip.com 获取的公网 IPv6 地址
- **益处**：确认 IPv6 是否有全局地址（应与 M3-9 的期望"无 IPv6"一致）
- **理由**：若有公网 IPv6，说明 IPv6 未完全关闭，代理旁路风险存在

#### M13-3：本地网络接口信息
- **检测内容**：ifconfig 显示的所有本机 IP 地址（信息类）
- **益处**：了解本机在本地网络中的 IP 分配情况

#### M13-4：DNS 服务器地址（信息类，交叉引用 M3-7）
- **检测内容**：当前系统 DNS 配置（信息类）

#### M13-5：代理配置（信息类）
- **检测内容**：scutil --proxy 的输出（信息类）
- **益处**：在一个地方汇总系统代理配置

#### M13-6：默认网关
- **检测内容**：route -n get default 的网关 IP（信息类）
- **益处**：确认数据包出口路由

#### M13-7：反向 DNS（PTR 记录）
- **检测内容**：公网 IP 的反向 DNS 解析（信息类）
- **益处**：反向 DNS 通常暴露 ISP 或机房信息
- **理由**：邮件发送需要正确的 PTR 记录；数据中心 IP 的反向 DNS 通常含机房域名

#### M13-8：Whois 归属组织
- **检测内容**：公网 IP 的 Whois 机构名（信息类）
- **益处**：了解 IP 归属于哪个机构/ISP/VPN 提供商

#### M13-9：Whois 归属国家
- **检测内容**：公网 IP 的 Whois 注册国家（信息类）
- **益处**：确认 IP 注册国家与代理位置是否一致

### M13-Phase B：GeoIP API 检测（11 项）

#### M13-10：所在国家（ip-api.com）
- **检测内容**：API 返回的 IP 所在国家
- **益处**：确认代理出口所在国家（应与代理配置一致）

#### M13-11：所在城市
- **检测内容**：API 返回的城市定位
- **益处**：了解代理出口的具体城市定位

#### M13-12：时区
- **检测内容**：IP 对应的时区（信息类）
- **益处**：验证 IP 时区与系统 TZ 配置是否一致

#### M13-13：ASN（自治系统编号）
- **检测内容**：IP 所在的 ASN
- **益处**：ASN 是 IP 的重要身份标识，大型数据中心/VPN 的 ASN 通常被服务商列入风控名单
- **理由**：Cloudflare/AWS/GCP 等大型云服务商的 IP 在访问某些服务时会被特别对待

#### M13-14：ISP（互联网服务提供商）
- **检测内容**：IP 归属的 ISP 名称
- **益处**：了解 IP 是住宅 ISP 还是机房服务商

#### M13-15：代理检测（is_proxy）
- **检测内容**：API 是否将此 IP 标记为已知代理
- **益处**：了解当前 IP 在主要数据库中的代理标记状态
- **理由**：被标记为代理的 IP 在访问某些服务时会被额外审查或限制

#### M13-16：VPN 检测（is_vpn，ipapi.is）
- **检测内容**：API 是否将此 IP 标记为 VPN
- **益处**：了解 VPN 特征标记情况

#### M13-17：Tor 检测（is_tor，ipapi.is）
- **检测内容**：API 是否将此 IP 标记为 Tor 出口节点
- **益处**：Tor 出口 IP 通常被绝大多数服务拒绝

#### M13-18：数据中心检测（is_datacenter，ipapi.is）
- **检测内容**：API 是否将此 IP 标记为数据中心 IP
- **益处**：数据中心 IP 与住宅 IP 有明显风险差异，高风险服务通常对数据中心 IP 限制更严
- **理由**：住宅 IP 被视为真实用户，数据中心 IP 被视为服务器/自动化程序

#### M13-19：IP 类型（住宅/商业/数据中心）
- **检测内容**：ipapi.is 返回的 IP 类型分类
- **益处**：明确 IP 类型，评估被服务商视为真实用户的可能性

#### M13-20：托管检测（risk_hosting，ip-api.com）
- **检测内容**：IP 是否为托管服务提供商的 IP
- **益处**：与数据中心检测互补，更全面评估 IP 的托管特征

### M13-Phase C：DNSBL 黑名单检测（1 项汇总）

#### M13-21：DNSBL 黑名单（13 个数据库汇总）
- **检测内容**：对 13 个主流 DNSBL 数据库的查询汇总结果
- **益处**：一次性了解 IP 是否被主要邮件服务器黑名单收录
- **理由**：被 DNSBL 收录的 IP 发送邮件会被拒绝；被收录说明该 IP 历史上有发送垃圾邮件的记录
- **检测的 DNSBL 库**：SpamCop、Barracuda、SORBS、CBL/XBL/SBL、bl.spamcop.net 等

### M13-Phase D：邮件端口检测（2 项）

#### M13-22：SMTP Port 25 连通性
- **检测内容**：TCP 连接 25 端口的成功率
- **益处**：确认是否可以直接发送邮件（Port 25 通常被 ISP/数据中心封锁）
- **理由**：住宅 IP 通常封锁 Port 25（防止垃圾邮件），数据中心 IP 则可能开放

#### M13-23：SMTP Port 587 连通性
- **检测内容**：TCP 连接 587 端口（邮件提交端口）
- **益处**：确认邮件客户端提交端口是否可达

---

## M14 — Chrome 浏览器隐私安全模块

> 定位：通过 Chrome Enterprise Policy（macOS 级别策略）配置 Chrome 安全设置，13 项检测，计入评分。

### M14 策略机制说明
- 优先读取 `/Library/Managed Preferences/com.google.Chrome.plist`（系统级强制策略）
- Fallback 到 `com.google.Chrome` 用户域
- 部分设置需 sudo 写入（系统级策略文件）

### M14-1：Chrome 安装状态
- **检测内容**：/Applications/Google Chrome.app 是否存在
- **益处**：未安装时跳过所有后续检测
- **理由**：Chrome 是最常见的工作浏览器，需要系统级策略管理其隐私配置

### M14-2：WebRTC IP 防泄露（最重要！）
- **检测内容**：WebRtcIPHandlingPolicy = "disable_non_proxied_udp"
- **益处**：防止 WebRTC 绕过代理暴露真实 IP，即使使用 VPN/代理也可能泄露
- **理由**：WebRTC 是最常见的真实 IP 泄露方式，视频会议、在线工具等都使用 WebRTC；不配置此策略时，真实 IP 会直接暴露给对端
- **期望值**：`disable_non_proxied_udp`
- **修复命令**：`sudo defaults write '/Library/Managed Preferences/com.google.Chrome' WebRtcIPHandlingPolicy -string 'disable_non_proxied_udp'`

### M14-3：Chrome 内置 DNS over HTTPS（关闭）
- **检测内容**：DnsOverHttpsMode = "off"
- **益处**：Chrome 不自行将 DNS 请求发送到 Google DoH 8.8.8.8，而是使用系统 DNS（由 Surge 等代理接管）
- **理由**：Chrome 默认会将 DNS 升级到 Google DoH，绕过 Surge 的 Fake IP DNS 机制，导致 DNS 泄露
- **期望值**：`off`
- **修复命令**：`sudo defaults write '/Library/Managed Preferences/com.google.Chrome' DnsOverHttpsMode -string 'off'`

### M14-4：Chrome 内置 DNS 客户端（关闭）
- **检测内容**：BuiltInDnsClientEnabled = 0（false）
- **益处**：Chrome 使用操作系统 DNS，而非自己的 DNS 客户端，确保 Surge 统一接管所有 DNS 解析
- **期望值**：`0`
- **修复命令**：`sudo defaults write '/Library/Managed Preferences/com.google.Chrome' BuiltInDnsClientEnabled -bool false`

### M14-5：Chrome 遥测上报（关闭）
- **检测内容**：MetricsReportingEnabled = 0
- **益处**：禁止崩溃报告和使用统计发送给 Google
- **期望值**：`0`
- **修复命令**：`sudo defaults write '/Library/Managed Preferences/com.google.Chrome' MetricsReportingEnabled -bool false`

### M14-6：Safe Browsing 扩展上报（关闭）
- **检测内容**：SafeBrowsingExtendedReportingEnabled = 0
- **益处**：禁用增强模式的页面截图和文件信息上传到 Google（保留标准安全保护）
- **期望值**：`0`

### M14-7：Chrome 网络预加载（关闭）
- **检测内容**：NetworkPredictionOptions = 2（禁用预测）
- **益处**：禁止 Chrome 预解析 DNS/预连接服务器，防止向未访问站点发送未授权连接
- **期望值**：`2`

### M14-8：Chrome 搜索建议（关闭）
- **检测内容**：SearchSuggestEnabled = 0
- **益处**：地址栏输入不实时发送到 Google 搜索服务器
- **理由**：每次按键都向 Google 发送，即使不回车，输入内容已被记录
- **期望值**：`0`

### M14-9：Chrome 页面翻译服务（关闭）
- **检测内容**：TranslateEnabled = 0
- **益处**：禁止 Chrome 将页面内容发送到 Google 翻译
- **期望值**：`0`

### M14-10：Chrome 云端拼写检查（关闭）
- **检测内容**：SpellCheckServiceEnabled = 0
- **益处**：禁止将输入的文字发送到 Google 服务器进行拼写检查
- **期望值**：`0`

### M14-11：Chrome 扩展旁加载阻止
- **检测内容**：BlockExternalExtensions = 1
- **益处**：阻止第三方软件（安装包等）静默安装 Chrome 扩展
- **理由**：恶意软件常通过安装包静默安装 Chrome 扩展实现持久化
- **期望值**：`1`

### M14-12：Chrome Google 账号登录
- **检测内容**：BrowserSignin 状态（信息类）
- **益处**：了解 Chrome 是否与 Google 账号同步
- **理由**：Chrome 同步 Google 账号会将浏览历史、密码、书签同步到 Google 服务器

### M14-13：Chrome 策略生效验证
- **检测内容**：/Library/Managed Preferences/com.google.Chrome.plist 是否存在
- **益处**：确认系统级 Chrome 策略文件已创建
- **期望值**：`exists`

---

## M15 — Safari 浏览器安全模块

> 定位：基于 CIS Benchmark 和 Apple 最佳实践的 Safari 隐私配置，12 项检测，计入评分。

### M15-1：Safari 网页搜索上报（关闭）
- **检测内容**：UniversalSearchEnabled = 0（交叉引用 M4-15）
- **益处**：地址栏输入内容不发送给 Apple 进行 Spotlight/Siri 建议
- **期望值**：`0`

### M15-2：Safari 搜索建议（关闭）
- **检测内容**：SuppressSearchSuggestions = 1（交叉引用 M4-16）
- **益处**：减少搜索关键词实时上传到搜索引擎
- **期望值**：`1`

### M15-3：Safari 预加载顶部结果（关闭）
- **检测内容**：PreloadTopHit = 0
- **益处**：禁止 Safari 在用户确认访问前就预先建立到热门网站的连接
- **理由**：预加载会向用户未主动访问的网站发送 HTTP 请求，泄露访问意图
- **期望值**：`0`

### M15-4：Safari 欺诈网站警告（开启）
- **检测内容**：WarnAboutFraudulentWebsites = 1（CIS 基线要求）
- **益处**：访问钓鱼网站时显示警告（基于 Google Safe Browsing）
- **期望值**：`1`

### M15-5：Safari 自动打开下载（关闭）
- **检测内容**：AutoOpenSafeDownloads = 0（CIS 基线要求）
- **益处**：下载完成后不自动打开文件，防止文件解析漏洞被自动触发
- **理由**：macOS 对某些"安全"文件类型（如 .pkg）自动打开，黑客可利用此机制自动执行恶意代码
- **期望值**：`0`

### M15-6：Safari 显示完整 URL
- **检测内容**：ShowFullURLInSmartSearchField = 1
- **益处**：显示完整 URL 防止地址栏欺骗（如 apple.com.evil.com 会完整显示）
- **理由**：Safari 默认只显示主域名，隐藏了可能用于欺骗的子域名前缀
- **期望值**：`1`

### M15-7：Safari 扩展自动更新（开启）
- **检测内容**：InstallExtensionUpdatesAutomatically = 1
- **益处**：Safari 扩展自动修补已知安全漏洞，不需要手动更新
- **期望值**：`1`

### M15-8：Safari 弹窗拦截（开启）
- **检测内容**：WebKitJavaScriptCanOpenWindowsAutomatically = 0
- **益处**：阻止 JavaScript 自动打开新窗口（广告弹窗/钓鱼弹窗）
- **期望值**：`0`

### M15-9：Safari 地址自动填充（关闭）
- **检测内容**：AutoFillFromAddressBook = 0
- **益处**：禁用地址/联系人自动填充，建议改用专用密码管理器（1Password/Bitwarden）
- **理由**：内置自动填充功能安全性不如专用密码管理器，且可能在恶意表单中意外填入个人信息
- **期望值**：`0`

### M15-10：Safari 信用卡自动填充（关闭）
- **检测内容**：AutoFillCreditCardData = 0
- **益处**：防止信用卡数据暴露给可能的恶意表单脚本
- **理由**：信用卡数据是最高价值的目标，不应依赖浏览器的信用卡存储
- **期望值**：`0`

### M15-11：Safari 私有浏览指纹保护（开启）
- **检测内容**：EnableEnhancedPrivacyInPrivateBrowsing = 1
- **益处**：私有浏览模式下启用高级跟踪和指纹识别防护
- **期望值**：`1`

### M15-12：Safari 常规浏览指纹保护（Tahoe 专属）
- **检测内容**：EnableEnhancedPrivacyInRegularBrowsing = 1（仅 macOS 26 Tahoe）
- **益处**：Tahoe 新增：常规浏览模式也启用高级跟踪/指纹识别防护
- **理由**：阻止跨站跟踪、限制设备信息 API，大幅降低网站指纹识别能力
- **期望值**：`1`

### M15-13：Safari IP 隐藏（手动操作）
- **检测内容**：WBSEnablePrivateRelay 状态（信息类，需手动配置）
- **益处**：通过 iCloud Private Relay 隐藏真实 IP
- **理由**：需要 iCloud+ 订阅；手动在 Safari 设置中开启 "Hide IP address"

---

## 附录：功能说明总结

### 功能分类矩阵

| 功能类别 | 模块 | 检测项数 | 用户价值 |
|---------|------|---------|---------|
| 系统安全基线 | M2 | 15 | ⭐⭐⭐⭐⭐ 必须检查 |
| 网络安全防护 | M3 | 12 | ⭐⭐⭐⭐⭐ 必须检查 |
| 网络性能调优 | M8 | 17 | ⭐⭐⭐⭐ AI 用户关键 |
| 隐私保护 | M4 | 17 | ⭐⭐⭐⭐⭐ 强烈推荐 |
| AI 服务安全 | M10 | 53 | ⭐⭐⭐⭐⭐ Claude Code 用户必须 |
| IP 质量评估 | M13 | 23 | ⭐⭐⭐⭐ 代理用户关键 |
| 浏览器安全 | M14/M15 | 25 | ⭐⭐⭐⭐ 强烈推荐 |
| 终端环境 | M9 | 19 | ⭐⭐⭐⭐ 开发者必须 |
| 电源管理 | M7 | 27 | ⭐⭐⭐ AI 任务服务器模式必须 |
| 系统信息 | M1 | 12 | ⭐⭐⭐ 基础了解 |
| 开发工具 | M11 | 68 | ⭐⭐⭐ 工具链完整性 |
| 服务管理 | M6 | ~70 | ⭐⭐⭐ 隐私+性能 |
| 视觉优化 | M5 | 43 | ⭐⭐ 效率提升 |

### 核心设计理念

1. **一次检测，分级建议**：每项检测明确区分 pass/fail/warn/info/skip 五种状态
2. **双模块同步**：CLI（MacAudit 目标）和 GUI（MacAuditCore 目标）共 12 个模块各有两份，修改需同步
3. **一键修复**：带 fixCommand 的检测项直接生成可执行的 shell 命令
4. **sudo 分级**：UI 层标注 `(!SUDO)` 标签，用户明确知道哪些操作需要管理员权限
5. **平台适配**：Sequoia (macOS 15) 和 Tahoe (macOS 26) 有专属检测项，通过 MacOSVersion 枚举动态过滤
6. **设备感知**：laptop vs desktop 类型影响电源模块的检测项（合盖行为、电池配置）
7. **离线降级**：M13 IP 质量模块在无网络时自动降级到本地检测，Phase B/C/D 标记为 skip

### 调研团队关注要点

1. **M10 风险变量的核心逻辑**：设置 DISABLE_NONESSENTIAL_TRAFFIC 不仅不能保护隐私，反而触发风控系统的地区标签，是当前设计中最具争议的"反直觉"检测
2. **评分模块的合理性**：services/dev/animation 三个模块不计入评分，避免建议性内容拉低用户系统评分
3. **双模块架构的维护成本**：MacAudit（CLI）和 MacAuditCore（GUI）的双份模块代码是当前最大的技术债务
4. **IP 质量模块的 API 依赖**：M13 Phase B 使用 ip-api.com 和 ipapi.is 两个免费 API，存在速率限制和可用性风险
5. **Chrome Enterprise Policy 的权限要求**：M14 的修复命令需要 sudo，且写入 /Library/Managed Preferences，影响范围是所有用户
