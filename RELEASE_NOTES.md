# MacAudit v0.3.2 — GUI Window Polish

**Release Date**: 2026-05-13
**Build**: Universal Binary (arm64 + x86_64), Release optimized
**Tests**: 724/724 passing
**Scope**: GUI visual polish only — zero detection logic changes

---

## What's New (since v0.3.1)

### 🐛 Fixed

- **GUI 默认窗口裁掉 Logo**（v0.3.1 用户反馈）
  - `defaultSize`：1200 × 760 → **1440 × 860**
  - `minSize`：1000 × 680 → **1280 × 780**
  - LOGO 顶部 padding：16 → **35**（避让 macOS 左上角红绿黄按钮）
- `MacAuditApp` launcher 补上 `.windowResizability(.contentMinSize)` modifier，修复原先只在 `MacAuditUI` 备份版有的不一致

### ✨ Changed

- LOGO 到 Dashboard 菜单的间距 -30%（40 → 28）
- 侧边栏菜单每项垂直 padding -10%（18 → 16），5 项合计节省 ~20px 垂直空间
- 紧凑度提升，整体视觉密度更接近赛博朋克设计意图

### 🔒 No Change

- 检测项内容、数量、配置：和 v0.3.1 完全相同
- fix / undo / baseline / diff：机制和行为不变
- CLI 输出、JSON / Markdown 报告格式：完全兼容 v0.3.1
- 724 测试：全部继续通过（GUI 调整不涉及测试断言）
- **纯 GUI 可视化补丁**，CLI 用户可以跳过本版

---

## Breaking Changes

**None.** v0.3.1 用户升级 v0.3.2 所有功能、配置、fix-history、baseline 完全兼容。

## Upgrade Notes

- 重新下载 zip + 替换旧 `.app` 即可
- 无需重建 baseline / 清除 history
- 仍在 v0.3.0 或更早版本的用户：建议直连 v0.3.2，v0.3.1 的 Codex 保护 + AIBrands 架构都已包含

---

## VM Test Status

本版未重跑 VM 实测（改动纯 UI 层，无 detection / fix 逻辑变动）。v0.3.1 在 Sequoia 15.6.1 + Tahoe 26.0 的 fix/undo 闭环验证结果 1:1 继承到 v0.3.2。

---

**Full changelog**: [CHANGELOG.md](CHANGELOG.md)
**Source repo**: https://github.com/Clauder-help-Clauder/Claude-MacAudit

**Clauder Help Clauder.** ⭐
