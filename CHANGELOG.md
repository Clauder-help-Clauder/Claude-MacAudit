# CHANGELOG

## v0.3.2 (2026-05-13)

### Fixed
- **GUI 默认窗口尺寸 logo 被裁切**（v0.3.1 反馈）：
  - `defaultSize`: 1200×760 → **1440×860**
  - `minSize`: 1000×680 → **1280×780**
  - LOGO 顶部 padding: 16 → **35**（避让 macOS 左上角红绿黄按钮）
- `MacAuditApp` launcher 补上 `.windowResizability(.contentMinSize)` modifier（原先只 UI 备份版有）

### Changed
- LOGO 到 Dashboard 菜单间距 -30%（40 → 28）
- 侧边栏菜单每项高度 -10%（vertical padding 18 → 16），5 项合计节省 ~20px 垂直空间
- 4 处 `MacAuditApp.swift` / `ContentView.swift` 在 MacAudit 开发树 + Github_upload 发版目录对齐

### No change
- 检测项内容、fix/undo 机制、CLI 行为、724 测试一切照旧
- 纯 GUI 可视化微调小版本

## v0.3.1 (2026-05-12)

### Added
- `AIBrands.swift` 单一数据源架构：集中管理 AI 品牌（Claude / Codex）的域名和服务端危险变量
- `m10.proxy_ai_domains`：扫描 7 款主流代理客户端（Surge / Surge-iCloud / ClashVerge / ClashX / V2RayU / V2RayX / Shadowrocket）的配置目录，验证 AI 域名覆盖
- `m10.env_no_openai_base`：反向检测 `OPENAI_BASE_URL`（Codex 服务端危险变量，机理同 `ANTHROPIC_BASE_URL`）
- `m10.hosts_openai_block`：检测 `/etc/hosts` 拉黑 OpenAI 域名，代理断开时的 fallback 防护

### Changed
- `m10.sandbox_domains` 的一键 fix 现在同时写入 Claude + OpenAI 域名白名单到 `~/.claude/settings.json`
- `m10.surge_stun_reject` 的 WebRTC STUN 白名单扩展到 OpenAI 域名（`openai.com` / `chatgpt.com`）
- 6 项 B 组环境变量检测命令统一补 `source ~/.zshrc 2>/dev/null;` 前缀（修复 GUI 子进程不继承 shell env 的历史问题）
- M10 活跃检测计数下限 30 → 33（配合 v0.3.1 新增 3 项检测）

### Architecture
- 未来新增 AI 品牌（Gemini / Copilot / DeepSeek 等）只需在 `AIBrands.all` 追加一行；所有数据驱动的检测项自动扩展覆盖

### Tests
- 全量 724 测试通过；M10 模块从 27 测试增至 31 测试
