# 开发环境安装指南 — macOS Tahoe 26.4（M4 Max 64GB）

> 适用系统：macOS Tahoe 26.4（Apple Silicon M4 Max，64GB，2TB SSD）
> 执行时机：系统安全加固 + 效能优化完成并重启后
> 安装路径：Homebrew 安装到 `/opt/homebrew`（Apple Silicon 标准路径）

---

## 执行顺序总览

```
1. Xcode Command Line Tools（所有工具的编译依赖）
2. Homebrew（包管理器基础）
3. 版本管理器（nvm / pyenv / rustup）
4. 语言运行时（Node.js / Python / Rust / Go / Java）
5. AI 开发工具（Ollama / llama.cpp / MLX）
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
# 预期：Apple clang version 16.x
```

> 来源：[Apple Developer](https://developer.apple.com/xcode/)
> 如果已安装 Xcode.app，Command Line Tools 会自动包含。

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
> Apple Silicon 安装到 `/opt/homebrew`，与 Intel 的 `/usr/local` 不同。

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

> 来源：[https://github.com/pyenv/pyenv](https://github.com/pyenv/pyenv)

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
source ~/.zshrc  # 确保 pyenv 已加载
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

升级到 0.19+（MLX 加速，M4 Max 专属加速）：
```bash
brew upgrade ollama
ollama --version
# 预期：0.19.x 或更高
```

拉取推荐模型：
```bash
# 编码模型
ollama pull qwen3.5:35b-a3b-coding-nvfp4    # Ollama 0.19 MLX 优化版
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

> 来源：[https://ollama.com](https://ollama.com)，MLX 加速详情：[Ollama Blog](https://ollama.com/blog/mlx)

### 5.2 llama.cpp（可选，更底层的控制）

```bash
brew install llama.cpp
```

> 来源：[https://github.com/ggerganov/llama.cpp](https://github.com/ggerganov/llama.cpp)

### 5.3 MLX（Apple 官方 ML 框架，可选）

```bash
pip install mlx mlx-lm
```

> 来源：[https://github.com/ml-explore/mlx](https://github.com/ml-explore/mlx)
> M4 Max 的 MLX 推理性能极佳，适合需要自定义推理管线的场景。

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

> 推荐来源：[rldyourmnd/new-macos-dev-setup](https://github.com/rldyourmnd/new-macos-dev-setup)

### 7.3 容器（如果需要 Docker）

```bash
# OrbStack（Docker Desktop 的轻量替代，Apple Silicon 原生）
brew install --cask orbstack
```

> 来源：[https://orbstack.dev](https://orbstack.dev)
> OrbStack 比 Docker Desktop 更轻量、启动更快、资源占用更少。推荐 M4 Max 使用。

### 7.4 安全工具

```bash
# LuLu 出站防火墙（效能优化文档中推荐）
brew install --cask lulu

# KnockKnock 持久化检测
brew install --cask knockknock
```

---

## 八、Xcode 配置

如果已安装 Xcode.app：

```bash
# 清理旧模拟器
xcrun simctl delete unavailable

# 清理 DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 查看 Xcode 版本
xcodebuild -version
```

车机开发如果需要特定 iOS/watchOS SDK，在 Xcode → Settings → Platforms 中下载。

---

## 九、.zshrc 统一配置

将所有环境变量整合到 `~/.zshrc` 末尾（确保不与效能优化文档中的代理配置冲突）：

```bash
# === 开发环境 ===

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Rust
. "$HOME/.cargo/env"

# Java（如果安装了）
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"

# Go（如果安装了）
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Ollama（M4 Max 64GB 配置）
export OLLAMA_MAX_LOADED_MODELS=2
export OLLAMA_MAX_QUEUE=512
export OLLAMA_NUM_PARALLEL=4
export OLLAMA_GPU_LAYERS=99

# 文件描述符限制
ulimit -n 65536
ulimit -u 2048

# delta 作为 git pager
export GIT_PAGER="delta"
```

---

## 十、安装后验证脚本

```bash
#!/bin/bash
echo "=== 开发环境验证 ==="

echo ""
echo "--- 基础工具 ---"
echo "  Homebrew: $(brew --version 2>/dev/null | head -1 || echo '未安装')"
echo "  Xcode CLT: $(xcode-select -p 2>/dev/null || echo '未安装')"
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
echo "--- Homebrew 健康检查 ---"
brew doctor 2>&1 | head -5
```

---

## 附录：推荐的 Brewfile

将以下内容保存为 `~/Brewfile`，以后新机器一键安装：

```ruby
# ~/Brewfile — M4 Max AI 开发工作站

# Taps
tap "homebrew/bundle"
tap "oven-sh/bun"

# 版本管理器
brew "nvm"
brew "pyenv"

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

# 容器
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
