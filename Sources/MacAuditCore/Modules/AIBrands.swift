/// 单一 AI 品牌定义。未来新增品牌（Gemini/Copilot/DeepSeek 等）只需在 `AIBrands` 中追加一个 `static let`。
public struct AIBrand: Sendable {
    public let id: String
    public let displayName: String
    /// 需要走代理的所有域名（API + 前端 + 静态资源 + 遥测）。
    public let domains: [String]
    /// 服务端标记为"危险"的环境变量（BASE_URL 重定向类；API Key 不在此列，因其为正常凭据）。
    /// 反向检测：设置则 warn。
    public let dangerousEnvVars: [String]
}

/// 所有支持的 AI 品牌。新增品牌：复制一行 `static let` 并加入 `all` 数组。
public enum AIBrands {
    public static let claude = AIBrand(
        id: "claude",
        displayName: "Claude",
        domains: [
            "anthropic.com",
            "claude.ai",
            "claude.com",
            "claude.dev",
            "claudeusercontent.com",
            "statsigapi.net",
            "datadoghq.com",
            "intercom.io"
        ],
        dangerousEnvVars: ["ANTHROPIC_BASE_URL"]
    )

    public static let codex = AIBrand(
        id: "codex",
        displayName: "Codex / OpenAI",
        domains: [
            "openai.com",
            "chatgpt.com",
            "oaistatic.com",
            "oaiusercontent.com"
        ],
        dangerousEnvVars: ["OPENAI_BASE_URL"]
    )

    public static let all: [AIBrand] = [claude, codex]
}

/// 用户可能使用的系统代理客户端。检测 AI 域名是否在任意一款的配置中。
public enum ProxyClients {
    public struct Client: Sendable {
        public let name: String
        /// 配置目录（支持 `~` 前缀；检测时会展开为 `$HOME`）。
        public let configDir: String
    }

    public static let all: [Client] = [
        .init(name: "Surge",          configDir: "~/Library/Application Support/Surge/Profiles"),
        .init(name: "Surge-iCloud",   configDir: "~/Library/Mobile Documents/iCloud~com~nssurge~inc/Documents"),
        .init(name: "ClashVerge",     configDir: "~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles"),
        .init(name: "ClashX",         configDir: "~/.config/clash"),
        .init(name: "V2RayU",         configDir: "~/.V2RayU"),
        .init(name: "V2RayX",         configDir: "~/Library/Application Support/V2RayX"),
        .init(name: "Shadowrocket",   configDir: "~/Library/Mobile Documents/iCloud~com~shadowlaunch~shadowrocket/Documents"),
    ]
}
