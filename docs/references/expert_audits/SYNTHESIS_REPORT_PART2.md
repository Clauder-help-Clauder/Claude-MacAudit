### C5: 扫描无法取消 [Krug]
- **发现者**: Expert 1 (Krug) Round 2
- **本质**: 扫描过程中无取消按钮
- **危害**: 用户启动审计后无法中止，只能强制退出

### C6: 评分计算与展示不一致 [Norman]
- **发现者**: Expert 3 (Norman) Round 2
- **本质**: 系统评分排除 services/dev/animation 模块，但界面仍显示其失败数
- **危害**: 用户看到 12 项检查有 3 项失败，但评分显示 100%，认知矛盾

### C7: FixHistory 非原子写入 [Dijkstra]
- **发现者**: Expert 4 (Dijkstra) Round 4
- **本质**: 修复历史 JSON 写入非原子操作
- **危害**: 进程中途崩溃会导致历史数据损坏

### C8: AppViewModel God Object [Uncle Bob]
- **发现者**: Expert 2 (Bob) Round 2
- **本质**: AppViewModel 637行，承担状态管理+评分+快照+过滤+修复
- **危害**: 任何改动都可能引发回归，违反SRP

---

## 三、HIGH 问题汇总

| # | 问题 | 发现者 | 维度 |
|---|------|--------|------|
| H1 | CLI 绕过 Core 直接实现模块 | Bob | 架构(DIP) |
| H2 | ShellExecutor 两份并发模型不一致 | Bob | 代码清洁度 |
| H3 | 模块卡片无可点击视觉暗示 | Norman | 示能(Affordance) |
| H4 | 扫描完成无心理闭合过渡 | Norman | 情感设计 |
| H5 | 超时参数可能溢出 | Dijkstra | 边界安全 |
| H6 | 取消状态不一致传播 | Dijkstra | 并发安全 |
| H7 | 80%测试验证数据结构而非行为 | Beck | 测试质量 |
| H8 | 颜色语义冲突(neonGreen=安全+进度) | Krug | 认知负载 |
| H9 | CLI 主菜单10项过多 | Krug | 信息架构 |

---

## 四、Philosophy & Tacit Knowledge 审查洞察

### 4.1 架构哲学冲突 (Uncle Bob)

**核心矛盾**: 项目声称4层target分离架构（CLI→Core→UI→App），但实际依赖规则未被执行。CLI target 内的 Modules 目录是架构的"叛逆者" — 它应该依赖 Core，而非自成一派。

**Tacit Knowledge**: 团队选择双模块是因为"历史原因"，但真正的原因是 Swift Package Manager 的 target 隔离让共享代码需要显式 import，而早期开发时 CLI 先行，没有预见到 GUI 需求。

### 4.2 设计心理学断层 (Don Norman)

**核心矛盾**: 工具声称帮助用户"审计安全"，但界面语言和视觉传达没有区分"信息"与"威胁"的边界。失败的检查项用红色标记但缺少严重性分级，导致用户对低风险问题产生与高风险问题同等程度的焦虑。

**Tacit Knowledge**: 用户使用审计工具时带着"我的电脑安全吗？"的焦虑心态。工具的每一次反馈都在加剧或缓解这种焦虑。当前的 FIX 按钮虚假成功是最糟糕的情况 — 它用虚假的掌控感替换了真实的焦虑。

### 4.3 程序正确性的"测试幻觉" (Dijkstra)

**核心矛盾**: 项目有 484 个测试且全部通过，但这不代表程序是正确的。DNSBL 的 IP 未验证、BaselineManager 的重复 key、FixHistory 的非原子写入 — 这些都是测试未覆盖的逻辑漏洞。

**Tacit Knowledge**: "全绿测试"给开发者虚假的安全感。Dijkstra 会说：测试只能证明 bug 的存在，不能证明 bug 的不存在。真正的正确性来自逻辑推理，不是来自测试数量。
