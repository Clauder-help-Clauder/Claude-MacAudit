# Expert 1: Steve Krug — UX可用性审查 Round 1

## 审查焦点
信息架构与导航：导航层级、用户寻路能力、3秒法则验证、迷失感检测。

## 发现的问题

### 问题 1: 导航命名与用户心智模型严重脱节
- **严重程度**: HIGH
- **文件**: `ContentView.swift:41-43`
- **描述**: 侧边栏导航项使用 "Security" 作为 Results 的标签，但用户刚完成审计时，心智预期是"结果"而非"安全"。同样 "Dashboard" 对新用户来说含义模糊——它到底是仪表盘、总览还是主页？`AppScreen` 枚举有 `.scanning` 和 `.detail` 两个状态，但侧边栏中没有对应入口，用户无法理解这两个隐藏屏幕从何而来、如何到达。
- **用户影响**: 新用户首次打开应用时，无法在3秒内判断"审计结果在哪里"。`Dashboard` 与 `Security` 的功能边界模糊——Dashboard 已有 RingChart 显示分数，Security 页面也有分数，存在信息重叠。
- **修复建议**: 将 "Security" 重命名为 "Audit Results" 或 "Scan Results"。在侧边栏底部添加 "Current Scan" 状态指示器，当扫描进行时自动高亮/切换。确保 `.scanning` 和 `.detail` 状态在导航中有明确入口。

### 问题 2: 隐藏屏幕导致导航不连贯
- **严重程度**: HIGH
- **文件**: `ContentView.swift:301-309`
- **描述**: `AppScreen` 枚举定义了6个 case（dashboard/scanning/results/detail/history/settings），但侧边栏只有4个导航项。`.scanning` 和 `.detail(let id)` 是不可达的隐藏状态，用户无法通过导航栏直接感知或访问。当用户从 Results 点击某个 check 进入 Detail 页面后，侧边栏没有任何视觉指示当前处于哪个上下文中。
- **用户影响**: 用户在 Detail 页面时产生"我在哪里"的迷失感。没有面包屑或返回按钮的明确指引，用户只能依赖记忆或随意点击侧边栏来脱离。
- **修复建议**: 在 TopBar 的 pathString 中添加面包屑导航，例如 `ROOT > RESULTS > DETAIL > [checkName]`，并让面包屑每一级可点击。在 Detail 页面添加明确的 "← Back to Results" 按钮。

### 问题 3: TopBar 路径伪代码增加认知噪音而非辅助导航
- **严重程度**: MEDIUM
- **文件**: `ContentView.swift:138-147`
- **描述**: TopBar 使用伪造的文件系统路径（如 `PATH: /VOLUMES/MAC_HD/SYSTEM/SECURITY`）作为位置指示。这些路径与实际文件系统无关，与导航层级也不对应——用户点击 Dashboard 看到的是 `/ROOT/MACAUDIT/DASHBOARD`，点击 Security 看到的是 `/VOLUMES/MAC_HD/SYSTEM/SECURITY`。路径风格不一致（有的在 ROOT 下，有的在 VOLUMES 下），且不可交互。
- **用户影响**: 技术用户可能尝试理解这些路径的含义而浪费时间；非技术用户直接忽略但会觉得界面"很乱"。既不提供导航辅助，也不提供位置信息，纯粹是装饰性噪音。
- **修复建议**: 如果保留路径风格，至少让它与实际导航层级一致且可交互。或者替换为更直观的面包屑 `Dashboard > Results > Detail`。

### 问题 4: StatusBar 信息过载且无实际功能
- **严重程度**: MEDIUM
- **文件**: `ContentView.swift:203-276`
- **描述**: 底部状态栏同时展示 SYSTEM HEALTH、DAEMON、SYNC_SECURED、LATENCY、SESSION、LOC、SECURE SHELL v4.2 共7个信息项。其中 "DAEMON: ACTIVE"、"SYNC_SECURED"、"SECURE SHELL v4.2"、"LOC: 127.0.0.1" 看起来像是伪造的技术状态，不反映真实的系统状态。"LATENCY: 0.04ms" 是硬编码值。
- **用户影响**: 大量无意义的技术装饰文字占据了视觉注意力，让用户误以为这是某种远程终端工具而非本地审计工具。新用户可能花时间寻找这些"功能"在哪里配置，徒增认知负载。
- **修复建议**: 移除或替换虚假状态信息。只保留真正有用的信息（如上次审计时间、版本号）。如果需要终端美学，至少使用真实数据。

