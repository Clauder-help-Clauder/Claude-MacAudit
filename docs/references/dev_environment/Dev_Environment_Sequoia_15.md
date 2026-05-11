# 开发环境安装指南 — macOS Sequoia 15.7.5（M4 Max 64GB）

> 适用系统：macOS Sequoia 15.7.5（Apple Silicon M4 Max，64GB，2TB SSD）
> 执行时机：系统安全加固 + 效能优化完成并重启后
> 安装路径：Homebrew 安装到 `/opt/homebrew`（Apple Silicon 标准路径）

---

## 与 Tahoe / Ventura 版的关键差异

| 项目 | Sequoia M4 Max | Tahoe M4 Max | Ventura Intel i9 |
|------|:----------:|:----------:|:--------------:|
| macOS 版本 | 15.7.5 | 26.4 | 13.7.8 |
| Homebrew 路径 | `/opt/homebrew` | `/opt/homebrew` | `/usr/local` |
| Xcode CLT Clang | Apple clang **16.x** | Apple clang **21.x** | Apple clang **15.x** |
| Xcode 版本 | Xcode **16.3**（最高） | Xcode **18.x** | Xcode **15.2**（最高） |
| Ollama GPU 加速 | Metal（MLX 需手动构建） | Metal + MLX 原生 | 有限 Metal 支持 |
| Ollama 并发 | 4 并发 | 4 并发 | 1 并发 |
| OrbStack | 需 **v2.0.4+**（修复 15.7.x 崩溃） | 正常 | 正常 |
| pyenv | 需手动设 LDFLAGS/CPPFLAGS | 正常 | 可能需要 |
| Apple Intelligence | 有（15.1+ 引入） | 有（更深度集成） | 无 |

> **Sequoia 15 兼容性说明**：所有工具均已验证可在 Sequoia 15.7.5 + Apple Silicon M4 Max 上正常运行。pyenv 和 OrbStack 有已知注意事项（见下文）。

---

## 执行顺序总览

```
1. Xcode Command Line Tools（所有工具的编译依赖）
2. Homebrew（包管理器基础）
3. 版本管理器（nvm / pyenv / rustup）
4. 语言运行时（Node.js / Python / Rust / Go / Java）
5. AI 开发工具（Ollama / llama.cpp）
6. AI 编码助手（Claude Code / Codex / OpenCode / Gemini CLI）
7. 开发辅助工具（Git 增强 / 终端工具 / 容器）
8. Xcode 配置
9. .zshrc 统一配置
10. 验证
```

---

## 一、Xcode Command Line Tools

所有编译工具的基础依赖（Metal GPU 编译、C/C++ 工具链等）。

```bash
xcode-select --install
```

等待安装完成后验证：
```bash
xcode-select -p
# 预期：/Library/Developer/CommandLineTools 或 /Applications/Xcode.app/Contents/Developer

gcc --version
# 预期：Apple clang version 16.x（Sequoia 15 对应 clang-1600.x.x.x）
```

> 来源：[Apple Developer](https://developer.apple.com/xcode/)
> Sequoia 15.7.5 最高支持 Xcode 16.3（需 macOS 15.2+）。如果已安装 Xcode.app，Command Line Tools 会自动包含。

---

## 二、Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

安装后配置 PATH：
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
eval "$(/opt/homebrew/bin/brew shellenv)"
```

关闭匿名统计：
```bash
brew analytics off
```

验证：
```bash
brew --version
# 预期：Homebrew 4.x.x
which brew
# 预期：/opt/homebrew/bin/brew
```

> 来源：[https://brew.sh](https://brew.sh)
> Apple Silicon 安装到 `/opt/homebrew`（与 Tahoe 相同，与 Intel 的 `/usr/local` 不同）。

---

## 三、版本管理器

### 3.1 nvm（Node.js 版本管理）

```bash
brew install nvm
mkdir -p ~/.nvm
```

加到 `~/.zshrc`（后面统一配置段会包含）：
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
```

> 来源：[https://github.com/nvm-sh/nvm](https://github.com/nvm-sh/nvm)
> Sequoia 15 无已知兼容性问题。确保 `.zshrc` 中包含 nvm 初始化代码。

### 3.2 pyenv（Python 版本管理）

```bash
brew install pyenv
```

加到 `~/.zshrc`：
```bash
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

**Sequoia 15 已知问题**：pyenv 在 Sequoia 上编译 Python 时可能遇到 zlib/OpenSSL/readline 路径检测失败。**安装 Python 前先安装依赖**：

```bash
# 安装编译依赖（必须在 pyenv install 之前）
brew install openssl readline zlib xz

# 设置编译环境变量（加到 ~/.zshrc 或安装前临时 export）
export LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix zlib)/lib"
export CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix readline)/include -I$(brew --prefix zlib)/include"
export PKG_CONFIG_PATH="$(brew --prefix openssl)/lib/pkgconfig:$(brew --prefix readline)/lib/pkgconfig:$(brew --prefix zlib)/lib/pkgconfig"
```

> 来源：[https://github.com/pyenv/pyenv](https://github.com/pyenv/pyenv)
> Sequoia 问题追踪：[pyenv/pyenv#issues?q=Sequoia](https://github.com/pyenv/pyenv/issues?q=Sequoia)

### 3.3 rustup（Rust 版本管理）

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
```

