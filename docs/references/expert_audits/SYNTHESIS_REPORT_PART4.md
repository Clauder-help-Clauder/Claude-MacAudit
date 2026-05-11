### Phase 2: 体验升级 (3-5天) — 解决设计心理学问题

1. **评分语义统一** (C6强化)
   - Dashboard 显示两类分数：安全评分(9模块) + 信息建议(3模块)
   - 所有失败项显示风险等级标签（高/中/低）
   - 被排除模块的检查项标注"建议"而非"失败"

2. **FIX 反馈真实性** (C2强化)
   - shell 执行后验证实际状态（重新运行检测命令）
   - 成功/失败/部分成功 三态反馈
   - 失败时提供诊断信息和建议

3. **扫描体验闭环** (C5强化 + Norman反馈)
   - 扫描页添加进度条+取消按钮
   - 完成后显示摘要过渡页（非直接跳转）
   - 心理闭合："扫描完成，发现 X 个问题需要关注"

### Phase 3: 测试质量提升 (2-3天)

1. **行为测试优先** (Beck建议)
   - 审计现有测试，标记"结构测试"vs"行为测试"
   - 将关键行为测试优先级提升
   - 目标：行为测试占比从20%提升到50%

2. **添加并发安全测试**
   - ShellExecutor 取消传播测试
   - 并发模块执行竞争测试
   - FixHistory 原子写入崩溃恢复测试

3. **属性测试（建议新增）**
   - AuditCheck 所有字段组合的 Codable roundtrip
   - FixEngine regex 对任意输入的鲁棒性
   - 评分算法对任意模块组合的数学一致性

### Phase 4: 代码质量持续改进 (持续)

1. ShellExecutor 统一为单一并发模型
2. checks() 方法拆分（>100行的函数必须重构）
3. 消除魔法字符串，引入常量
4. AuditCheck 从贫血模型演进为富模型

---

## 七、审查文件索引

| 文件 | 专家 | 轮次 | 焦点 |
|------|------|------|------|
| EXPERT1_UX_KRUG_ROUND1.md | Steve Krug | R1 | 信息架构与导航 |
| EXPERT1_UX_KRUG_ROUND2.md | Steve Krug | R2 | 交互反馈与状态 |
| EXPERT1_UX_KRUG_ROUND3.md | Steve Krug | R3 | 认知负载与视觉 |
| EXPERT1_UX_KRUG_ROUND4.md | Steve Krug | R4 | CLI/TUI可用性 |
| EXPERT1_UX_KRUG_ROUND5.md | Steve Krug | R5 | 综合评分方案 |
| EXPERT2_CLEAN_CODE_BOB_ROUND1.md | Uncle Bob | R1 | SOLID原则 |
| EXPERT2_CLEAN_CODE_BOB_ROUND2.md | Uncle Bob | R2 | 架构边界 |
| EXPERT2_CLEAN_CODE_BOB_ROUND3.md | Uncle Bob | R3 | 代码清洁度 |
| EXPERT2_CLEAN_CODE_BOB_ROUND4.md | Uncle Bob | R4 | 设计模式 |
| EXPERT2_CLEAN_CODE_BOB_ROUND5.md | Uncle Bob | R5 | 综合评分方案 |
| EXPERT3_DESIGN_NORMAN_ROUND1.md | Don Norman | R1 | 示能与意符 |
| EXPERT3_DESIGN_NORMAN_ROUND2.md | Don Norman | R2 | 概念模型 |
| EXPERT3_DESIGN_NORMAN_ROUND3.md | Don Norman | R3 | 反馈系统 |
| EXPERT3_DESIGN_NORMAN_ROUND4.md | Don Norman | R4 | 情感设计 |
| EXPERT3_DESIGN_NORMAN_ROUND5.md | Don Norman | R5 | 综合评分方案 |
| EXPERT4_LOGIC_DIJKSTRA_ROUND1.md | Dijkstra | R1 | 状态机逻辑 |
| EXPERT4_LOGIC_DIJKSTRA_ROUND2.md | Dijkstra | R2 | 边界条件 |
| EXPERT4_LOGIC_DIJKSTRA_ROUND3.md | Dijkstra | R3 | 算法正确性 |
| EXPERT4_LOGIC_DIJKSTRA_ROUND4.md | Dijkstra | R4 | 并发逻辑 |
| EXPERT4_LOGIC_DIJKSTRA_ROUND5.md | Dijkstra | R5 | 综合评分方案 |
| EXPERT5_TDD_BECK_ROUND1.md | Kent Beck | R1 | 测试覆盖质量 |
| EXPERT5_TDD_BECK_ROUND2.md | Kent Beck | R2 | 测试隔离可靠 |
| EXPERT5_TDD_BECK_ROUND3.md | Kent Beck | R3 | 简单设计4规则 |
| EXPERT5_TDD_BECK_ROUND4.md | Kent Beck | R4 | 开发者体验 |
| EXPERT5_TDD_BECK_ROUND5.md | Kent Beck | R5 | 综合评分方案 |

---

> **五专家共识**: MacAudit 是一个功能完备、测试覆盖广泛的工具。其核心价值主张（macOS审计+调优）清晰且有用。主要问题集中在：(1) 架构层面的双模块结构缺陷，(2) 用户体验层面的反馈真实性和认知负载，(3) 形式正确性层面的边界条件处理。按路线图执行后，预计可将综合评分从 5.09 提升至 8.0+。
