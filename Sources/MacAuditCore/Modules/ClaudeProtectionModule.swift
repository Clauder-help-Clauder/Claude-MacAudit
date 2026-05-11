import Foundation

/// M10: AI 服务效率调优模块
/// v2 重构依据：Claude Code 封号机制逆向分析文档
/// 核心原则：融入而非消失。关闭遥测本身是风险行为。
public struct ClaudeProtectionModule: AuditModule {
    public init() {}

    public let id = "claude"
    public let name = "AI服务调优"
    public let description = "AI 服务效率与安全态势检测"



    // ── A 组：安全变量（正向检测，期望=设置）──────────────────────────────
    // 这些变量设置后有实际安全/稳定性价值，且不会增加风控风险
    private let safeEnvVars: [(varName: String, expected: String, name: String, enableNote: String, disableNote: String)] = [
        ("CLAUDE_CODE_PROXY_RESOLVES_HOSTS", "1", "代理 DNS 解析",
         "配合 HTTPS_PROXY 使用，让代理接管 DNS 防止 IP 泄露\n在 ~/.zshrc 中追加:\nexport CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1",
         "在 ~/.zshrc 中删除:\n# export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1"),
        ("CLAUDE_ENABLE_STREAM_WATCHDOG", "1", "流监控看门狗",
         "在 ~/.zshrc 中追加:\nexport CLAUDE_ENABLE_STREAM_WATCHDOG=1",
         "在 ~/.zshrc 中删除:\n# export CLAUDE_ENABLE_STREAM_WATCHDOG=1"),
        ("CLAUDE_CODE_SUBPROCESS_ENV_SCRUB", "1", "子进程凭据清洗",
         "防止子进程继承 API Key 等凭据，在 ~/.zshrc 中追加:\nexport CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1",
         "在 ~/.zshrc 中删除:\n# export CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1"),
        ("CLAUDE_STREAM_IDLE_TIMEOUT_MS", "90000", "流空闲超时",
         "在 ~/.zshrc 中追加:\nexport CLAUDE_STREAM_IDLE_TIMEOUT_MS=90000",
         "在 ~/.zshrc 中删除:\n# export CLAUDE_STREAM_IDLE_TIMEOUT_MS=90000"),
    ]

