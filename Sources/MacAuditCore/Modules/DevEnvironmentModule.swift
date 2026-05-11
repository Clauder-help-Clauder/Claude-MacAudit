import Foundation

/// M11: 开发工具模块
public struct DevEnvironmentModule: AuditModule {
    public init() {}
    public let id = "dev"
    public let name = "开发工具"
    public let description = "开发工具链和环境配置检测"

    private struct ToolDef {
        let id: String
        let name: String
        let command: String
        let expected: String?
        let versions: Set<MacOSVersion>
        let architectures: Set<CPUArchitecture>
        let description: String
        let fixCommand: String?

        init(_ id: String, _ name: String, _ cmd: String,
             _ expected: String? = nil, _ versions: Set<MacOSVersion> = [],
             architectures: Set<CPUArchitecture> = [],
             description: String = "", fix: String? = nil) {
            self.id = id; self.name = name; self.command = cmd
            self.expected = expected; self.versions = versions
            self.architectures = architectures
            self.description = description; self.fixCommand = fix
        }
    }

    private let tools: [ToolDef] = [
        // ── 基础工具链 ─────────────────────────────────────────────────────
        ToolDef("xcode_clt", "Xcode CLT",
                "xcode-select -p 2>/dev/null || echo 'not installed'",
                description: """
Xcode Command Line Tools：编译 Swift/C/C++/ObjC 的基础组件，也是 Homebrew 的依赖。
安装: xcode-select --install
验证安装: xcode-select -p
更新（如已安装）: sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install
""",
                fix: "xcode-select --install"),

        ToolDef("clang", "Clang 版本",
                "clang --version 2>/dev/null | head -1 | sed 's/.*version //' | awk '{print $1}'",
                description: """
Clang C/C++/ObjC 编译器（随 Xcode CLT 安装）。
Apple Clang 是 LLVM 的 Apple 定制版，通常与 macOS SDK 深度集成。
查看完整版本: clang --version
若未安装: xcode-select --install
"""),

        ToolDef("xcodebuild", "Xcode 版本",
                "xcodebuild -version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
Xcode 构建工具版本（需要完整 Xcode，不仅仅是 CLT）。
安装完整 Xcode:
  App Store 搜索 Xcode 安装（约 10GB）
  或命令行: xcodes install latest（需先 brew install xcodesorg/made/xcodes）
切换 Xcode 版本（多版本时）: sudo xcode-select -s /Applications/Xcode_15.app
"""),

        ToolDef("brew", "Homebrew",
                "brew --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
Homebrew：macOS 最流行的包管理器，几乎所有开发工具都通过它安装。
安装（官方脚本）:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
Apple Silicon 安装路径: /opt/homebrew/bin/brew
Intel Mac 安装路径: /usr/local/bin/brew
安装后需将路径加入 PATH（Apple Silicon）:
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc && source ~/.zshrc
更新 Homebrew: brew update && brew upgrade
""",
                fix: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""),

        ToolDef("brew_path", "Homebrew 路径",
                "which brew 2>/dev/null || echo 'not found'",
                description: """
Homebrew 可执行文件路径。
期望值：
  Apple Silicon (M1/M2/M3/M4): /opt/homebrew/bin/brew
  Intel Mac: /usr/local/bin/brew
若路径不符，说明 Homebrew 可能安装在非标准位置，或 PATH 配置不正确。
修复 PATH（Apple Silicon）: echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc && source ~/.zshrc
"""),

        ToolDef("brew_analytics", "Homebrew analytics",
                "brew analytics 2>/dev/null | head -1 || echo 'unknown'",
                description: """
Homebrew 遥测统计状态。应显示 "Analytics are disabled" 或 "Analytics are turned off"。
关闭遥测（推荐）: brew analytics off
验证: brew analytics
开启（不推荐）: brew analytics on
""",
                fix: "brew analytics off"),

        ToolDef("brew_doctor", "brew 路径检查",
                "brew --prefix 2>/dev/null | head -1 || echo 'not found'",
                description: """
Homebrew 安装前缀路径（prefix）。
期望：Apple Silicon = /opt/homebrew，Intel = /usr/local
若路径异常，运行: brew doctor
brew doctor 会检测并报告配置问题（如 PATH 冲突、孤立包等）。
"""),

        // ── 运行时 ──────────────────────────────────────────────────────────
        ToolDef("nvm", "nvm",
                "test -f ~/.nvm/nvm.sh && echo 'installed' || echo 'not found'",
                description: """
nvm（Node Version Manager）：管理多个 Node.js 版本。
安装（官方方式，与 Homebrew brew install nvm 不同）:
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
安装后在 ~/.zshrc 中会自动添加（或手动添加）:
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"
使用: nvm install --lts  |  nvm use 20  |  nvm ls
""",
                fix: "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"),

        ToolDef("node", "Node.js",
                "node -v 2>/dev/null || echo 'not installed'",
                description: """
Node.js 运行时（Claude Code 和大多数 AI CLI 工具的依赖）。
通过 nvm 安装（推荐，便于版本管理）:
  nvm install --lts           # 安装最新 LTS 版本
  nvm use --lts               # 切换到 LTS
  nvm alias default node      # 设为默认
直接通过 Homebrew 安装（如不用 nvm）: brew install node
Claude Code 建议 Node 版本: v18+ （当前推荐 v20 LTS 或 v22 LTS）
""",
                fix: "nvm install --lts 2>/dev/null || brew install node"),

        ToolDef("npm", "npm",
                "npm -v 2>/dev/null || echo 'not installed'",
                description: """
npm：Node.js 默认包管理器（随 Node.js 安装）。
更新到最新版本: npm install -g npm@latest
查看全局安装的包: npm list -g --depth=0
清理缓存（磁盘空间不足时）: npm cache clean --force
""",
                fix: "npm install -g npm@latest"),

        ToolDef("bun", "Bun",
                "bun --version 2>/dev/null || echo 'not installed'",
                description: """
Bun：现代 JavaScript 运行时 + 包管理器（比 npm install 快 20-100 倍）。
特点：内置打包器、测试框架、原生 TypeScript 支持，Apple Silicon 高度优化。
安装: curl -fsSL https://bun.sh/install | bash
使用: bun install  |  bun run  |  bun test  |  bunx <command>
Claude Code 相关: bun 可替代 npx 执行 one-shot 命令，速度更快
""",
                fix: "curl -fsSL https://bun.sh/install | bash"),

        ToolDef("tsc", "TypeScript",
                "tsc --version 2>/dev/null || echo 'not installed'",
                description: """
TypeScript 编译器（Claude Code 及大量工具的开发语言）。
全局安装（用于命令行使用）: npm install -g typescript
项目级安装（推荐）: npm install -D typescript
初始化 tsconfig: npx tsc --init
常用命令: tsc --noEmit（只做类型检查，不输出文件）
""",
                fix: "npm install -g typescript"),

        ToolDef("pyenv", "pyenv",
                "pyenv --version 2>/dev/null || echo 'not installed'",
                description: """
pyenv：Python 版本管理器（类似 nvm for Python）。
安装: brew install pyenv
安装后在 ~/.zshrc 添加:
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
安装指定 Python 版本: pyenv install 3.12.4
设为全局默认: pyenv global 3.12.4
查看可安装版本: pyenv install --list
""",
                fix: "brew install pyenv"),

        ToolDef("python", "Python",
                "python3 --version 2>/dev/null || echo 'not installed'",
                description: """
Python 3 解释器（多种 AI/ML 工具依赖，如 PyTorch/MLX/LangChain）。
通过 pyenv 安装（推荐）:
  pyenv install 3.12.4 && pyenv global 3.12.4
通过 Homebrew 安装: brew install python@3.12
通过 uv 安装（最快）: uv python install 3.12
建议版本: Python 3.11+ 或 3.12（Claude SDK、MLX 等工具的推荐版本）
""",
                fix: "brew install python@3.12"),

        ToolDef("uv", "uv",
                "uv --version 2>/dev/null || echo 'not installed'",
                description: """
uv：超快速 Python 包管理器（Astral 出品，Rust 编写，比 pip 快 10-100 倍）。
安装: curl -LsSf https://astral.sh/uv/install.sh | sh
主要用途:
  uv pip install <package>     # 替代 pip install（快得多）
  uv venv .venv                # 快速创建虚拟环境
  uv run script.py             # 无需激活 venv 直接运行
  uv python install 3.12       # 安装 Python 版本（替代 pyenv）
Claude Code 相关: MCP 服务器的 Python 依赖推荐用 uv 安装
""",
                fix: "curl -LsSf https://astral.sh/uv/install.sh | sh"),

        ToolDef("rustc", "Rust",
                "rustc --version 2>/dev/null || echo 'not installed'",
                description: """
Rust 编译器（Claude Code 部分 MCP 工具、高性能工具的编写语言）。
安装（官方 rustup 工具链管理器）:
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
更新到最新稳定版: rustup update stable
查看已安装工具链: rustup toolchain list
安装后建议也安装 rust-analyzer（IDE 支持）: rustup component add rust-analyzer
""",
                fix: "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"),

        ToolDef("cargo", "Cargo",
                "cargo --version 2>/dev/null || echo 'not installed'",
                description: """
Cargo：Rust 包管理器和构建工具（随 Rust 安装）。
常用命令:
  cargo new <project>     # 新建项目
  cargo build --release   # 编译优化版本
  cargo test              # 运行测试
  cargo install <crate>   # 安装命令行工具（如 cargo install ripgrep）
若 rustc 已安装但 cargo 未找到，确认 PATH 包含 ~/.cargo/bin:
  echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
""",
                fix: "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"),

        ToolDef("go", "Go",
                "go version 2>/dev/null || echo 'not installed'",
                description: """
Go 语言运行时（部分 MCP 服务器和开发工具使用 Go 编写）。
安装: brew install go
验证: go version
配置 GOPATH（默认为 ~/go）:
  echo 'export GOPATH="$HOME/go"' >> ~/.zshrc
  echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.zshrc
更新 Go 版本: brew upgrade go
安装工具（如 golangci-lint）: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
""",
                fix: "brew install go"),

        ToolDef("java", "Java",
                "java -version 2>&1 | head -1 || echo 'not installed'",
                description: """
Java 运行时（部分 AI 工具、Spring Boot 应用依赖）。
安装（推荐使用 Eclipse Temurin，免费开源）:
  brew install --cask temurin@21         # Java 21 LTS
  brew install --cask temurin@17         # Java 17 LTS
  brew install --cask temurin@11         # Java 11 LTS（旧版兼容）
设置 JAVA_HOME（安装后）:
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)
  echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 21)' >> ~/.zshrc
多版本切换: export JAVA_HOME=$(/usr/libexec/java_home -v 17)
""",
                fix: "brew install --cask temurin@21"),

        // ── Sequoia 专属 ──────────────────────────────────────────────────
        ToolDef("pyenv_deps", "pyenv 编译依赖",
                "brew list openssl readline zlib xz 2>/dev/null | head -1 && echo 'ok' || echo 'missing'",
                nil, [.sequoia],
                description: """
【Sequoia 专属】pyenv 在 macOS 15 Sequoia 下编译 Python 源码所需的依赖。
缺少这些依赖会导致 pyenv install 失败（无法编译 Python 扩展模块）。
安装所有依赖: brew install openssl readline zlib xz
验证: brew list openssl readline zlib xz
若 pyenv install 仍报错，可能还需要:
  brew install bzip2 libffi ncurses sqlite
Sequoia 特别说明: openssl@3 会自动安装，但 readline 和 zlib 需要手动安装
""",
                fix: "brew install openssl readline zlib xz"),

        ToolDef("orbstack_seq", "OrbStack >= 2.0.4",
                "orb version 2>/dev/null || echo 'not installed'",
                nil, [.sequoia],
                description: """
【Sequoia 专属】OrbStack 需要 2.0.4+ 版本才能完全兼容 macOS 15 Sequoia。
旧版本在 Sequoia 下可能出现：容器网络异常、文件挂载问题、性能下降。
安装/更新到最新版: brew install --cask orbstack
验证版本: orb version
OrbStack 相比 Docker Desktop 的优势（Apple Silicon 优化）:
  - 启动速度快 10 倍
  - 内存占用低 3 倍
  - 完整支持 Apple Silicon Native 编译
""",
                fix: "brew install --cask orbstack"),

        // ── Tahoe 专属 ────────────────────────────────────────────────────
        ToolDef("mlx", "MLX 框架",
                "python3 -c 'import mlx; print(mlx.__version__)' 2>/dev/null || echo 'not installed'",
                nil, [.tahoe],
                architectures: [.arm64],
                description: """
【Tahoe 专属】Apple MLX：专为 Apple Silicon 设计的机器学习框架（类似 PyTorch）。
macOS 26 Tahoe 对 MLX 有更深度的系统集成和性能优化。
安装: pip install mlx 或 uv pip install mlx
安装 MLX 生态工具:
  pip install mlx-lm              # LLM 推理（可运行 Llama/Mistral 等）
  pip install mlx-data             # 数据加载
  pip install mlxlm mlx-vlm        # 语言/视觉模型
运行本地 LLM（Tahoe 推荐方式）:
  mlx_lm.generate --model mlx-community/Llama-3.2-3B-Instruct-4bit --prompt "你好"
相比 Ollama，MLX 在 Tahoe 上性能更高，推荐 AI 开发者使用。
""",
                fix: "pip install mlx"),

        // ── Rust 组件 ─────────────────────────────────────────────────────
        ToolDef("rust_components", "Rust 组件",
                "rustup component list --installed 2>/dev/null | wc -l | tr -d ' ' || echo 0",
                description: """
已安装的 Rust 工具链组件数量（如 rust-src、rust-analyzer、clippy、rustfmt）。
安装推荐组件套件:
  rustup component add rust-src rust-analyzer clippy rustfmt
主要组件说明:
  rust-src：IDE 跳转定义所需的标准库源码
  rust-analyzer：LSP 语言服务器（VS Code 等编辑器智能补全）
  clippy：Rust 代码质量检查（lint）
  rustfmt：代码格式化
""",
                fix: "rustup component add rust-src rust-analyzer clippy rustfmt"),

        // ── Git 工具链 ────────────────────────────────────────────────────
        ToolDef("git", "Git",
                "git --version 2>/dev/null || echo 'not installed'",
                description: """
Git 版本控制系统（系统自带版本较旧，建议通过 Homebrew 安装最新版）。
安装最新版 Git: brew install git
安装后需要更新 PATH 优先级（确保使用 Homebrew 版本）:
  which git    # 应显示 /opt/homebrew/bin/git
若仍指向 /usr/bin/git（系统版本），在 ~/.zshrc 确保 Homebrew bin 在 PATH 前面。
配置 Git（首次使用）:
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  git config --global core.editor "code --wait"  # 使用 VS Code 作为编辑器
""",
                fix: "brew install git"),

        ToolDef("git_lfs", "git-lfs",
                "git lfs version 2>/dev/null || echo 'not installed'",
                description: """
Git Large File Storage：处理大文件（模型权重、数据集、媒体文件）的 Git 扩展。
安装: brew install git-lfs && git lfs install
验证: git lfs version
常用命令:
  git lfs track "*.bin"        # 追踪大文件类型
  git lfs ls-files             # 查看 LFS 管理的文件
  git lfs fetch --all          # 下载所有 LFS 文件
AI 开发场景：从 HuggingFace 克隆模型仓库时必须开启 LFS。
""",
                fix: "brew install git-lfs && git lfs install"),

        ToolDef("gh", "GitHub CLI",
                "gh --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
GitHub 官方 CLI 工具：命令行操作 GitHub（PR/Issue/Release）。
安装: brew install gh
认证登录: gh auth login
常用命令:
  gh pr create            # 创建 PR
  gh pr list              # 查看 PR 列表
  gh issue create         # 创建 Issue
  gh repo clone owner/repo  # 克隆仓库
  gh workflow run         # 触发 Actions 工作流
Claude Code 集成: gh 是 Claude Code 执行 GitHub 操作的依赖工具之一
""",
                fix: "brew install gh"),

        ToolDef("lazygit", "lazygit",
                "lazygit --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
lazygit：终端 Git 可视化界面（键盘驱动的 TUI，比 git 命令更直观）。
安装: brew install lazygit
使用: 在 Git 仓库中直接运行 lazygit
特点：
  - 可视化 diff、暂存区、分支管理
  - 交互式 rebase
  - 支持一键 cherry-pick
  - Claude Code 可直接调用
""",
                fix: "brew install lazygit"),

        ToolDef("delta", "delta",
                "delta --version 2>/dev/null || echo 'not installed'",
                description: """
delta：Git diff/grep 语法高亮美化工具（替代默认的 diff 输出）。
安装: brew install git-delta
配置到 git（在 ~/.gitconfig 中）:
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.side-by-side true
效果：彩色高亮、行号显示、并排对比模式。
""",
                fix: "brew install git-delta && git config --global core.pager delta"),

        ToolDef("git_pager", "GIT_PAGER",
                "echo ${GIT_PAGER:-not set}",
                description: """
GIT_PAGER 环境变量控制 git 输出的分页器。
推荐设置为 delta（更好的 diff 高亮）:
  git config --global core.pager delta
  # 或设置环境变量:
  echo 'export GIT_PAGER=delta' >> ~/.zshrc
使用 less（默认，无需安装）:
  git config --global core.pager 'less -FRX'
禁用分页（适合脚本）:
  git config --global core.pager ''
"""),

        ToolDef("git_safe_dup", "git safe.directory 重复",
                "git config --global --list 2>/dev/null | grep -c safe.directory; true",
                description: """
git safe.directory 重复条目会拖慢 git 启动速度（每次执行 git 命令都要解析配置）。
查看重复条目: git config --global --list | grep safe.directory
清理重复条目（保留 '*' 通配符）:
  git config --global --unset-all safe.directory
  git config --global --add safe.directory '*'
出现大量重复通常是因为：git 添加了多个目录的白名单，每个目录单独一条记录。
""",
                fix: "git config --global --unset-all safe.directory 2>/dev/null; git config --global --add safe.directory '*'; true"),

        ToolDef("git_config", "git 全局配置项数",
                "git config --global --list 2>/dev/null | wc -l | tr -d ' '",
                description: """
Git 全局配置项总数（~/.gitconfig 文件中的配置行数）。
查看所有配置: git config --global --list
重要建议配置清单:
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  git config --global core.pager delta
  git config --global pull.rebase false
  git config --global init.defaultBranch main
  git config --global push.autoSetupRemote true
  git config --global fetch.prune true
查看配置文件: cat ~/.gitconfig
"""),

        // ── 效率工具 ──────────────────────────────────────────────────────
        ToolDef("rg", "ripgrep",
                "rg --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
ripgrep：极速代码搜索工具（比 grep 快 10-100 倍，Claude Code 内部大量使用）。
安装: brew install ripgrep
常用命令:
  rg "pattern" ./src           # 搜索指定目录
  rg --type ts "useState"      # 搜索特定文件类型
  rg -l "TODO"                 # 只显示文件名
  rg --hidden "pattern"        # 包含隐藏文件
注意：Claude Code 在代码搜索时直接调用 rg，是重要的性能依赖。
""",
                fix: "brew install ripgrep"),

        ToolDef("fzf", "fzf",
                "fzf --version 2>/dev/null || echo 'not installed'",
                description: """
fzf：模糊搜索工具（文件/历史记录/任何内容的交互式模糊匹配）。
安装: brew install fzf && $(brew --prefix)/opt/fzf/install
安装后的快捷键（在终端中）:
  Ctrl+R：模糊搜索命令历史（替代 Ctrl+R 的默认行为）
  Ctrl+T：模糊搜索文件路径并插入到命令行
  Alt+C：模糊搜索目录并 cd 进入
与其他工具集成: cat file.txt | fzf  |  vim $(fzf)  |  kill $(ps aux | fzf | awk '{print $2}')
""",
                fix: "brew install fzf && $(brew --prefix)/opt/fzf/install --all"),

        ToolDef("jq", "jq",
                "jq --version 2>/dev/null || echo 'not installed'",
                description: """
jq：命令行 JSON 处理工具（Claude Code API 响应调试必备）。
安装: brew install jq
常用命令:
  cat response.json | jq '.'                     # 格式化输出
  cat response.json | jq '.data[0].name'         # 提取字段
  cat response.json | jq '.[] | select(.age>18)' # 过滤
  curl -s https://api.github.com/users/octocat | jq '.name'
配合 Claude API 使用:
  curl -s -X POST https://api.anthropic.com/v1/messages ... | jq '.content[0].text'
""",
                fix: "brew install jq"),

        ToolDef("bat", "bat",
                "bat --version 2>/dev/null || echo 'not installed'",
                description: """
bat：cat 命令的现代替代（语法高亮 + 行号 + Git 变更标记）。
安装: brew install bat
使用: bat file.swift  |  bat README.md
配置为默认 cat（可选）: echo 'alias cat=bat' >> ~/.zshrc
配置 man 手册高亮（可选）:
  echo 'export MANPAGER="sh -c \\'col -bx | bat -l man -p\\'"' >> ~/.zshrc
Claude Code 集成: 可配置为 less 替代品以获得彩色输出
""",
                fix: "brew install bat"),

        ToolDef("eza", "eza",
                "eza --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
eza：ls 命令的现代替代（颜色 + 图标 + Git 状态 + 树状显示）。
安装: brew install eza
常用别名（加入 ~/.zshrc）:
  alias ls='eza --icons'
  alias ll='eza -l --icons --git'
  alias la='eza -la --icons --git'
  alias lt='eza --tree --icons --level=2'
特点：比 lsd/exa（已停更）更活跃维护，支持显示 Git 文件状态。
""",
                fix: "brew install eza"),

        ToolDef("htop", "htop",
                "htop --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
htop：交互式进程监控工具（Activity Monitor 的命令行版本）。
安装: brew install htop
使用: htop（交互式）| htop -d 10（1秒刷新）
快捷键:
  F5：树状视图（查看进程父子关系）
  F6：排序（CPU/MEM/TIME）
  F9：发送信号（杀死进程）
  Space：标记进程（批量操作）
Claude Code 使用时可用于监控 AI 任务的资源消耗。
""",
                fix: "brew install htop"),

        ToolDef("ncdu", "ncdu",
                "ncdu --version 2>/dev/null || echo 'not installed'",
                description: """
ncdu（NCurses Disk Usage）：交互式磁盘占用分析工具。
安装: brew install ncdu
使用:
  ncdu /           # 分析根目录（可能需要 sudo）
  ncdu ~           # 分析主目录（速度更快）
  ncdu --exclude .git ./  # 排除 .git 目录
快捷键: d=删除选中项, i=文件信息, n=按名称排序, s=按大小排序
适合快速找出占用大量磁盘空间的目录（如 node_modules、Docker 镜像、LLM 模型文件）。
""",
                fix: "brew install ncdu"),

        ToolDef("wget", "wget",
                "wget --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
wget：文件下载工具（curl 的补充，支持递归下载和断点续传）。
安装: brew install wget
使用:
  wget https://example.com/file.zip                    # 基本下载
  wget -c https://example.com/large.bin               # 断点续传
  wget -r -np https://example.com/docs/               # 递归下载整个目录
  wget --header='Authorization: Bearer TOKEN' url     # 带认证头下载
若使用代理: wget -e "https_proxy=http://127.0.0.1:6152" url
""",
                fix: "brew install wget"),

        ToolDef("fd", "fd",
                "fd --version 2>/dev/null || echo 'not installed'",
                description: """
fd：find 命令的现代替代（更快、语法更简洁、默认忽略 .gitignore）。
安装: brew install fd
使用:
  fd "*.swift" ./Sources        # 搜索 Swift 文件
  fd -t d "node_modules"        # 只搜索目录
  fd -e json                    # 搜索指定扩展名
  fd --hidden "\\.env"           # 搜索隐藏文件
比 find 优势：默认彩色输出、忽略 .git、速度快 2-10 倍。
""",
                fix: "brew install fd"),

        ToolDef("yq", "yq",
                "yq --version 2>/dev/null || echo 'not installed'",
                description: """
yq：YAML/JSON/XML/TOML 命令行处理工具（类似 jq 但支持更多格式）。
安装: brew install yq
使用:
  yq '.services.web.image' docker-compose.yml    # 读取字段
  yq '.version = "3.9"' docker-compose.yml       # 修改字段
  yq -o=json config.yaml                         # YAML 转 JSON
  cat config.json | yq -P                        # JSON 转 YAML（美化）
适合编辑 Kubernetes YAML、Docker Compose、GitHub Actions 配置。
""",
                fix: "brew install yq"),

        ToolDef("tree", "tree",
                "tree --version 2>/dev/null || echo 'not installed'",
                description: """
tree：目录树可视化工具。
安装: brew install tree
使用:
  tree ./src                     # 显示目录树
  tree -L 2 ./src               # 限制深度为 2
  tree -I 'node_modules|.git'   # 排除特定目录
  tree -a                       # 包含隐藏文件
  tree --gitignore              # 遵守 .gitignore（新版 tree 支持）
Claude Code 中可用于快速了解项目结构: tree -L 2 --gitignore
""",
                fix: "brew install tree"),

        ToolDef("lazydocker", "lazydocker",
                "lazydocker version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
lazydocker：Docker 容器可视化管理 TUI 界面（类似 lazygit for Docker）。
安装: brew install lazydocker
使用: 在项目目录运行 lazydocker（需要 Docker 或 OrbStack 运行中）
特点：
  - 实时查看容器日志
  - 交互式管理容器/镜像/网络/存储卷
  - 一键清理未使用资源
快捷键: x=执行命令, e=打开配置, d=删除
""",
                fix: "brew install lazydocker"),

        // ── 容器/AI ───────────────────────────────────────────────────────
        ToolDef("orbstack", "OrbStack",
                "orb version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
OrbStack：性能最佳的 macOS Docker 容器运行时（Apple Silicon 深度优化）。
安装: brew install --cask orbstack
相比 Docker Desktop：
  - 启动时间 < 2 秒（Docker Desktop 需 30+ 秒）
  - 内存占用 < 300MB（Docker Desktop 需 1-2GB）
  - 完整支持 Apple Silicon Native 编译（arm64 镜像）
  - 内置 Linux 虚拟机（可 ssh 进入）
  - 集成 GUI 仪表盘
安装后：Docker CLI 自动可用，无需额外配置
""",
                fix: "brew install --cask orbstack"),

        ToolDef("docker", "Docker",
                "docker --version 2>/dev/null || echo 'not installed'",
                description: """
Docker CLI（推荐通过 OrbStack 提供，而非单独安装 Docker Desktop）。
安装（通过 OrbStack，推荐）: brew install --cask orbstack
安装（仅 CLI，配合远程 Docker 服务器使用）: brew install docker
验证连接: docker info
常用命令:
  docker ps -a                     # 查看所有容器
  docker images                    # 查看所有镜像
  docker system df                 # 查看磁盘使用
  docker system prune -a           # 清理所有未使用资源
""",
                fix: "brew install --cask orbstack"),

        ToolDef("ollama", "Ollama",
                "ollama --version 2>/dev/null || echo 'not installed'",
                description: """
Ollama：本地 LLM 运行框架（支持 Llama/Mistral/Phi/Gemma 等模型）。
安装: brew install ollama
启动服务: ollama serve（或 brew services start ollama）
常用命令:
  ollama pull llama3.2          # 下载模型（3.2B 参数，约 2GB）
  ollama pull phi4              # Phi-4（高性价比小模型）
  ollama run llama3.2           # 交互式聊天
  ollama list                   # 查看已下载模型
  ollama ps                     # 查看运行中的模型
Apple Silicon 优化：Ollama 自动使用 Metal GPU 加速推理。
Claude Code 集成: 可通过 MCP 将本地 Ollama 模型接入 Claude Code
""",
                fix: "brew install ollama"),

        ToolDef("ollama_gpu", "OLLAMA_GPU_LAYERS",
                "echo ${OLLAMA_GPU_LAYERS:-not set}",
                description: """
OLLAMA_GPU_LAYERS 控制 Ollama 加载到 GPU（Metal）的模型层数。
Apple Silicon 建议设置: OLLAMA_GPU_LAYERS=-1（全部层加载到 GPU，最高性能）
设置（永久）: echo 'export OLLAMA_GPU_LAYERS=-1' >> ~/.zshrc && source ~/.zshrc
设置（当前 session）: export OLLAMA_GPU_LAYERS=-1
值说明:
  -1 = 全部层（Apple Silicon 推荐）
  0  = 纯 CPU 模式（测试用）
  N  = 加载 N 层到 GPU（内存受限时使用）
验证效果: ollama ps（查看 GPU 利用率显示 100%）
""",
                fix: "grep -q 'OLLAMA_GPU_LAYERS' ~/.zshrc 2>/dev/null || echo 'export OLLAMA_GPU_LAYERS=-1' >> ~/.zshrc"),

        ToolDef("ollama_models", "OLLAMA_MAX_LOADED_MODELS",
                "echo ${OLLAMA_MAX_LOADED_MODELS:-not set}",
                description: """
OLLAMA_MAX_LOADED_MODELS 控制同时加载到内存的最大模型数（默认 1）。
Apple Silicon 建议配置:
  16GB RAM: 1（单模型）
  32GB RAM: 2（两个小模型并行）
  64GB RAM: 3-4（多模型同时服务）
设置（永久）: echo 'export OLLAMA_MAX_LOADED_MODELS=2' >> ~/.zshrc && source ~/.zshrc
增大此值可以减少模型切换时的加载延迟，但会增加内存占用。
""",
                fix: "grep -q 'OLLAMA_MAX_LOADED_MODELS' ~/.zshrc 2>/dev/null || echo 'export OLLAMA_MAX_LOADED_MODELS=2' >> ~/.zshrc"),

        ToolDef("ollama_parallel", "OLLAMA_NUM_PARALLEL",
                "echo ${OLLAMA_NUM_PARALLEL:-not set}",
                description: """
OLLAMA_NUM_PARALLEL 控制单个模型可处理的并发请求数（默认 1）。
提高并发数可减少多用户/应用同时请求时的等待，但会增加显存消耗。
推荐配置:
  日常使用（1 用户）: 不设置（默认 1）
  开发测试（多并发）: echo 'export OLLAMA_NUM_PARALLEL=4' >> ~/.zshrc
  API 服务模式: echo 'export OLLAMA_NUM_PARALLEL=8' >> ~/.zshrc
""",
                fix: "grep -q 'OLLAMA_NUM_PARALLEL' ~/.zshrc 2>/dev/null || echo 'export OLLAMA_NUM_PARALLEL=4' >> ~/.zshrc"),

        ToolDef("ollama_queue", "OLLAMA_MAX_QUEUE",
                "echo ${OLLAMA_MAX_QUEUE:-not set}",
                description: """
OLLAMA_MAX_QUEUE 控制 Ollama 的请求排队长度（超出时拒绝新请求）。
默认值 512（通常足够），仅在高负载场景下需要调整。
增大队列（高负载服务）: echo 'export OLLAMA_MAX_QUEUE=1024' >> ~/.zshrc
减小队列（避免积压）: echo 'export OLLAMA_MAX_QUEUE=64' >> ~/.zshrc
调试排队问题: curl http://localhost:11434/api/tags 查看服务状态
"""),

        ToolDef("llama_cpp", "llama.cpp",
                "brew list llama.cpp 2>/dev/null | head -1 && echo 'installed' || echo 'not installed'",
                description: """
llama.cpp：高性能本地 LLM 推理引擎（Metal GPU 加速，C++ 编写）。
安装（Homebrew，含 Metal 加速）: brew install llama.cpp
安装后可用命令:
  llama-cli -m model.gguf -p "你好"    # 直接推理
  llama-server -m model.gguf --port 8080   # 启动 OpenAI 兼容 API 服务器
下载模型（GGUF 格式）:
  从 https://huggingface.co/models 搜索 GGUF 格式模型
  推荐: Llama-3.2-3B-Instruct.Q4_K_M.gguf（性价比最高）
llama.cpp vs Ollama: llama.cpp 更轻量/低延迟，Ollama 更易用/有 API 管理
""",
                fix: "brew install llama.cpp"),

        // ── AI CLI ────────────────────────────────────────────────────────
        ToolDef("claude", "Claude Code",
                "claude --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
Claude Code：Anthropic 官方 AI 编程助手 CLI（本工具的运行环境）。
安装: npm install -g @anthropic-ai/claude-code
更新到最新版: claude update  或  npm install -g @anthropic-ai/claude-code@latest
查看当前版本: claude --version
配置目录: ~/.claude/（settings.json, CLAUDE.md, rules/, skills/）
Claude Code 文档: https://docs.anthropic.com/claude-code
""",
                fix: "npm install -g @anthropic-ai/claude-code"),

        ToolDef("codex", "Codex CLI",
                "codex --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
OpenAI Codex CLI：OpenAI 官方代码辅助 CLI 工具。
安装: npm install -g @openai/codex
使用: codex（交互式）| codex "帮我重构这段代码"
与 Claude Code 配合：多 AI 协作（ask codex/gemini）。
需要设置 OPENAI_API_KEY 环境变量:
  echo 'export OPENAI_API_KEY="sk-..."' >> ~/.zshrc
""",
                fix: "npm install -g @openai/codex"),

        ToolDef("opencode", "OpenCode",
                "opencode version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
OpenCode：开源 AI 编程 CLI（支持多种 LLM 提供商）。
安装: npm install -g opencode-ai
文档和配置: ~/.config/opencode/
""",
                fix: "npm install -g opencode-ai"),

        ToolDef("gemini_cli", "Gemini CLI",
                "gemini --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
Google Gemini CLI：Google 官方 AI 编程助手 CLI。
安装: npm install -g @google/gemini-cli
使用需要 Google AI API Key:
  GEMINI_API_KEY=your_key gemini
  或: echo 'export GEMINI_API_KEY="..."' >> ~/.zshrc
与 Claude Code 协作: /ask gemini <prompt> 可在 Claude Code 中请求 Gemini 提供意见。
""",
                fix: "npm install -g @google/gemini-cli"),

        // ── Xcode 清理 ────────────────────────────────────────────────────
        ToolDef("xcode_cleanup", "Xcode 清理 plist",
                "test -f ~/Library/LaunchAgents/com.user.xcode-cleanup.plist && echo 'exists' || echo 'missing'",
                description: """
自动清理 Xcode DerivedData 的用户级 LaunchAgent。
Xcode DerivedData 是 Xcode 构建缓存，可能增长到数十 GB。
手动清理: rm -rf ~/Library/Developer/Xcode/DerivedData
创建自动清理 LaunchAgent（每周日凌晨自动清理 30 天以上旧缓存）:
  mkdir -p ~/Library/LaunchAgents
  cat > ~/Library/LaunchAgents/com.user.xcode-cleanup.plist << 'EOF'
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>Label</key><string>com.user.xcode-cleanup</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/sh</string><string>-c</string>
      <string>find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -mtime +30 -exec rm -rf {} \\;</string>
    </array>
    <key>StartCalendarInterval</key><dict>
      <key>Weekday</key><integer>0</integer>
      <key>Hour</key><integer>3</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
  </dict></plist>
  EOF
  launchctl load ~/Library/LaunchAgents/com.user.xcode-cleanup.plist
""",
                fix: "mkdir -p ~/Library/LaunchAgents && [ ! -f ~/Library/LaunchAgents/com.user.xcode-cleanup.plist ] && /usr/libexec/PlistBuddy -c 'Add Label string com.user.xcode-cleanup' -c 'Add ProgramArguments array' -c 'Add ProgramArguments:0 string /bin/sh' -c 'Add ProgramArguments:1 string -c' -c 'Add ProgramArguments:2 string find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -mtime +30 -exec rm -rf {} \\\\;' -c 'Add StartCalendarInterval dict' -c 'Add StartCalendarInterval:Weekday integer 0' -c 'Add StartCalendarInterval:Hour integer 3' ~/Library/LaunchAgents/com.user.xcode-cleanup.plist && launchctl load ~/Library/LaunchAgents/com.user.xcode-cleanup.plist 2>/dev/null; true"),

        // ── Ollama Metal GPU 检测 ─────────────────────────────────────────
        ToolDef("ollama_metal", "Ollama Metal GPU",
                "ollama --version 2>/dev/null | grep -i metal | head -1 || system_profiler SPDisplaysDataType 2>/dev/null | grep -i metal | head -1 || echo 'Metal supported (Apple Silicon)'",
                architectures: [.arm64],
                description: """
Ollama Metal GPU 加速状态（Apple Silicon 专有）。
Apple Silicon Mac 自带 Metal GPU，Ollama 会自动启用，无需额外配置。
验证 Metal 加速是否生效:
  运行模型后: ollama ps
  应显示 GPU 利用率（如 100% GPU）
若显示 100% CPU，Metal 未生效，检查:
  1. Ollama 版本是否最新: ollama --version
  2. 是否有 OLLAMA_GPU_LAYERS=0 覆盖设置
  3. 模型文件是否完整（重新 ollama pull）
"""),

        // ── brew 统计 ─────────────────────────────────────────────────────
        ToolDef("brew_formula_count", "brew formula 数",
                "brew list --formula 2>/dev/null | wc -l | tr -d ' '",
                description: """
已通过 Homebrew 安装的命令行工具（formula）数量。
查看所有已安装工具: brew list --formula
查找占用磁盘最多的包: brew list --formula | xargs brew info | grep -E '^[A-Za-z].*MB'
清理旧版本（释放磁盘空间）: brew cleanup --prune=all
查看哪些包可以升级: brew outdated
"""),

        ToolDef("brew_cask_count", "brew cask 数",
                "brew list --cask 2>/dev/null | wc -l | tr -d ' '",
                description: """
已通过 Homebrew Cask 安装的 GUI 应用数量。
查看所有已安装应用: brew list --cask
更新所有 cask: brew upgrade --cask
清理旧版本: brew cleanup --cask --prune=all
卸载应用（同时删除关联文件）: brew uninstall --cask appname
"""),

        ToolDef("brew_formula", "brew formula 列表",
                "brew list --formula 2>/dev/null | head -20 || echo 'none'",
                description: "当前通过 Homebrew 安装的命令行工具前 20 条（完整列表: brew list --formula）"),

        ToolDef("brew_cask", "brew cask 列表",
                "brew list --cask 2>/dev/null | head -20 || echo 'none'",
                description: "当前通过 Homebrew Cask 安装的 GUI 应用前 20 条（完整列表: brew list --cask）"),

        // ── 文件描述符限制 ────────────────────────────────────────────────
        ToolDef("ulimit_n", "ulimit -n (文件描述符)",
                "ulimit -n 2>/dev/null || echo 'unknown'",
                "65536",
                description: """
文件描述符上限（Claude Code 推荐 65536）。
macOS 默认值 256 在高并发时容易触发 "Too many open files" 错误。
临时提升（当前 session）: ulimit -n 65536
持久化（重启后保持）:
  echo 'ulimit -n 65536' >> ~/.zshrc
  创建 /Library/LaunchDaemons/limit.maxfiles.plist（参见 m9.maxfiles_plist）
验证: ulimit -n
""",
                fix: "ulimit -n 65536 && grep -q 'ulimit -n 65536' ~/.zshrc 2>/dev/null || echo 'ulimit -n 65536' >> ~/.zshrc"),

        ToolDef("ulimit_u", "ulimit -u (进程数)",
                "ulimit -u 2>/dev/null || echo 'unknown'",
                "2048",
                description: """
最大进程数上限。macOS 默认约 1418，高并发构建/AI 推理任务时可能不足。
临时提升: ulimit -u 2048
持久化: echo 'ulimit -u 2048' >> ~/.zshrc && source ~/.zshrc
验证: ulimit -u
""",
                fix: "ulimit -u 2048 && grep -q 'ulimit -u 2048' ~/.zshrc 2>/dev/null || echo 'ulimit -u 2048' >> ~/.zshrc"),

        // ── 补充工具 ──────────────────────────────────────────────────────
        ToolDef("java_home", "JAVA_HOME",
                "echo ${JAVA_HOME:-not set}",
                description: """
JAVA_HOME 环境变量（指向 Java 安装路径）。
正确设置可避免 Maven/Gradle 等工具找不到 Java。
设置方法（自动检测系统 Java）:
  echo 'export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null)' >> ~/.zshrc && source ~/.zshrc
指定版本（如 Java 21）:
  echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 21)' >> ~/.zshrc
查看所有已安装 JDK: /usr/libexec/java_home -V
""",
                fix: "grep -q 'JAVA_HOME' ~/.zshrc 2>/dev/null || echo 'export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null)' >> ~/.zshrc && source ~/.zshrc"),

        ToolDef("swift", "Swift",
                "swift --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
Swift 语言版本（随 Xcode / Xcode CLT 安装）。
当前 macOS 版本对应 Swift 版本：
  Sequoia (15)：Swift 6.0（Xcode 16）
  Tahoe (26)：Swift 6.2（Xcode 17，支持 Approachable Concurrency）
安装/更新: xcode-select --install  或  从 App Store 更新 Xcode
若需要独立 Swift 工具链（不依赖 Xcode）:
  从 swift.org/download 下载对应 macOS 版本的工具链
验证: swift --version
"""),

        ToolDef("deno", "Deno",
                "deno --version 2>/dev/null | head -1 || echo 'not installed'",
                description: """
Deno：安全的 JavaScript/TypeScript 运行时（类 Node.js，内置 TypeScript 支持）。
安装: brew install deno
特点：默认安全（需显式授权文件/网络/环境访问）、内置测试/格式化/linter。
常用命令:
  deno run --allow-net script.ts    # 运行 TypeScript
  deno install <url>                # 安装全局工具
  deno task build                   # 运行 deno.json 中的任务
与 MCP: 部分 MCP 服务器使用 Deno 运行时
""",
                fix: "brew install deno"),

        ToolDef("pnpm", "pnpm",
                "pnpm --version 2>/dev/null || echo 'not installed'",
                description: """
pnpm：高效 Node 包管理器（比 npm 节省约 60% 磁盘空间，速度更快）。
安装: npm install -g pnpm
特点：通过硬链接共享 node_modules，多项目不重复安装相同包。
使用:
  pnpm install              # 替代 npm install
  pnpm add <package>        # 替代 npm install <package>
  pnpm run <script>         # 替代 npm run
  pnpm store prune          # 清理无用的存储（释放磁盘）
查看存储大小: pnpm store status
""",
                fix: "npm install -g pnpm"),

        ToolDef("yarn", "Yarn",
                "yarn --version 2>/dev/null || echo 'not installed'",
                description: """
Yarn：Facebook 出品的 Node 包管理器（支持 Yarn 1.x Classic 和 Berry 2+/4+）。
安装 Yarn Classic (v1): npm install -g yarn
安装 Yarn Berry (v4，推荐): corepack enable && corepack prepare yarn@stable --activate
常用命令:
  yarn install        # 安装依赖
  yarn add <pkg>      # 添加依赖
  yarn cache clean    # 清理缓存
注意: Yarn Berry (v2+) 与 v1 有较大区别，查看 .yarnrc.yml 确认项目使用的版本。
""",
                fix: "npm install -g yarn"),
    ]

    public func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        tools
            .filter { t in
                let versionOk = t.versions.isEmpty || t.versions.contains(version)
                let archOk = t.architectures.isEmpty || t.architectures.contains(arch)
                return versionOk && archOk
            }
            .map { t in
                AuditCheck(
                    id: "m11.\(t.id)", name: t.name, module: id,
                    description: t.description,
                    command: t.command, expected: t.expected,
                    versions: t.versions,
                    fixRisk: t.fixCommand != nil ? .low : nil,
                    fixCommand: t.fixCommand,
                    priority: .a3
                )
            }
    }

    public func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecksParallel(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name, perCheckTimeout: .seconds(5))
    }
}