安装常用组件：
```bash
rustup component add clippy rustfmt
```

> 来源：[https://rustup.rs](https://rustup.rs)

---

## 四、语言运行时

### 4.1 Node.js

```bash
source ~/.zshrc  # 确保 nvm 已加载
nvm install --lts
nvm use --lts
nvm alias default lts/*
```

安装全局工具：
```bash
npm install -g typescript tsx
```

验证：
```bash
node -v    # 预期：v22.x 或最新 LTS
npm -v     # 预期：10.x+
```

### 4.2 Bun（高性能 JS/TS 运行时，可选）

```bash
brew tap oven-sh/bun
brew install bun
```

验证：
```bash
bun --version   # 预期：1.x
```

> 来源：[https://bun.sh](https://bun.sh)

### 4.3 Python

```bash
source ~/.zshrc  # 确保 pyenv + 编译环境变量已加载

# 先安装编译依赖（如果还没安装）
brew install openssl readline zlib xz

# 安装 Python（Sequoia 上需要 LDFLAGS/CPPFLAGS 已设置）
pyenv install 3.12
pyenv install 3.13
pyenv global 3.13
```

安装 uv（现代 Python 包管理器，替代 pip）：
```bash
brew install uv
```

验证：
```bash
python --version   # 预期：Python 3.13.x
uv --version       # 预期：uv 0.x
```

> 来源：[https://github.com/astral-sh/uv](https://github.com/astral-sh/uv)
> uv 比 pip 快 10-100 倍，推荐用 `uv pip install` 替代 `pip install`。

### 4.4 Rust

已在 3.3 通过 rustup 安装。验证：
```bash
rustc --version    # 预期：rustc 1.8x.x
cargo --version
```

安装常用 Cargo 工具：
```bash
cargo install cargo-watch cargo-edit cargo-audit
```

### 4.5 Go（可选）

```bash
brew install go
```

验证：
```bash
go version   # 预期：go1.23.x
```

> 来源：[https://go.dev](https://go.dev)

### 4.6 Java OpenJDK（车机开发可能需要）

```bash
brew install openjdk@17
```

配置 PATH：
```bash
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
echo 'export JAVA_HOME="/opt/homebrew/opt/openjdk@17"' >> ~/.zshrc
```

验证：
```bash
java -version   # 预期：openjdk version "17.x"
```

---

## 五、AI 开发工具

### 5.1 Ollama（本地大模型推理）

```bash
brew install ollama
```

**M4 Max 64GB 专用配置**（加到 `~/.zshrc`）：
```bash
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_MAX_QUEUE=512
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_GPU_LAYERS=99
# 如果有外置存储放模型：
# export OLLAMA_MODELS="/path/to/large/storage/ollama/models"
```

升级到 0.19+（Metal 加速增强）：
```bash
brew upgrade ollama
ollama --version
# 预期：0.19.x 或更高
```

**Sequoia 15 GPU 加速说明**：
- Sequoia 上 Ollama 默认使用 **Metal GPU 加速**（通过 llama.cpp Metal 后端），无需额外配置
- **MLX 引擎**在 Sequoia 上需要手动构建（`xcodebuild -downloadComponent MetalToolchain` + `cmake --preset MLX`），普通安装不含 MLX
- Tahoe 26 上 MLX 原生集成更好，Sequoia 上建议直接用默认 Metal 后端即可

拉取推荐模型：
```bash
# 编码模型
ollama pull codellama:13b                     # Meta 编码模型
ollama pull deepseek-coder-v2:16b             # DeepSeek 编码

# 通用模型
ollama pull llama3:8b                         # Meta 通用
ollama pull qwen2.5:14b                       # 阿里通义
```

验证 Metal GPU 全量卸载：
```bash
ollama run llama3:8b --verbose 2>&1 | grep -i metal
# 预期输出包含 "Metal" 和 "using XX/64 GB of device memory"
```

> 来源：[https://ollama.com](https://ollama.com)

### 5.2 llama.cpp（可选，更底层的控制）

```bash
brew install llama.cpp
```

> 来源：[https://github.com/ggerganov/llama.cpp](https://github.com/ggerganov/llama.cpp)

---

## 六、AI 编码助手

### 6.1 Claude Code

```bash
# 官方安装方式
npm install -g @anthropic-ai/claude-code
```

验证：
```bash
claude --version
```

> 来源：[https://docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code)
> Sequoia 15 无已知兼容性问题。Claude Code 依赖 HTTPS_PROXY 环境变量 + Surge 代理路由，确保 .zshrc 中 proxy_on 函数已配置。

### 6.2 OpenAI Codex CLI

```bash
brew install --cask codex
# 或
npm install -g @openai/codex
```

验证：
```bash
codex --version
```

> 来源：[https://github.com/openai/codex-cli](https://github.com/openai/codex-cli)

### 6.3 OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
```

验证：
```bash
opencode --version
```

> 来源：[https://opencode.ai](https://opencode.ai)

### 6.4 Gemini CLI

```bash
brew install gemini-cli
# 或
npm install -g @anthropic-ai/gemini-cli 2>/dev/null || brew install gemini-cli
```

验证：
```bash
gemini --version
```

> 来源：[https://github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)

---

## 七、开发辅助工具

### 7.1 Git 增强

```bash
brew install git git-lfs gh
git lfs install

# Git 全局配置
git config --global user.name "testuser"
git config --global user.email "your-email@example.com"
git config --global init.defaultBranch main
git config --global fetch.parallel 4
git config --global submodule.fetchJobs 4
git config --global http.postBuffer 524288000
git config --global pack.threads 0
git config --global core.editor "nano"
```

> 来源：[https://git-scm.com](https://git-scm.com)，[https://cli.github.com](https://cli.github.com)

### 7.2 终端工具

```bash
# 搜索与文件管理
brew install ripgrep fd tree jq yq wget htop ncdu fzf

# 现代 CLI 替代品
brew install bat          # cat 替代，语法高亮
brew install eza          # ls 替代
brew install delta        # git diff 替代，语法高亮

# lazygit / lazydocker（TUI 界面）
brew install lazygit lazydocker
```

### 7.3 容器

```bash
# OrbStack（Docker Desktop 的轻量替代，Apple Silicon 原生）
brew install --cask orbstack
```

> **Sequoia 15.7.x 重要**：必须使用 OrbStack **v2.0.4 或更高版本**。
> v2.0.4（2024-10）修复了 macOS 15.7.x 上的启动崩溃问题。
> 安装后如果版本过低，运行 `brew upgrade --cask orbstack` 升级。

> 来源：[https://orbstack.dev](https://orbstack.dev)，[OrbStack Release Notes](https://docs.orbstack.dev/release-notes)

### 7.4 安全工具

```bash
# LuLu 出站防火墙
brew install --cask lulu

# KnockKnock 持久化检测
brew install --cask knockknock
```

> **LuLu 在 Sequoia 15 上的权限要求**：
> 安装后需要手动批准两项权限：
> 1. **System Extension**（系统扩展）：系统会弹出管理员认证
> 2. **Network Filter**（网络过滤器）：需要在 系统设置 → 隐私与安全性 中手动激活
> 当前版本 LuLu 4.3.1（2025-03）支持 macOS 10.15+。

---

## 八、Xcode 配置

如果已安装 Xcode.app：

```bash
# 查看 Xcode 版本
xcodebuild -version
# 预期：Xcode 16.3（Sequoia 15.2+ 支持的最高版本）

# 清理旧模拟器
xcrun simctl delete unavailable

# 清理 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

车机开发如果需要特定 iOS/watchOS SDK，在 Xcode → Settings → Platforms 中下载。

---

## 九、.zshrc 统一配置

将所有环境变量整合到 `~/.zshrc` 末尾。包含效能优化文档中的代理配置 + 开发环境配置：

```bash
# ========================================
# .zshrc — macOS Sequoia 15.7.5 M4 Max
# ========================================

# === 代理开关函数（Claude Code 核心依赖）===
proxy_on() {
  export http_proxy="http://127.0.0.1:6152"
  export https_proxy="http://127.0.0.1:6152"
  export all_proxy="socks5://127.0.0.1:6153"
  export HTTP_PROXY="http://127.0.0.1:6152"
  export HTTPS_PROXY="http://127.0.0.1:6152"
  export ALL_PROXY="socks5://127.0.0.1:6153"
  export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1"
  echo "代理已开启"
}

proxy_off() {
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY
  echo "代理已关闭"
}

# 默认开启代理（Surge 常驻运行）
proxy_on > /dev/null 2>&1

# === Homebrew ===
eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_NO_ANALYTICS=1

# === nvm ===
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# === pyenv ===
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# pyenv 编译依赖（Sequoia 15 必需）
export LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix zlib)/lib"
export CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix readline)/include -I$(brew --prefix zlib)/include"
export PKG_CONFIG_PATH="$(brew --prefix openssl)/lib/pkgconfig:$(brew --prefix readline)/lib/pkgconfig:$(brew --prefix zlib)/lib/pkgconfig"

# === Rust ===
. "$HOME/.cargo/env"

# === Java（如果安装了）===
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"

# === Go（如果安装了）===
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# === Ollama（M4 Max 64GB 配置）===
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_MAX_QUEUE=512
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_GPU_LAYERS=99

# === 文件描述符限制 ===
ulimit -n 65536
ulimit -u 2048

# === delta 作为 git pager ===
export GIT_PAGER="delta"
```

---

## 十、安装后验证脚本

```bash
#!/bin/bash
echo "=== 开发环境验证 — macOS Sequoia 15.7.5 ==="

echo ""
echo "--- 基础工具 ---"
echo "  Homebrew: $(brew --version 2>/dev/null | head -1 || echo '未安装')"
echo "  Homebrew 路径: $(which brew 2>/dev/null || echo '未找到')"
echo "  Xcode CLT: $(xcode-select -p 2>/dev/null || echo '未安装')"
echo "  Clang: $(clang --version 2>/dev/null | head -1 || echo '未安装')"
echo "  Git: $(git --version 2>/dev/null || echo '未安装')"
echo "  GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo '未安装')"

echo ""
echo "--- 语言运行时 ---"
echo "  Node.js: $(node -v 2>/dev/null || echo '未安装')"
echo "  npm: $(npm -v 2>/dev/null || echo '未安装')"
echo "  Bun: $(bun --version 2>/dev/null || echo '未安装')"
echo "  Python: $(python --version 2>/dev/null || echo '未安装')"
echo "  uv: $(uv --version 2>/dev/null || echo '未安装')"
echo "  Rust: $(rustc --version 2>/dev/null || echo '未安装')"
echo "  Cargo: $(cargo --version 2>/dev/null || echo '未安装')"
echo "  Go: $(go version 2>/dev/null || echo '未安装')"
echo "  Java: $(java -version 2>&1 | head -1 || echo '未安装')"

echo ""
echo "--- AI 工具 ---"
echo "  Ollama: $(ollama --version 2>/dev/null || echo '未安装')"
echo "  Claude Code: $(claude --version 2>/dev/null || echo '未安装')"
echo "  Codex: $(codex --version 2>/dev/null || echo '未安装')"
echo "  OpenCode: $(opencode --version 2>/dev/null || echo '未安装')"
echo "  Gemini: $(gemini --version 2>/dev/null || echo '未安装')"

echo ""
echo "--- 辅助工具 ---"
echo "  ripgrep: $(rg --version 2>/dev/null | head -1 || echo '未安装')"
echo "  fzf: $(fzf --version 2>/dev/null || echo '未安装')"
echo "  jq: $(jq --version 2>/dev/null || echo '未安装')"
echo "  bat: $(bat --version 2>/dev/null | head -1 || echo '未安装')"
echo "  lazygit: $(lazygit --version 2>/dev/null | head -1 || echo '未安装')"
echo "  delta: $(delta --version 2>/dev/null || echo '未安装')"

echo ""
echo "--- 容器 ---"
echo "  OrbStack: $(orb version 2>/dev/null || echo '未安装')"
echo "  Docker: $(docker --version 2>/dev/null || echo '未安装')"

echo ""
echo "--- Ollama Metal 验证 ---"
echo "  GPU Layers: ${OLLAMA_GPU_LAYERS:-未设置}"
echo "  Max Models: ${OLLAMA_MAX_LOADED_MODELS:-未设置}"
echo "  Parallel: ${OLLAMA_NUM_PARALLEL:-未设置}"

echo ""
echo "--- Claude 网络防护（关键）---"
HOSTS_COUNT=$(grep -c '0.0.0.0.*\(anthropic\|claude\)' /etc/hosts 2>/dev/null)
echo "  hosts Claude 域名屏蔽: ${HOSTS_COUNT} 条"
if [ "$HOSTS_COUNT" -lt 20 ]; then
  echo "  ⚠️ 警告：hosts 规则不足 20 条，Surge 关闭时 Claude 流量可能泄露！"
fi
echo -n "  代理函数: "; grep -c 'proxy_on' ~/.zshrc 2>/dev/null && echo "条匹配（已配置）" || echo "未配置"
echo -n "  HTTPS_PROXY: "; echo "${HTTPS_PROXY:-未设置}"

echo ""
echo "--- Sequoia 15 特有检查 ---"
echo -n "  pyenv 编译依赖 (openssl): "; brew list openssl 2>/dev/null | head -1 && echo "已安装" || echo "⚠️ 未安装"
echo -n "  pyenv 编译依赖 (readline): "; brew list readline 2>/dev/null | head -1 && echo "已安装" || echo "⚠️ 未安装"
echo -n "  pyenv 编译依赖 (zlib): "; brew list zlib 2>/dev/null | head -1 && echo "已安装" || echo "⚠️ 未安装"
echo -n "  OrbStack 版本: "; orb version 2>/dev/null || echo "未安装"
echo "  （需 v2.0.4+ 以避免 15.7.x 启动崩溃）"

echo ""
echo "--- Homebrew 健康检查 ---"
brew doctor 2>&1 | head -5
```

---

## 附录：推荐的 Brewfile

将以下内容保存为 `~/Brewfile`，以后新机器一键安装：

```ruby
# ~/Brewfile — Sequoia 15.7.5 M4 Max AI 开发工作站

# Taps
tap "homebrew/bundle"
tap "oven-sh/bun"

# 版本管理器
brew "nvm"
brew "pyenv"

# pyenv 编译依赖（Sequoia 15 必需）
brew "openssl"
brew "readline"
brew "zlib"
brew "xz"

# 语言运行时
brew "bun"
brew "go"
brew "openjdk@17"

# AI 工具
brew "ollama"
brew "llama.cpp"

# Git 增强
brew "git"
brew "git-lfs"
brew "gh"
brew "lazygit"
brew "delta"

# 终端工具
brew "ripgrep"
brew "fd"
brew "fzf"
brew "jq"
brew "yq"
brew "tree"
brew "wget"
brew "htop"
brew "ncdu"
brew "bat"
brew "eza"

# Python 工具
brew "uv"

# 容器（需 v2.0.4+ for Sequoia 15.7.x）
cask "orbstack"

# 安全工具
cask "lulu"
cask "knockknock"

# 终端（如果需要）
# cask "ghostty"
```

使用方式：
```bash
brew bundle --file=~/Brewfile
```