    public func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        var list: [AuditCheck] = []


        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 1. 风险信号检测（B组：危险变量反向检测）
        // 这些变量设置后会增加封号风险或导致付费功能失效
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        list.append(AuditCheck(
            id: "m10.env_no_disable_traffic", name: "禁止关闭非必要流量（风控风险）", module: id,
            description: """
⚠ 风险警告: CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 会增加封号风险
原因1（贝叶斯标签）: 关闭遥测的教程几乎只在中文社区传播，风控系统统计规律可直接推断地区
原因2（付费功能失效）: 触发链 DISABLE_NONESSENTIAL_TRAFFIC → isAnalyticsDisabled → isGrowthBookEnabled=false
  → Opus 4.6 1M 模型静默消失、Fast Mode 不可用、Remote Control 失效，且无任何报错提示
原因3（掩盖无效）: 关闭后每个 API 请求自身的 Attribution Header 和 cch Attestation 仍然发送
修复: sed -i '' '/export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=/d' ~/.zshrc
""",
            command: "source ~/.zshrc 2>/dev/null; echo ${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-not set}",
            expected: "not set",
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.env_no_disable_survey", name: "禁止关闭反馈调查（风控风险）", module: id,
            description: """
⚠ 风险警告: CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1 属于遥测关闭链路的一环
同样会在风控系统中增加地域风险标签
修复: sed -i '' '/export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=/d' ~/.zshrc
""",
            command: "source ~/.zshrc 2>/dev/null; echo ${CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY:-not set}",
            expected: "not set",
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.env_no_disable_telemetry", name: "禁止关闭遥测总开关（极高风险）", module: id,
            description: """
⚠ 极高风险: DISABLE_TELEMETRY=1 与 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 效果相同
这是风控系统中最危险的设置之一。关闭后：
- GrowthBook 被完全禁用（控制所有付费功能 Feature Flag）
- 自动成为风控系统中的异常用户
修复: sed -i '' '/export DISABLE_TELEMETRY=/d' ~/.zshrc
""",
            command: "source ~/.zshrc 2>/dev/null; echo ${DISABLE_TELEMETRY:-not set}",
            expected: "not set",
            priority: .a0
        ))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 2. 危险环境变量（服务端标记为危险）
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        list.append(contentsOf: [
            AuditCheck(id: "m10.env_no_custom_api", name: "ANTHROPIC_BASE_URL 未自定义（服务端危险变量）", module: id,
                       description: """
反向检测: ANTHROPIC_BASE_URL 若被设置，会通过 GrowthBook 的 apiBaseUrlHost 字段上报到服务端
服务端 Remote Managed Settings 模块将此标记为「危险环境变量」，设置后会被特别关注
修复: sed -i '' '/export ANTHROPIC_BASE_URL=/d' ~/.zshrc
""",
                       command: "source ~/.zshrc 2>/dev/null; echo ${ANTHROPIC_BASE_URL:-not set}",
                       expected: "not set",
                       priority: .a0),
            AuditCheck(id: "m10.env_no_tls_skip", name: "NODE_TLS_REJECT_UNAUTHORIZED 未禁用（服务端危险变量）", module: id,
                       description: """
反向检测: NODE_TLS_REJECT_UNAUTHORIZED=0 会跳过 TLS 证书验证
服务端 Remote Managed Settings 将此标记为「危险环境变量」，设置后会被特别关注
修复: sed -i '' '/export NODE_TLS_REJECT_UNAUTHORIZED=/d' ~/.zshrc
""",
                       command: "source ~/.zshrc 2>/dev/null; echo ${NODE_TLS_REJECT_UNAUTHORIZED:-not set}",
                       expected: "not set",
                       priority: .a0),
            AuditCheck(id: "m10.env_no_openai_base", name: "OPENAI_BASE_URL 未自定义（Codex 服务端危险变量）", module: id,
                       description: """
反向检测: OPENAI_BASE_URL 若被设置，会让 Codex 客户端改走自定义端点
与 ANTHROPIC_BASE_URL 机理相同：OpenAI 服务端会把非官方端点视作高风险标签
修复: sed -i '' '/export OPENAI_BASE_URL=/d' ~/.zshrc
""",
                       command: "source ~/.zshrc 2>/dev/null; echo ${OPENAI_BASE_URL:-not set}",
                       expected: "not set",
                       priority: .a0),
            AuditCheck(id: "m10.env_no_telemetry", name: "OTel 遥测未启用", module: id,
                       description: "反向检测: CLAUDE_CODE_ENABLE_TELEMETRY 若被设置为 1，会开启 OpenTelemetry 数据采集（默认关闭）\n修复: 从 ~/.zshrc 删除 export CLAUDE_CODE_ENABLE_TELEMETRY=1",
                       command: "source ~/.zshrc 2>/dev/null; echo ${CLAUDE_CODE_ENABLE_TELEMETRY:-not set}",
                       expected: "not set",
                       priority: .a0),
            AuditCheck(id: "m10.env_no_otel_prompts", name: "Prompt 日志未开启", module: id,
                       description: "反向检测: OTEL_LOG_USER_PROMPTS 若被设置，会将用户 Prompt 文本上传遥测系统（极高隐私风险）\n修复: 从 ~/.zshrc 删除 export OTEL_LOG_USER_PROMPTS=1",
                       command: "source ~/.zshrc 2>/dev/null; echo ${OTEL_LOG_USER_PROMPTS:-not set}",
                       expected: "not set",
                       priority: .a0),
            AuditCheck(id: "m10.env_no_otel_tools", name: "工具调用日志未开启", module: id,
                       description: "反向检测: OTEL_LOG_TOOL_CONTENT 若被设置，会将所有工具调用内容上传遥测\n修复: 从 ~/.zshrc 删除 export OTEL_LOG_TOOL_CONTENT=1",
                       command: "source ~/.zshrc 2>/dev/null; echo ${OTEL_LOG_TOOL_CONTENT:-not set}",
                       expected: "not set",
                       priority: .a0),
        ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 3. 安全基线（A组：正向检测）
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        let safeEnvEchoLines = safeEnvVars.map { "echo 'export \($0.varName)=\($0.expected)'" }.joined(separator: " && ")
        let safeEnvDelLines = safeEnvVars.map { "sed -i '' '/export \($0.varName)=/d' ~/.zshrc" }.joined(separator: " && ")
        let safeEnvSummaryDesc = """
添加防护: 复制以下命令粘贴到终端直接执行:
{ \(safeEnvEchoLines); } >> ~/.zshrc
取消防护: 复制以下命令粘贴到终端直接执行:
\(safeEnvDelLines)
"""
        // A组汇总（检测总状态，不单独修复——由下方独立项逐一修复）
        list.append(AuditCheck(
            id: "m10.env_safe_summary", name: "Claude Code 安全环境变量（A组汇总）", module: id,
            description: safeEnvSummaryDesc,
            command: "grep -c 'export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1' ~/.zshrc 2>/dev/null; true",
            expected: "1",
            priority: .a0
        ))

        // A组独立检测（含 description + fixCommand，与 MacAudit CLI 版同步）
        // 检测命令检查 ~/.zshrc 文件内容（因为 env var 写入后需要新 shell 才生效）
        for env in safeEnvVars {
            let desc = "\(env.enableNote)\n取消防护:\n\(env.disableNote)"
            list.append(AuditCheck(
                id: "m10.env_\(env.varName.lowercased().prefix(30))",
                name: env.name,
                module: id,
                description: desc,
                command: "grep -c 'export \(env.varName)=\(env.expected)' ~/.zshrc 2>/dev/null; true",
                expected: "1",
                fixRisk: .low,
                fixCommand: "sed -i '' '/^export \(env.varName)=/d' ~/.zshrc 2>/dev/null; echo 'export \(env.varName)=\(env.expected)' >> ~/.zshrc; true",
                priority: .a0
            ))
        }

        // C组：低影响变量（info 级别，不判 pass/fail）
        list.append(AuditCheck(
            id: "m10.env_disable_upgrade",
            name: "隐藏升级命令（低影响）",
            module: id,
            description: "信息: DISABLE_UPGRADE_COMMAND=1 隐藏 claude update 命令，不影响安全也不影响风控。无需主动设置。",
            command: "source ~/.zshrc 2>/dev/null; echo ${DISABLE_UPGRADE_COMMAND:-not set}",
            expected: nil,
            priority: .a0
        ))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 4. 环境信号检测（新增，身份/地理信号）
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        list.append(AuditCheck(
            id: "m10.device_id",
            name: "DeviceId 永久设备指纹",
            module: id,
            description: """
信息: ~/.claude.json 中的 deviceId 是跨账号永久设备指纹（64 字符随机十六进制）
即使更换账号，此 ID 不变。被封账号的 deviceId 会关联新账号，导致新账号风险评分拉满。
封号后清理步骤:
1. 备份: ~/.claude/skills/ ~/.claude/settings.json ~/.claude/CLAUDE.md ~/.claude/rules/
2. 删除: rm -rf ~/.claude/ && rm ~/.claude.json
""",
            command: "cat ~/.claude.json 2>/dev/null | grep -o 'deviceId' | head -1 || echo 'not found'",
            expected: nil,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.git_email_leak",
            name: "git user.email 身份泄露",
            module: id,
            description: """
信息: Claude Code 会读取 git config user.email 作为用户身份信号并上报到 GrowthBook
即使未用 OAuth 登录，邮箱也会被采集。这是一个容易被忽略的身份泄露点。
检查当前 git 邮箱: git config --global user.email
修改: git config --global user.email "your-preferred-email@example.com"
""",
            command: "git config --global user.email 2>/dev/null || echo 'not set'",
            expected: nil,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.npm_registry",
            name: "npm 源地理信号",
            module: id,
            description: """
添加防护: 使用官方 npm registry，避免中文社区专属镜像源被识别为地理信号
npm config set registry https://registry.npmjs.org/
取消防护（不推荐）:
npm config set registry https://registry.npmmirror.com/
⚠ npmmirror/tuna 等国内镜像是强地理位置信号。Claude Code 会探测已安装的包管理器信息。
""",
            command: "npm config get registry 2>/dev/null || echo 'not set'",
            expected: "https://registry.npmjs.org/",
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.tz_info",
            name: "时区环境信号",
            module: id,
            description: """
信息: Claude Code 遥测包含环境信息（platform/arch 等）。
TZ、LANG、LC_ALL 应与代理出口 IP 的地理位置一致。
最常见的穿帮：IP 在美国/日本，但 TZ=Asia/Shanghai 或 LANG=zh_CN
建议: TZ 与代理 IP 所在地区保持一致
""",
            command: "echo ${TZ:-$(date +%Z 2>/dev/null || echo 'not set')}",
            expected: nil,
            priority: .a0
        ))

        // LANG / LC_ALL 语言环境检测
        list.append(AuditCheck(
            id: "m10.lang_check",
            name: "LANG 语言环境信号",
            module: id,
            description: """
⚠ 风险信号: LANG 含 zh_CN / zh_TW 会直接暴露中文地区特征。
浏览器的 navigator.language 和系统 LANG 不一致也是风险点。
建议: LANG 应与代理 IP 所在地区一致（如美国代理 → en_US.UTF-8）
修复: echo 'export LANG=en_US.UTF-8' >> ~/.zshrc
""",
            command: "source ~/.zshrc 2>/dev/null; echo ${LANG:-not set}",
            expected: nil,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.lc_all_check",
            name: "LC_ALL 语言覆盖信号",
            module: id,
            description: """
⚠ 风险信号: LC_ALL 优先级高于 LANG，若设为 zh_CN.UTF-8 会覆盖所有语言设置暴露地区。
修复: echo 'export LC_ALL=en_US.UTF-8' >> ~/.zshrc
取消: sed -i '' '/export LC_ALL=/d' ~/.zshrc
""",
            command: "source ~/.zshrc 2>/dev/null; echo ${LC_ALL:-not set}",
            expected: nil,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.macos_lang",
            name: "macOS 系统语言首选项",
            module: id,
            description: """
⚠ 风险信号: macOS 系统语言列表第一项为中文（zh-Hans/zh-Hant）会暴露地区特征。
浏览器 User-Agent 中的语言偏好来自系统语言设置。
修复: System Settings → Language & Region → 添加 English，移到首位
""",
            command: "defaults read -g AppleLanguages 2>/dev/null | head -2 | tail -1 | tr -d '\" ()' | tr -d ' ' || echo 'not set'",
            expected: nil,
            priority: .a0
        ))


        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 6. 网络防护（代理/IPv6/防火墙）
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        let proxyAddCmd = """
添加防护（一次性部署代理函数 + 环境变量）:
  以下命令以 Surge 端口 6152 为例，请根据实际代理软件调整端口:
  Shadowrocket: 1082 | V2Ray: 1087 | Clash: 7890 | Trojan: 1080
复制以下命令粘贴到终端执行:
{ echo ''; echo 'all_proxy_on() {'; echo '  export http_proxy="http://127.0.0.1:6152"'; echo '  export https_proxy="http://127.0.0.1:6152"'; echo '  export HTTP_PROXY="http://127.0.0.1:6152"'; echo '  export HTTPS_PROXY="http://127.0.0.1:6152"'; echo '  export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"'; echo '  export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"'; echo '  echo "ProxyOn"'; echo '}'; echo ''; echo 'all_proxy_off() {'; echo '  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY'; echo '  echo "ProxyOff"'; echo '}'; echo ''; echo 'all_proxy_on > /dev/null 2>&1'; } >> ~/.zshrc
取消防护（一次性移除）:
sed -i '' '/^all_proxy_on()/,/^}/d' ~/.zshrc && sed -i '' '/^all_proxy_off()/,/^}/d' ~/.zshrc && sed -i '' '/^all_proxy_on > \\/dev\\/null/d' ~/.zshrc
"""
        list.append(contentsOf: [
            AuditCheck(id: "m10.proxy_functions", name: "代理出口函数（HTTPS_PROXY + all_proxy_on/off）", module: id,
                       description: proxyAddCmd,
                       command: "grep -c 'all_proxy_on' ~/.zshrc 2>/dev/null | awk '{print ($1>=1)?\"set\":\"not set\"}'",
                       expected: "set",
                       priority: .a0),
        ])

        let sandboxAddCmd = """
添加防护: 复制以下命令粘贴到终端直接执行:
jq '.network = (.network // {}) | .network.httpProxyPort = 6152 | .network.allowedDomains = ["api.anthropic.com","*.anthropic.com"] | .network.allowManagedDomainsOnly = true' ~/.claude/settings.json > ~/.claude/_tmp_settings.json && mv ~/.claude/_tmp_settings.json ~/.claude/settings.json
取消防护: 复制以下命令粘贴到终端直接执行:
jq 'del(.network.httpProxyPort) | del(.network.allowedDomains) | del(.network.allowManagedDomainsOnly)' ~/.claude/settings.json > ~/.claude/_tmp_settings.json && mv ~/.claude/_tmp_settings.json ~/.claude/settings.json
"""
        list.append(contentsOf: [
            AuditCheck(id: "m10.sandbox_proxy", name: "沙盒代理端口", module: id,
                       description: sandboxAddCmd,
                       command: "cat ~/.claude/settings.json 2>/dev/null | grep -c 'httpProxyPort'; true",
                       expected: "1",
                       fixRisk: .low,
                       fixCommand: "which jq > /dev/null 2>&1 && jq '.network = (.network // {}) | .network.httpProxyPort = 6152' ~/.claude/settings.json > ~/.claude/_tmp_settings.json && mv ~/.claude/_tmp_settings.json ~/.claude/settings.json || echo 'jq not installed, run: brew install jq'",
                       priority: .a0),
            AuditCheck(id: "m10.sandbox_domains", name: "沙盒域名白名单", module: id,
                       description: sandboxAddCmd,
                       command: "cat ~/.claude/settings.json 2>/dev/null | grep -c 'allowedDomains'; true",
                       expected: "1",
                       fixRisk: .low,
                       fixCommand: "which jq > /dev/null 2>&1 && jq '.network = (.network // {}) | .network.allowedDomains = [\"api.anthropic.com\",\"*.anthropic.com\",\"statsig.anthropic.com\",\"sentry.io\",\"api.openai.com\",\"*.openai.com\",\"chatgpt.com\",\"oaistatic.com\"]' ~/.claude/settings.json > ~/.claude/_tmp_settings.json && mv ~/.claude/_tmp_settings.json ~/.claude/settings.json || echo 'jq not installed, run: brew install jq'",
                       priority: .a0),
            AuditCheck(id: "m10.sandbox_managed", name: "仅允许托管域名", module: id,
                       description: sandboxAddCmd,
                       command: "cat ~/.claude/settings.json 2>/dev/null | grep -c 'allowManagedDomainsOnly'; true",
                       expected: "1",
                       fixRisk: .low,
                       fixCommand: "which jq > /dev/null 2>&1 && jq '.network = (.network // {}) | .network.allowManagedDomainsOnly = true' ~/.claude/settings.json > ~/.claude/_tmp_settings.json && mv ~/.claude/_tmp_settings.json ~/.claude/settings.json || echo 'jq not installed, run: brew install jq'",
                       priority: .a0),
        ])

        // Surge 防护
        list.append(contentsOf: [
            AuditCheck(id: "m10.surge_dns", name: "Surge Fake IP DNS", module: id,
                       description: "添加防护: 打开 Surge > 启用增强模式（Enhanced Mode）\n验证: scutil --dns | grep 198.18.0.2\n取消防护: Surge > 关闭增强模式",
                       command: "scutil --dns 2>/dev/null | grep -c '198.18.0.2'",
                       crossRef: "m3.surge_dns",
                       priority: .a0),
            AuditCheck(id: "m10.surge_tun", name: "Surge TUN 接口", module: id,
                       description: "添加防护: 打开 Surge > 启用增强模式（Enhanced Mode），Surge 会创建 utun 虚拟接口接管所有系统流量（含非 HTTP 协议）\n验证: ifconfig | grep utun\n正常 macOS 有 1-2 个 utun（系统 VPN），Surge 增强模式会额外添加 1-2 个\n取消防护: Surge > 关闭增强模式",
                       command: "ifconfig 2>/dev/null | grep -c 'utun'",
                       priority: .a0),
            AuditCheck(id: "m10.ipv6_global", name: "IPv6 全局地址", module: id,
                       description: "添加防护: 关闭所有网络接口的 IPv6，防止通过 IPv6 直连绕过代理出口\n复制以下命令到终端执行:\nnetworksetup -listallnetworkservices | grep -v '^\\*' | tail -n +2 | while read svc; do sudo networksetup -setv6off \"$svc\"; done\n取消防护:\nnetworksetup -listallnetworkservices | grep -v '^\\*' | tail -n +2 | while read svc; do sudo networksetup -setv6automatic \"$svc\"; done",
                       command: "ifconfig 2>/dev/null | grep inet6 | grep -v 'fe80\\|::1\\|%lo' | wc -l | tr -d ' '",
                       expected: "0", fixRisk: .high,
                       fixCommand: "networksetup -listallnetworkservices | grep -v '^\\*' | tail -n +2 | while read svc; do sudo networksetup -setv6off \"$svc\"; done",
                       crossRef: "m3.ipv6",
                       priority: .a0),
            AuditCheck(id: "m10.wifi_ipv6", name: "Wi-Fi IPv6", module: id,
                       description: "添加防护（二选一）:\n方法1 终端命令: sudo networksetup -setv6off Wi-Fi\n方法2 系统设置: 系统设置 → 网络 → Wi-Fi → 详细信息 → TCP/IP → 配置IPv6 → 选择「关闭」\n取消防护:\nsudo networksetup -setv6automatic Wi-Fi\n或: 系统设置 → 网络 → Wi-Fi → TCP/IP → 配置IPv6 → 选择「自动」",
                       command: "networksetup -getinfo Wi-Fi 2>/dev/null | grep '^IPv6:' | awk '{print $2}'",
                       expected: "Off", fixRisk: .medium,
                       fixCommand: "sudo networksetup -setv6off Wi-Fi",
                       crossRef: "m3.wifi_ipv6",
                       priority: .a0),
            AuditCheck(id: "m10.mdns", name: "mDNS 多播", module: id,
                       description: "禁用 mDNS 多播广告，防止本地网络泄露设备信息。\n添加防护:\nsudo defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements -bool true\nsudo launchctl stop com.apple.mDNSResponder && sudo launchctl start com.apple.mDNSResponder\n取消防护:\nsudo defaults delete /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements\nsudo launchctl stop com.apple.mDNSResponder && sudo launchctl start com.apple.mDNSResponder\n注意: killall -HUP 不足以让 mDNSResponder 重新读取 plist，需要完全重启 daemon。",
                       command: "defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements 2>/dev/null || echo '0'",
                       expected: "1", fixRisk: .medium,
                       fixCommand: "sudo defaults write /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements -bool true && sudo launchctl stop com.apple.mDNSResponder && sudo launchctl start com.apple.mDNSResponder && echo 'mDNS multicast disabled'",
                       crossRef: "m4.mdns",
                       priority: .a0),
            AuditCheck(id: "m10.captive", name: "Captive Portal", module: id,
                       description: "添加防护: 禁用 Captive Portal 自动弹窗，防止强制网络探测泄露信息\n复制以下命令到终端执行:\nsudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool false\n取消防护:\nsudo defaults write /Library/Preferences/SystemConfiguration/com.apple.captive.control Active -bool true",
                       command: "scutil --get ComputerName 2>/dev/null && defaults read /Library/Preferences/SystemConfiguration/CaptiveNetworkSupport Active 2>/dev/null || echo 'not set'",
                       expected: nil, crossRef: "m4.captive"),
            AuditCheck(id: "m10.ipv6_rtadv", name: "IPv6 路由通告", module: id,
                       description: "注意: net.inet6.ip6.accept_rtadv 在 macOS 上为只读 sysctl，无法直接修改。\n正确做法: 关闭所有网络接口的 IPv6。\n添加防护（二选一）:\n方法1 终端命令:\nnetworksetup -listallnetworkservices | grep -v '^An' | while IFS= read -r svc; do sudo networksetup -setv6off \"$svc\" 2>/dev/null; done\n方法2 系统设置: 对每个网络接口执行:\n  系统设置 → 网络 → [接口名] → 详细信息 → TCP/IP → 配置IPv6 → 选择「关闭」\n取消防护:\nnetworksetup -listallnetworkservices | grep -v '^An' | while IFS= read -r svc; do sudo networksetup -setv6automatic \"$svc\" 2>/dev/null; done",
                       command: "sysctl -n net.inet6.ip6.accept_rtadv 2>/dev/null",
                       expected: "0", fixRisk: .medium,
                       fixCommand: "networksetup -listallnetworkservices | grep -v '^An' | while IFS= read -r svc; do sudo networksetup -setv6off \"$svc\" 2>/dev/null; done && echo 'IPv6 disabled (RA stopped)'",
                       crossRef: "m8.ipv6_rtadv",
                       priority: .a0),
            AuditCheck(id: "m10.ipv6_fwd", name: "IPv6 转发", module: id,
                       description: "添加防护: 禁用 IPv6 数据包转发\n复制以下命令到终端执行:\nsudo sysctl -w net.inet6.ip6.forwarding=0\n取消防护:\nsudo sysctl -w net.inet6.ip6.forwarding=1",
                       command: "sysctl -n net.inet6.ip6.forwarding 2>/dev/null",
                       expected: "0", fixRisk: .medium,
                       fixCommand: "sudo sysctl -w net.inet6.ip6.forwarding=0",
                       crossRef: "m8.ipv6_fwd",
                       priority: .a0),
        ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 7. 防火墙和安全工具
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        list.append(contentsOf: [
            AuditCheck(id: "m10.fw_global", name: "防火墙开启", module: id,
                       description: "添加防护: 开启 macOS 应用防火墙，阻止未授权的入站连接\n复制以下命令到终端执行:\nsudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on\n取消防护:\nsudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -o 'enabled\\|disabled'",
                       expected: "enabled", fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on",
                       crossRef: "m2.firewall",
                       priority: .a0),
            AuditCheck(id: "m10.fw_stealth", name: "防火墙隐身", module: id,
                       description: "添加防护: 开启防火墙隐身模式，不响应 ICMP ping 和端口探测\n复制以下命令到终端执行:\nsudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on\n取消防护:\nsudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /enabled/{print \"enabled\";next} /disabled/{print \"disabled\";next} / on$/{print \"enabled\";next} / off$/{print \"disabled\";next}'",
                       expected: "enabled", fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on",
                       crossRef: "m2.stealth",
                       priority: .a0),
            AuditCheck(id: "m10.fw_signed", name: "防火墙签名", module: id,
                       description: "添加防护: 允许已签名的应用自动通过防火墙（推荐开启，避免误阻断 Claude Code）\n复制以下命令到终端执行:\nsudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on\n取消防护:\nsudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off",
                       command: "/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null | grep -oi 'ENABLED\\|DISABLED' | head -1 | tr '[:upper:]' '[:lower:]'",
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on",
                       crossRef: "m2.allowsigned"),
            AuditCheck(id: "m10.lulu", name: "LuLu 安装", module: id,
                       description: "添加防护:\nbrew install --cask lulu\n安装后在 System Settings > Privacy & Security > Network Filter 批准权限\n取消防护:\nsudo rm -rf /Applications/LuLu.app",
                       command: "test -d /Applications/LuLu.app && echo 'installed' || echo 'not installed'"),
            AuditCheck(id: "m10.knockknock", name: "KnockKnock 安装", module: id,
                       description: "添加防护:\nbrew install --cask knockknock\n取消防护:\nsudo rm -rf /Applications/KnockKnock.app",
                       command: "test -d /Applications/KnockKnock.app && echo 'installed' || echo 'not installed'"),
        ])

        // Surge Dashboard
        list.append(AuditCheck(
            id: "m10.surge_dashboard", name: "Surge Dashboard 绑定", module: id,
            description: "添加防护: 打开 Surge > 启动代理（Dashboard 端口 6170 监听）\n取消防护: pkill -x Surge",
            command: "lsof -nP -iTCP:6170 -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print $9}'",
            crossRef: "m3.surge_dashboard"
        ))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 8. macOS 遥测禁用（Apple 遥测，与 Claude 风控无关）
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        let telemetryAddCmd = """
添加防护: 复制以下命令粘贴到终端直接执行:
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false && defaults write com.apple.CrashReporter DialogType -string none && defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false && defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false && defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false
取消防护: 复制以下命令粘贴到终端直接执行:
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool true && defaults write com.apple.CrashReporter DialogType -string prompt && defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool true && defaults write com.apple.UsageTracking CoreDonationsEnabled -bool true && defaults write com.apple.UsageTracking UDCAutomationEnabled -bool true
"""
        list.append(contentsOf: [
            AuditCheck(id: "m10.telemetry_diaginfo", name: "Apple 诊断数据提交", module: id,
                       description: telemetryAddCmd,
                       command: "defaults read com.apple.SubmitDiagInfo AutoSubmit 2>/dev/null || echo 'not set'",
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false",
                       priority: .a0),
            AuditCheck(id: "m10.telemetry_crashreporter", name: "崩溃报告弹窗", module: id,
                       description: telemetryAddCmd,
                       command: "defaults read com.apple.CrashReporter DialogType 2>/dev/null || echo 'not set'",
                       expected: "none", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.CrashReporter DialogType -string none",
                       priority: .a0),
            AuditCheck(id: "m10.telemetry_adlib", name: "Apple 个性化广告", module: id,
                       description: telemetryAddCmd,
                       command: "defaults read com.apple.AdLib allowApplePersonalizedAdvertising 2>/dev/null || echo 'not set'",
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false",
                       priority: .a0),
            AuditCheck(id: "m10.telemetry_usage1", name: "iCloud 使用追踪", module: id,
                       description: telemetryAddCmd,
                       command: "defaults read com.apple.UsageTracking CoreDonationsEnabled 2>/dev/null || echo 'not set'",
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.UsageTracking CoreDonationsEnabled -bool false",
                       priority: .a0),
            AuditCheck(id: "m10.telemetry_usage2", name: "iCloud UDC 自动化", module: id,
                       description: telemetryAddCmd,
                       command: "defaults read com.apple.UsageTracking UDCAutomationEnabled 2>/dev/null || echo 'not set'",
                       expected: "0", risk: .safe,
                       fixRisk: .low,
                       fixCommand: "defaults write com.apple.UsageTracking UDCAutomationEnabled -bool false",
                       priority: .a0),
        ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 9. 代理辅助检测
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        list.append(AuditCheck(
            id: "m10.env_no_proxy", name: "NO_PROXY 无全局泄漏", module: id,
            description: """
检测 ~/.zshrc 中是否有函数外的独立 export NO_PROXY= 行（期望: 0）。
正确做法: NO_PROXY 只应在 all_proxy_on() 函数内部设置，不应全局 export。
如发现全局设置: sed -i '' '/^export NO_PROXY=/d;/^export no_proxy=/d' ~/.zshrc
""",
            command: "grep -c '^export NO_PROXY=\\|^export no_proxy=' ~/.zshrc 2>/dev/null; true",
            expected: "0",
            risk: .safe,
            fixRisk: .low,
            fixCommand: "sed -i '' '/^export NO_PROXY=/d;/^export no_proxy=/d' ~/.zshrc 2>/dev/null; true"
        ))

        list.append(AuditCheck(
            id: "m10.proxy_noproxy_in_func", name: "all_proxy_on 含 NO_PROXY 排除", module: id,
            description: """
检测 ~/.zshrc 中 all_proxy_on() 函数是否包含 NO_PROXY 本地排除配置（期望 ≥1 处）。
缺少 NO_PROXY 排除会导致代理开启时，localhost/127.0.0.1/内网地址也走代理，引发本地开发工具连接失败。
添加 NO_PROXY 到 all_proxy_on() 函数:
  grep -n 'all_proxy_on' ~/.zshrc  # 先找到函数位置
  然后在函数内添加:
  export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  export no_proxy="$NO_PROXY"
取消: 从 all_proxy_on() 中删除 NO_PROXY/no_proxy 行
""",
            command: "grep -c 'NO_PROXY\\|no_proxy' ~/.zshrc 2>/dev/null ; true",
            expected: nil,
            priority: .a0
        ))

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: - 10. 其他
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        list.append(AuditCheck(
            id: "m10.claude_improve", name: "Help improve Claude (对话训练开关)", module: id,
            description: """
⚠ 建议关闭: settings.json 中 enableTraining 若为 true，对话内容将用于模型训练，数据保留 5 年。
关闭方法:
  打开 claude.ai → 设置 → 隐私 → 关闭 "Help improve Claude"
  或检查 ~/.claude/settings.json 中是否包含 "enableTraining": true
""",
            command: "cat ~/.claude/settings.json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(\"enableTraining\", \"not set\"))' 2>/dev/null || echo 'not set'",
            risk: .safe,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.claude_version", name: "Claude Code 版本", module: id,
            description: "建议更新到最新版本\n更新命令: claude update",
            command: "claude --version 2>/dev/null || echo 'not installed'",
            risk: .safe,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.ipv6_all_interfaces", name: "全部接口 IPv6 状态", module: id,
            description: "添加防护: 复制以下命令粘贴到终端直接执行:\nnetworksetup -listallnetworkservices | grep -v '^\\*' | tail -n +2 | while read svc; do sudo networksetup -setv6off \"$svc\"; done\n取消防护: 复制以下命令粘贴到终端直接执行:\nnetworksetup -listallnetworkservices | grep -v '^\\*' | tail -n +2 | while read svc; do sudo networksetup -setv6automatic \"$svc\"; done",
            command: "networksetup -listallnetworkservices 2>/dev/null | grep -v '^\\*' | tail -n +2 | while read svc; do val=$(networksetup -getinfo \"$svc\" 2>/dev/null | grep '^IPv6:' | awk '{print $2}'); [ \"$val\" != \"Off\" ] && echo \"$svc:$val\"; done | wc -l | tr -d ' '",
            expected: "0", risk: .safe,
            networkRisk: true
        ))

        list.append(AuditCheck(
            id: "m10.surge_stun_reject", name: "Surge WebRTC STUN 拦截", module: id,
            description: "添加防护: 在 Surge 配置 [Rule] 段加入:\nAND,((PROTOCOL,STUN),(NOT,((OR,((DOMAIN-SUFFIX,anthropic.com),(DOMAIN-SUFFIX,claude.ai),(DOMAIN-SUFFIX,openai.com),(DOMAIN-SUFFIX,chatgpt.com)))))),REJECT\n取消防护: 从 Surge 配置删除上述规则",
            command: "find ~/Library/Application\\ Support/Surge -name '*.conf' 2>/dev/null -exec grep -li 'PROTOCOL,STUN\\|stun.*REJECT' {} \\; | wc -l | tr -d ' '",
            expected: "1", risk: .safe,
            priority: .a0
        ))

        list.append(AuditCheck(
            id: "m10.hosts_openai_block", name: "hosts 拉黑 OpenAI 域名（代理断开 fallback）", module: id,
            description: """
添加防护: 当代理断开时阻止 Codex 直连。在 /etc/hosts 追加以下行（对应 AIBrands.codex.domains 全集）:
0.0.0.0 api.openai.com
0.0.0.0 chatgpt.com
0.0.0.0 oaistatic.com
0.0.0.0 oaiusercontent.com
一键执行:
sudo sh -c 'printf "0.0.0.0 api.openai.com\\n0.0.0.0 chatgpt.com\\n0.0.0.0 oaistatic.com\\n0.0.0.0 oaiusercontent.com\\n" >> /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder'
取消防护: 手动编辑 /etc/hosts 删除上述四行
""",
            command: "grep -c -E '^0\\.0\\.0\\.0[[:space:]]+(api\\.openai\\.com|chatgpt\\.com|oaistatic\\.com|oaiusercontent\\.com)' /etc/hosts 2>/dev/null | awk '{print ($1>=4)?1:0}'",
            expected: "1",
            priority: .a0
        ))

        // 数据驱动：扫描所有支持的代理客户端配置，验证覆盖所有 AI 品牌域名
        let allAIDomains = AIBrands.all.flatMap(\.domains)
        let proxyDirsExpanded = ProxyClients.all
            .map { $0.configDir.replacingOccurrences(of: "~", with: "$HOME") }
        let domainRegex = allAIDomains
            .map { $0.replacingOccurrences(of: ".", with: "\\.") }
            .joined(separator: "|")
        let requiredDomainCount = allAIDomains.count
        let shellDirsArray = proxyDirsExpanded
            .map { "\"\($0)\"" }
            .joined(separator: " ")
        let proxyDescriptionList = ProxyClients.all
            .map { "- \($0.name): \($0.configDir)" }
            .joined(separator: "\n")
        let proxyScanCmd = "ok=0; for d in \(shellDirsArray); do [ -d \"$d\" ] || continue; hit=$(grep -rohE '\(domainRegex)' \"$d\" 2>/dev/null | sort -u | wc -l | tr -d ' '); if [ \"$hit\" -ge \(requiredDomainCount) ]; then ok=1; break; fi; done; [ \"$ok\" -eq 1 ] && echo ok || echo missing"

        list.append(AuditCheck(
            id: "m10.proxy_ai_domains",
            name: "代理软件覆盖 AI 品牌域名（Surge/Clash/V2Ray/Shadowrocket）",
            module: id,
            description: """
扫描以下代理客户端的配置目录，检查是否覆盖所有 AI 品牌域名（Claude + Codex）：
\(proxyDescriptionList)

需覆盖的域名（\(requiredDomainCount) 个）: \(allAIDomains.joined(separator: ", "))

添加防护:
1. 选择一款代理客户端（推荐 Surge）
2. 在其规则配置中为所有上述域名添加走代理的规则
3. 参考 docs/proxy_rules.md 的 Surge / Clash 配置示例

取消防护: 从代理规则中移除对应 DOMAIN-SUFFIX 条目
""",
            command: proxyScanCmd,
            expected: "ok",
            priority: .a0
        ))

        return list
    }

    public func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
