# MacAudit VM 测试 — VM 环境信息

## VM 基本信息

```
ProductName:    macOS
ProductVersion: 15.6.1
BuildVersion:   24G90
Architecture:   arm64 (Apple Silicon via UTM)
Hostname:       <vm-user>@<vm-ip>
```

## 网络配置

```
网络服务:
  com.redhat.spice.0  (UTM 虚拟网卡)
  Ethernet            (UTM 以太网)

注意: 无 Wi-Fi 接口 (UTM VM 不提供无线)
```

## 电源管理 (pmset -g)

```
System-wide power settings:
Currently in use:
 powernap             0
 SleepServices        0
 sleep                1
 Sleep On Power Button 1
 ttyskeepawake        1
 tcpkeepalive         1
 disksleep            0
 standby              0
 displaysleep         10

不支持的 key: lowpowermode, autorestart, womp, sms, hibernatemode, lidwake
```

## 防火墙状态

```
socketfilterfw --getglobalstate: disabled
socketfilterfw --getstealthmode: Firewall stealth mode is off
socketfilterfw --getallowsigned: DISABLED
socketfilterfw --getallowsignedapp: 参数已移除 (macOS 15)
```

## 安全状态

```
Gatekeeper: assessments enabled
FileVault: (未检查)
SIP: enabled
```

## sysctl 关键值

```
kern.ipc.maxsockbuf: 6291456 (硬限制, 最大可设值)
net.inet6.ip6.accept_rtadv: read-only
net.inet6.ip6.forwarding: 0 (可读写)
```

## 已安装的开发工具

```
xcode-select: /Applications/Xcode.app/Contents/Developer
python3: 存在
swift: 存在
brew/node/npm: 未安装
```

## 未安装的应用

```
Safari: 从未启动 (defaults 域不存在)
Chrome: 未安装
Surge: 未安装
```
