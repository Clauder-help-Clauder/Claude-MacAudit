# Expert 3: Don Norman — 产品哲学与设计心理学审查 Round 2

## 审查焦点
**概念模型（Conceptual Models）与心智映射（Mental Mapping）** — 用户能否建立正确的系统工作模型？

## 发现的问题

### 问题 1: 评分计算逻辑隐藏，用户心智模型与实际行为不一致
- **严重程度**: CRITICAL
- **设计原则违反**: Conceptual Model（概念模型）
- **文件**: `AppViewModel.swift:128-143`
- **描述**: `systemScore` 排除了 services、dev、animation 模块，也排除了 skip/info 项和用户跳过的项。但用户看到 Dashboard 时，这些模块的分数和通过/失败数仍然显示在界面上。用户看到 "FAILED CHECKS: 12"，但系统分数可能显示 95%。这种不一致会严重破坏用户对评分系统的信任——"为什么有12个失败但分数是95？"
- **用户心理影响**: 困惑→不信任——"这个工具是不是坏了？分数是假的？"
- **修复建议**: 在 Dashboard 明确标注"个人偏好模块不参与系统评分"，或提供一个可见的评分规则说明。更好的方案是：在 statsRow 中区分"系统安全失败"和"个人偏好调整"。

### 问题 2: "审计→结果→修复"工作流的心智模型断裂
- **严重程度**: HIGH
- **设计原则违反**: Conceptual Model + Gulf of Execution
- **文件**: `AppViewModel.swift:186-235` + `DetailView.swift:264-284`
- **描述**: 用户完成审计后进入 ResultsView，看到 FAIL 项。点击 FAIL 项进入 DetailView，看到修复命令。但修复方式是"复制 shell 命令到终端执行"——这意味着用户必须离开应用，打开 Terminal.app，粘贴执行，然后回到应用。这个工作流与用户期望的"一键修复"心智模型严重不符。同时，InlineFixButton（ResultsView.swift:772）提供了应用内修复，但仅限非 sudo 命令，且两个入口的修复逻辑不一致。
- **用户心理影响**: 挫败——"为什么不能直接修复？"然后焦虑——"复制到终端安全吗？"
- **修复建议**: 统一修复入口，在 DetailView 中也提供 InlineFixButton（非 sudo 场景）。对于 sudo 命令，提供更安全的一步到位流程（如"在 Terminal 中打开"按钮，自动打开终端并粘贴命令）。

### 问题 3: 导航状态模型不透明
- **严重程度**: HIGH
- **设计原则违反**: Conceptual Model + Mapping
- **文件**: `AppViewModel.swift:12-19`（AppScreen enum）+ 全局导航
- **描述**: `AppScreen` 是一个 enum，包含 `.dashboard`、`.scanning`、`.results`、`.detail(checkId:)`、`.history`、`.settings` 六个状态。但界面上没有全局导航栏、面包屑或侧边栏来表示当前位置。用户从 Dashboard 点击模块卡片直接跳到 ResultsView（`DashboardView.swift:343`），从 ResultsView 点击检测项跳到 DetailView，但没有可见的"你在哪里"指示器。History 和 Settings 状态似乎没有入口。
- **用户心理影响**: 迷失——"我怎么到这里了？怎么回去？这个应用有几页？"
- **修复建议**: 添加轻量级面包屑（如 Dashboard > Results > Privacy > Detail），或侧边栏导航指示当前位置。

### 问题 4: DetailView 中 Current/Target 的比较设计缺乏视觉映射
- **严重程度**: MEDIUM
- **设计原则违反**: Mapping（映射）
- **文件**: `DetailView.swift:238-252`
- **描述**: Current State 和 Target State 并排显示，但缺乏视觉上的"从→到"映射关系。用户需要分别读取两个值，然后在脑中构建比较。对于技术用户来说可行，但对于"Mac用户"这个更广泛的群体，一个箭头、进度条或差异高亮会更直觉。
- **用户心理影响**: 认知负荷——需要主动解读两个值的含义和差异。
- **修复建议**: 添加 `→` 箭头连接两个区块，或对差异值部分用颜色高亮。

### 问题 5: 修复脚本的三级风险分类对用户不可见
- **严重程度**: MEDIUM
- **设计原则违反**: Conceptual Model
- **文件**: `AppViewModel.swift:268-351`
- **描述**: 内部有 safe/medium/critical 三级分类，但 RepairScriptSheet 只显示合并的脚本。用户无法区分哪些命令是安全的、哪些需要 sudo、哪些有网络风险。在 CheckListView 中有 `!SUDO` 标记，但仅对 CRITICAL 组显示。
- **用户心理影响**: 不安——"这些命令安全吗？会不会搞坏我的电脑？"
- **修复建议**: 在脚本展示中按风险级别分节显示，每节有明确的标题和说明。

## Tacit Knowledge 审查

1. **"扫描完成"的过渡太突兀**：`performAudit` 完成后直接 `selectedScreen = .results`，没有"扫描完成"的确认动画或过渡页面。用户看到雷达扫描画面，下一秒就跳到结果列表——缺少"处理完成"的心理闭合。

2. **DetailView 的 `>> Remediation Protocol` 标题**：这是黑客/安全工具的语言风格，对于普通 Mac 用户可能产生"这是不是太专业了"的距离感。同时，"Executing Risk Analysis"暗示系统正在分析，但实际上这只是静态展示——用户可能等待"分析完成"。

3. **cancelAudit 的行为**：取消审查后跳回 Dashboard 而非停留（用户可能想看部分结果），且已收集的结果被丢弃（`results = []` 在 performAudit 开始时清空）。这是一个破坏性的决定，但没有"确定要取消吗？"的确认。

## 本轮评分

| 维度 | 评分(1-10) | 说明 |
|------|-----------|------|
| 示能(Affordance) | 6 | 扫描按钮的意图明确，但修复操作路径不够直觉 |
| 意符(Signifier) | 5 | 导航缺少位置指示，用户不知道自己在哪 |
| 映射(Mapping) | 4 | 评分与展示不一致，Current/Target缺乏视觉关联 |
| 反馈(Feedback) | 6 | 扫描进度清晰，但完成过渡和取消确认缺失 |
| 概念模型 | 3 | 用户无法建立一致的"扫描→结果→修复"工作流模型 |
