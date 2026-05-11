# M4 Test Plan — 三轮专家审查综合报告

> 生成日期: 2026-04-23
> 审查轮次: 3 (Round 1: 5专家独立审查 → Round 2: 交叉验证 → Round 3: 最终综合)
> 审查专家: E1-Dr.Elena(Security) / E2-Kenji(Compatibility) / E3-Sarah(Architecture) / E4-Raj(Coverage) / E5-Marcus(Reliability)

---

## 一、审查总览

### 发现统计

| 严重级别 | 数量 | 说明 |
|---------|------|------|
| CRITICAL | 6 | 必须在执行前修复 |
| HIGH | 9 | 应在 M4 中修复 |
| MEDIUM | 4 | 可推迟到 M4+1 |
| LOW | 2 | 不影响执行 |
| **总计** | **21** | 去重后（原始 30+） |

### 关键结论

1. **原计划文件数低估 37%**: 计划说 16 个文件，实际需修改 22 个（遗漏 FixEngine×2, ShellExecutor×2, AuditModule×2）
2. **原计划工时低估 ~50%**: 计划 4-5h，修正后 7-8h（增加：前置分歧修复 +1h，测试编写 +2.5h，验证 +0.5h）
3. **双副本架构已存在 3 处分歧**: PrivacyModule、ClaudeProtectionModule、AuditModule 的 CLI/Core 两份代码逻辑不一致
4. **Chrome 模块 undo 完全失效**: 所有 14 个 fixCommand 使用 PlistBuddy（非 `defaults write`），generateUndoCommand 的正则无法匹配任何一个
5. **T2/T3 已完成**: socketfilterfw 已用新参数，plutil 已用 PlistBuddy 绕过，两个待办可关闭

---

## 二、CRITICAL 发现详情

### U-01: FixEngine.generateUndoCommand() 注入风险
- **来源**: SEC-001 / ARCH-02 / COMPAT-005 / REL-04（4 位专家独立发现）
- **位置**: `FixEngine.swift:157-184`（两副本）
- **问题**: `previousValue` 未转义直接插入 shell 命令。Tahoe 26 `defaults read` 返回 `{ "-bool" = true; }` 时，undo 命令变为 `defaults write ... -bool { "-bool" = true; }` — 无效命令
- **修复**: Shell 转义 + 归一化 previousValue

### U-02: 比较引擎零格式容错
- **来源**: ARCH-04 / SEC-002
- **位置**: `AuditModule.swift:64` — `actual.lowercased() == expected.lowercased()`
- **问题**: 纯字符串比较，无类型感知。Tahoe dict 格式与 `"0"/"1"` 永远不匹配 → 所有 bool 检测项误报 FAIL
- **修复**: 在比较层添加 `normalizeDefaultsBool()` 归一化

### U-04: SafariModule 零测试覆盖
- **来源**: COV-002
- **问题**: `Tests/MacAuditTests/SafariModuleTests.swift` 不存在。13 个检测项无任何测试
- **修复**: 从零创建测试文件

### U-05: ChromeModule 零测试覆盖
- **来源**: COV-003
- **问题**: `Tests/MacAuditTests/ChromeModuleTests.swift` 不存在。14 个检测项无任何测试
- **修复**: 从零创建测试文件

### B-02: Chrome undo 引擎根本性缺失
- **来源**: Round 2 盲点发现
- **问题**: Chrome 所有 fixCommand 使用 `PlistBuddy`，`generateUndoCommand` 正则只匹配 `defaults write/delete` → 全部 Chrome fix 无法自动回滚
- **修复**: 扩展 undo 生成器支持 PlistBuddy 模式

### U-13: FixEngine Tahoe undo 无测试
- **来源**: COV-004
- **问题**: 现有测试只覆盖 "not set"/"N/A"/简单值，未覆盖 Tahoe dict 格式 previousValue
- **修复**: 添加 Tahoe 格式 undo 测试

---

## 三、HIGH 发现详情

| ID | 标题 | 位置 | 修复建议 |
|----|------|------|---------|
| U-03 | pmset_not_found 哨兵值分歧 | AuditModule Core:59,106 vs CLI | 统一两副本的哨兵处理 |
| U-06 | newValue 提取对复合命令错误 | FixEngine.swift:127 | 从 `&&` 前的第一段命令提取 |
| U-08 | PrivacyModule 双副本分歧 | PrivacyModule CLI:56-93 vs Core:53-76 | mDNS/captive 检测命令不同，需统一 |
| U-09 | ClaudeProtection 矛盾期望值 | ClaudeProtection 6+ check | CLI 和 Core 对同一检查有不同的 expected/fixCommand |
| U-10 | NetworkSecurity Core 缺 fixCommand | Core NetworkSecurityModule | m3 项目和 m8.sysctl_plist 缺修复命令 |
| U-11 | swift test 违反 CLAUDE.md | M4_WORK_PLAN.md:116 | 改用 `bash scripts/build_app.sh` |
| U-14 | ShellExecutor 10s 超时不够 | ShellExecutor.swift:21 | SSH 场景需 30s |
| U-16 | Safari popup_block 复合 undo | SafariModule.swift:74 | `&&` 链接两个 defaults write，undo 只处理第一个 |

---

## 四、Round 2 交叉验证关键发现

1. **ClaudeProtectionModule 矛盾升级**: `m10.env_no_proxy` CLI 期望 `"not set"`，Core 期望 `"localhost"` — 完全相反
2. **AuditModule 双副本分歧**: Core 有 `pmset_not_found` 哨兵 → 返回 `.info`；CLI 无此哨兵 → 返回 `.fail`
3. **方案裁决**: E2 建议 shell 端归一化，E3 建议 Swift 比较层归一化 → **方案 C（混合）正确**，需两层都做
4. **测试工时修正**: E4 估计 3-4h → 修正为 5-6h（因双副本 + Chrome PlistBuddy 复杂度）

---

## 五、执行顺序修正

**原计划**: Safari → Chrome → Privacy → Animation → Claude → NetworkSecurity → Power → Shell

**修正后**:

```
Phase 0 — 前置分歧修复 (60 min)
  ├── 修复 PrivacyModule mDNS/captive 分歧
  ├── 修复 ClaudeProtectionModule 矛盾期望值
  └── 统一 AuditModule pmset_not_found 哨兵

Phase 1 — 基础设施 (45 min)
  ├── ShellExecutor: 添加 normalizeDefaultsBool()
  ├── AuditModule: 比较层添加归一化
  ├── FixEngine: previousValue 转义 + Tahoe 格式处理
  └── FixEngine: 扩展 undo 正则支持 PlistBuddy

Phase 2 — 试点模块: Power + Shell + NetworkSecurity (30 min)
  ├── 修改 3 个最小模块验证方案可行性
  └── swift test --filter 验证

Phase 3 — 批量修复 (2.5 hr)
  ├── Safari (含 popup_block 拆分)
  ├── Chrome (验证 PlistBuddy undo)
  ├── Claude + Privacy
  ├── Animation (最大，~45 checks)
  └── 每个 module pair 后 git commit

Phase 4 — 全量验证 (1.5 hr)
  ├── 完整测试套件 (492+ tests)
  ├── 双副本一致性检查
  └── Tahoe VM 集成测试 (如可用)
```

**总工时: 7-8 小时**（含测试编写）
