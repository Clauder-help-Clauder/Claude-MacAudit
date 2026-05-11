二、Sequoia 15.x 与 Tahoe 26.x 的核心差异


  ┌──────────────────────────────────────────┬───────────────────────────┬──────────────────┐
  │                   特性                   │      Sequoia 15.7.5       │    Tahoe 26.4    │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ Liquid Glass UI                          │            无             │ 有（GPU 开销大） │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ Apple Intelligence                       │     有（15.1+ 引入）      │ 有（更深度集成） │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ intelligenceflowd / intelligencecontextd │           存在            │       存在       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ generativeexperiencesd                   │        可能不存在         │       存在       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ modelcatalogd / modelmanagerd            │          不存在           │    Tahoe 新增    │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ Stage Manager                            │        有，非默认         │   有，默认开启   │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ Window Tiling                            │ Sequoia 新增原生窗口平铺  │       继承       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ launchctl 语法                           │   bootout/disable 正确    │        同        │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ pmset autopoweroff                       │   Apple Silicon 不支持    │        同        │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ reduceBlurring                           │ 无此项（无 Liquid Glass） │       需要       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ WindowServer 26.2-26.3 bug               │          不存在           │  Tahoe 已知问题  │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ Ollama MLX 0.19+                         │           支持            │       支持       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ win_scale_factor sysctl                  │           可用            │       可用       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ tcp.blackhole / udp.blackhole            │     可用（安全加固）      │       可用       │
  ├──────────────────────────────────────────┼───────────────────────────┼──────────────────┤
  │ iPhone Mirroring                         │       Sequoia 新增        │       继承       │
  └──────────────────────────────────────────┴───────────────────────────┴──────────────────┘

  三、Sequoia 特有的需要新增/调整的优化项

  1. Apple Intelligence 服务 — Sequoia 15.1+ 引入了 intelligenceplatformd、intelligenceflowd（但范围比 Tahoe 小，无 generativeexperiencesd）
  2. iPhone Mirroring 守护进程 — Sequoia 新增，开发工作站不需要
  3. Window Tiling — Sequoia 原生功能，保留不关
  4. 新增网络调优参数（来自 GitHub 项目，Tahoe 文档中缺失）：
    - kern.ipc.maxsockbuf=16777216
    - net.inet.tcp.win_scale_factor=8（RFC 7323）
    - net.inet.tcp.slowstart_flightsize=20
    - net.inet.tcp.local_slowstart_flightsize=20
    - net.inet.tcp.sack=1
    - net.inet.tcp.always_keepalive=1
    - net.inet.tcp.msl=5000
    - net.inet.tcp.blackhole=2（安全：丢弃到关闭端口的 TCP）
    - net.inet.udp.blackhole=1（安全：丢弃到关闭端口的 UDP）
  5. 新增 defaults 优化（Tahoe 文档缺失）：
    - NSDisableAutomaticTermination — 防止系统自动终止后台 App
    - NSUseAnimatedFocusRing -bool false — 关闭焦点环动画
    - DSDontWriteNetworkStores / DSDontWriteUSBStores — 网络/USB 不写 .DS_Store
    - DisableAirDrop — 禁用 AirDrop
  6. 新增服务禁用（GitHub 项目中有，Tahoe 文档遗漏）：
    - com.apple.translationd（翻译）
    - com.apple.shazamd（Shazam 音乐识别）
    - com.apple.sportsd（体育）
    - com.apple.homeenergyd（家庭能源）
    - com.apple.milod（个性化推荐）
    - com.apple.proactived（主动建议）
    - com.apple.corespeechd（语音识别核心）
    - AMP 系列（Apple Music 6 个守护进程）

  四、需要从 Tahoe 文档中移除的内容

  - Step K：reduceBlurring（Liquid Glass 专用）
  - Step O：Quick Note 热角修饰键（Tahoe 专用行为）
  - Step Q-4：WindowServer 26.2-26.3 卡顿修复
  - "不要关闭的服务"中的 modelcatalogd / modelmanagerd
  - "暂不更新到 26.5 Beta" 说明
  - Stage Manager 默认开启的说明

  ---
  信息已经足够了，可以开始生成 Sequoia 15.7.5 版本的优化文档。要我现在开始编写吗？