### 问题 5: ResultsView 的 HSplitView 缺乏宽度约束指引
- **严重程度**: MEDIUM
- **文件**: `ResultsView.swift:82-191`
- **描述**: HSplitView 左侧模块列表设置了 `minWidth: 260, maxWidth: 320`，右侧是动态内容。但右侧 CheckListView 内容非常密集（包含分组标题、检查行、FIX/SKIP 按钮、IP质量检查说明等），当窗口较窄时内容会被严重压缩。用户可以自由拖动分割线但没有默认最佳比例的引导。
- **用户影响**: 在小窗口下，右侧内容可读性急剧下降。IP质量模块的外部检查说明区块（490-553行）包含大量中文文本和URL，在窄面板中几乎无法阅读。
- **修复建议**: 为右侧面板设置合理的 minWidth（如480px）。考虑在小屏幕下将分割视图切换为 Tab 式浏览。

### 问题 6: 模块短名称映射表硬编码且不可维护
- **严重程度**: LOW
- **文件**: `DashboardView.swift:380-396`
- **描述**: `shortName` 函数使用硬编码字典将中文名称映射为英文缩写。如果模块名称变化或新增模块，映射会失败，回退为 `name.uppercased()`。中英文混搭的映射逻辑分散在 Dashboard 中而非数据模型层。
- **用户影响**: 模块条显示的名称可能突然变为一长串中文的大写形式，破坏视觉一致性。
- **修复建议**: 将 shortName 移至 ModuleSummary 模型中作为计算属性，或让每个 AuditModule 自带 shortName。

### 问题 7: Dashboard 到 Results 的跳转缺乏上下文传递
- **严重程度**: MEDIUM
- **文件**: `DashboardView.swift:342-343`
- **描述**: 点击 moduleStrip 中的模块卡片时，直接设置 `vm.selectedScreen = .results`，但没有同时设置 `vm.selectedModuleId`。用户点击 Dashboard 上的 "NETWORK" 模块期望看到该模块的详情，但实际跳转到 Results 页面后，左侧列表没有自动选中对应模块。
- **用户影响**: 用户点击特定模块卡片后到达 Results 页面，却看不到期望的模块被选中，需要再次在列表中寻找。这违反了"点击→期望→满足"的基本交互闭环。
- **修复建议**: 在 moduleCard 的点击事件中同时设置 `vm.selectedModuleId = summary.id`，确保跳转+选中一步完成。

## Tacit Knowledge 审查

1. **终端美学的隐性代价**: 设计团队选择了赛博朋克/终端美学风格（neon green、脉冲指示器、Matrix下落点、伪造路径），这在视觉上很酷，但隐性代价是：普通 macOS 用户（而非开发者）会本能地认为这是一个"给黑客用的工具"而非"给普通用户的安全检查工具"。这种心理障碍可能导致用户不敢点击 "FIX" 按钮，因为他们不确定这是否安全。

2. **"INITIATE AUDIT" 按钮的语言门槛**: 使用全大写英文 "INITIATE FULL SYSTEM AUDIT" 对中文用户构成认知障碍。虽然目标用户可能是技术用户，但"INITIATE"比"START"或"开始"更难快速理解。用户的眼睛在大写全字母词上滑动时速度比混合大小写慢约13%。

3. **RingChart 零分状态的困惑**: Dashboard 空状态显示一个0分的RingChart，配合"NO AUDIT DATA"文字。但用户可能误以为"我的系统得了0分"而非"还没有数据"。空状态应该用完全不同的视觉表达（如空白盾牌图标）而非0分圆环。

## 本轮评分

| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 直觉性 | 5 | 导航命名不直觉，隐藏页面增加迷失风险 |
| 一致性 | 7 | 视觉风格统一，但导航路径与层级不一致 |
| 反馈性 | 6 | 选中状态有视觉反馈，但跨屏跳转缺乏上下文 |
| 容错性 | 6 | 无明显破坏性操作风险，但返回路径不清晰 |
| 效率 | 5 | Dashboard→模块详情需2步操作，应可1步完成 |
