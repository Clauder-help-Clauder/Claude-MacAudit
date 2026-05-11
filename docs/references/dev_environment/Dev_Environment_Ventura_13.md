# 开发环境安装指南 — macOS Ventura 13.7.8（Intel i9）

> 适用系统：macOS Ventura 13.7.8（Intel Core i9，16/32GB DDR4）
> 执行时机：系统安全加固 + 效能优化完成并重启后
> 安装路径：Homebrew 安装到 `/usr/local`（Intel 标准路径）

---

## 与 Tahoe M4 Max 版的关键差异

| 项目 | Tahoe M4 Max | Ventura Intel i9 |
|------|:----------:|:--------------:|
| Homebrew 路径 | `/opt/homebrew` | `/usr/local` |
| nvm 路径 | `/opt/homebrew/opt/nvm` | `/usr/local/opt/nvm` |
| Ollama MLX 加速 | ✅ 支持（0.19+） | ❌ 不支持 |
| Ollama 并发 | 4 并发 | 1 并发 |
| Ollama 可跑模型 | 70B（Q4_K_M） | 7B-13B |
| Metal GPU | 40 核 GPU，全量卸载 | Intel UHD/AMD，有限支持 |
| Rust 编译速度 | 快 | 慢（建议用 `cargo-watch` 增量编译） |
| Java 路径 | `/opt/homebrew/opt/openjdk@17` | `/usr/local/opt/openjdk@17` |

---

## 执行顺序总览

```
1. Xcode Command Line Tools
2. Homebrew
3. 版本管理器（nvm / pyenv / rustup）
4. 语言运行时（Node.js / Python / Rust / Go / Java）
5. AI 开发工具（Ollama）
6. AI 编码助手（Claude Code / Codex / OpenCode / Gemini CLI）
7. 开发辅助工具
8. Xcode 配置
9. .zshrc 统一配置
10. 验证
```

---

## 一、Xcode Command Line Tools

```bash
xcode-select --install
```

验证：
```bash
xcode-select -p
gcc --version
# 预期：Apple clang version 15.x（Ventura 对应版本）
```

> 来源：[Apple Developer](https://developer.apple.com/xcode/)

---

## 二、Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Intel Mac 无需额外配置 PATH**（默认安装到 `/usr/local/bin`，已在 PATH 中）。

如果 PATH 异常，手动添加：
```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
eval "$(/usr/local/bin/brew shellenv)"
```

关闭匿名统计：
```bash
brew analytics off
```

验证：
```bash
brew --version
which brew
# 预期：/usr/local/bin/brew
```

> 来源：[https://brew.sh](https://brew.sh)

---

## 三、版本管理器

### 3.1 nvm

```bash
brew install nvm
mkdir -p ~/.nvm
```

加到 `~/.zshrc`（注意路径与 Tahoe 不同）：
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/usr/local/opt/nvm/etc/bash_completion.d/nvm"
```

> 来源：[https://github.com/nvm-sh/nvm](https://github.com/nvm-sh/nvm)

### 3.2 pyenv

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

### 3.3 rustup

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup component add clippy rustfmt
```

> 来源：[https://rustup.rs](https://rustup.rs)

---

## 四、语言运行时

### 4.1 Node.js

```bash
source ~/.zshrc
nvm install --lts
nvm use --lts
nvm alias default lts/*
npm install -g typescript tsx
```

验证：
```bash
node -v    # 预期：v22.x 或最新 LTS
npm -v
```

### 4.2 Bun（可选，Intel 也支持）

```bash
brew tap oven-sh/bun
brew install bun
```

> 来源：[https://bun.sh](https://bun.sh)

### 4.3 Python

```bash
source ~/.zshrc
pyenv install 3.12
pyenv install 3.13
pyenv global 3.13
brew install uv
```

验证：
```bash
python --version   # 预期：Python 3.13.x
uv --version
```

> 来源：[https://github.com/astral-sh/uv](https://github.com/astral-sh/uv)

### 4.4 Rust

已通过 rustup 安装。安装常用工具：
```bash
cargo install cargo-watch cargo-edit cargo-audit
```

> Intel i9 编译 Rust 较慢，`cargo-watch` 的增量编译模式可以减少等待时间。

### 4.5 Go（可选）

```bash
brew install go
```

### 4.6 Java OpenJDK（车机开发）

```bash
brew install openjdk@17
```

配置 PATH（注意路径与 Tahoe 不同）：
```bash
echo 'export PATH="/usr/local/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
echo 'export JAVA_HOME="/usr/local/opt/openjdk@17"' >> ~/.zshrc
```

---

## 五、AI 开发工具

### 5.1 Ollama

```bash
brew install ollama
```

**Intel i9 专用配置**（加到 `~/.zshrc`）：
```bash
export OLLAMA_MAX_LOADED_MODELS=1    # Intel 内存有限，只加载 1 个
export OLLAMA_MAX_QUEUE=512
export OLLAMA_NUM_PARALLEL=1         # Intel 单并发
# Intel 不支持 OLLAMA_GPU_LAYERS=99（无 Metal 全量卸载能力）
# 如果有外置存储：
# export OLLAMA_MODELS="/path/to/large/storage/ollama/models"
```

拉取推荐模型（受内存限制，只拉小模型）：
```bash
# 编码模型（Intel 推荐 7B 以下）
ollama pull codellama:7b
ollama pull deepseek-coder-v2:lite      # 轻量版

# 通用模型
ollama pull llama3:8b                    # 8B 是 Intel 16GB 的上限
ollama pull qwen2.5:7b
```

> ⚠️ Intel Mac 不支持 Ollama 0.19 的 MLX 加速。推理速度约为 M4 Max 的 1/5 到 1/3。
> ⚠️ 13B 模型在 16GB RAM 的 Intel Mac 上可能导致严重 swap，32GB RAM 才能流畅运行。

### 5.2 llama.cpp（可选）

```bash
brew install llama.cpp
```

> 来源：[https://github.com/ggerganov/llama.cpp](https://github.com/ggerganov/llama.cpp)
> Intel Mac 上 llama.cpp 使用 CPU 推理（无 MLX），建议配合 Turbo Boost Switcher 关闭睿频后运行。

---

## 六、AI 编码助手

安装方式与 Tahoe 版完全相同：

### 6.1 Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

> 来源：[https://docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code)

### 6.2 OpenAI Codex CLI

```bash
brew install --cask codex
# 或
npm install -g @openai/codex
```

> 来源：[https://github.com/openai/codex-cli](https://github.com/openai/codex-cli)

### 6.3 OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
```

> 来源：[https://opencode.ai](https://opencode.ai)

### 6.4 Gemini CLI

```bash
brew install gemini-cli
```

> 来源：[https://github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)

---

## 七、开发辅助工具

### 7.1 Git 增强

```bash
brew install git git-lfs gh
git lfs install

git config --global user.name "testuser"
git config --global user.email "your-email@example.com"
git config --global init.defaultBranch main
git config --global fetch.parallel 4
git config --global submodule.fetchJobs 4
git config --global http.postBuffer 524288000
git config --global pack.threads 0
git config --global core.editor "nano"
```

### 7.2 终端工具

```bash
brew install ripgrep fd tree jq yq wget htop ncdu fzf
brew install bat eza delta
brew install lazygit lazydocker
```

### 7.3 容器（如果需要 Docker）

```bash
# Intel Mac 推荐 Docker Desktop（OrbStack 对 Intel 支持不如 Apple Silicon）
brew install --cask docker
```

> Intel Mac 上 OrbStack 也能用，但 Docker Desktop 在 Intel 上更成熟稳定。

### 7.4 安全工具

```bash
brew install --cask lulu
brew install --cask knockknock
```

### 7.5 i9 散热工具（效能优化文档中推荐）

```bash
# Turbo Boost Switcher — 从官网下载，Homebrew 没有
# 下载：http://tbswitcher.rugarciap.com/

# Macs Fan Control — 从官网下载
# 下载：https://crystalidea.com/macs-fan-control
```

---

## 八、Xcode 配置

```bash
xcrun simctl delete unavailable
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild -version
```

---

## 九、.zshrc 统一配置

将所有环境变量整合到 `~/.zshrc` 末尾：

```bash
# === 开发环境（Intel Mac）===

# Homebrew（Intel 路径）
eval "$(/usr/local/bin/brew shellenv)"

# nvm（Intel 路径）
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/usr/local/opt/nvm/etc/bash_completion.d/nvm"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Rust
. "$HOME/.cargo/env"

# Java（Intel 路径）
export PATH="/usr/local/opt/openjdk@17/bin:$PATH"
export JAVA_HOME="/usr/local/opt/openjdk@17"

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Ollama（Intel i9 配置）
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_MAX_QUEUE=512
export OLLAMA_NUM_PARALLEL=1

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
echo "=== 开发环境验证（Intel i9）==="

echo ""
echo "--- 基础工具 ---"
echo "  Homebrew: $(brew --version 2>/dev/null | head -1 || echo '未安装')"
echo "  Homebrew 路径: $(which brew)"
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
echo "  Docker: $(docker --version 2>/dev/null || echo '未安装')"

echo ""
echo "--- i9 散热工具 ---"
ls /Applications/Turbo\ Boost\ Switcher.app 2>/dev/null && echo "  Turbo Boost Switcher: 已安装" || echo "  Turbo Boost Switcher: 未安装"
ls /Applications/Macs\ Fan\ Control.app 2>/dev/null && echo "  Macs Fan Control: 已安装" || echo "  Macs Fan Control: 未安装"

echo ""
echo "--- Homebrew 健康检查 ---"
brew doctor 2>&1 | head -5
```

---

## 附录：推荐的 Brewfile

```ruby
# ~/Brewfile — Intel i9 AI 开发工作站

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
cask "docker"

# 安全工具
cask "lulu"
cask "knockknock"
```

使用方式：
```bash
brew bundle --file=~/Brewfile
```

---

## 附录：两版本安装差异对照表

| 项目 | Tahoe M4 Max | Ventura Intel i9 |
|------|:----------:|:--------------:|
| Homebrew 路径 | `/opt/homebrew` | `/usr/local` |
| Homebrew PATH 配置 | 需手动加到 .zshrc | 默认已在 PATH |
| nvm .sh 路径 | `/opt/homebrew/opt/nvm/nvm.sh` | `/usr/local/opt/nvm/nvm.sh` |
| Java 路径 | `/opt/homebrew/opt/openjdk@17` | `/usr/local/opt/openjdk@17` |
| Ollama 并发 | `OLLAMA_NUM_PARALLEL=4` | `OLLAMA_NUM_PARALLEL=1` |
| Ollama 模型数 | `OLLAMA_MAX_LOADED_MODELS=2` | `OLLAMA_MAX_LOADED_MODELS=1` |
| Ollama GPU 卸载 | `OLLAMA_GPU_LAYERS=99` | 不设置 |
| Ollama MLX | ✅ 0.19+ 支持 | ❌ 不支持 |
| 推荐模型上限 | 70B（Q4_K_M） | 7B-13B |
| 容器工具 | OrbStack（更轻量） | Docker Desktop（更稳定） |
| 散热工具 | 不需要 | Turbo Boost Switcher + Macs Fan Control |
| Rust 编译 | 快 | 慢（用 cargo-watch 增量编译） |
