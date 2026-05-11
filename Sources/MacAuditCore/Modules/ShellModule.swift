import Foundation

/// M9: 终端环境模块
public struct ShellModule: AuditModule {
    public init() {}
    public let id = "shell"
    public let name = "终端环境"
    public let description = "Shell 配置和环境变量检测"

    public func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            AuditCheck(id: "m9.default_shell", name: "默认 Shell", module: id,
                       description: """
默认 Shell 应为 /bin/zsh（macOS Catalina 10.15+ 默认）。
修复（切换到 zsh）: chsh -s /bin/zsh
验证: echo $SHELL
若 zsh 不在 /etc/shells 中: sudo sh -c 'echo /bin/zsh >> /etc/shells' && chsh -s /bin/zsh
注意：切换后需重启终端生效。
""",
                       command: "echo $SHELL", expected: "/bin/zsh",
                       fixRisk: .low, fixCommand: "chsh -s /bin/zsh",
                       priority: .a2),

            AuditCheck(id: "m9.https_proxy", name: "HTTPS_PROXY", module: id,
                       description: """
HTTPS_PROXY 环境变量控制 Claude Code、curl、wget 等 CLI 工具的出口代理。
建议在 ~/.zshrc 的 all_proxy_on() 函数中统一设置（端口以实际代理软件为准）：
  Surge: 6152  |  Shadowrocket: 1082  |  Clash: 7890  |  V2Ray: 1087  |  Trojan: 1080
添加设置: echo 'export HTTPS_PROXY="http://127.0.0.1:6152"' >> ~/.zshrc && source ~/.zshrc
取消: unset HTTPS_PROXY
""",
                       command: "echo ${HTTPS_PROXY:-not set}",
                       priority: .a2),

            AuditCheck(id: "m9.http_proxy", name: "HTTP_PROXY", module: id,
                       description: """
HTTP_PROXY 控制 HTTP 协议的出口代理。应与 HTTPS_PROXY 同步设置。
添加设置: echo 'export HTTP_PROXY="http://127.0.0.1:6152"' >> ~/.zshrc && source ~/.zshrc
取消: unset HTTP_PROXY
注意：部分工具（如 npm）只识别小写的 http_proxy，建议同时设置大小写两个变量。
""",
                       command: "echo ${HTTP_PROXY:-not set}",
                       priority: .a2),

            AuditCheck(id: "m9.proxy_on", name: "all_proxy_on 函数", module: id,
                       description: """
代理一键开关函数 all_proxy_on 不存在于 ~/.zshrc。
此函数让代理切换更方便（终端直接执行 all_proxy_on 即可开启所有代理变量）。
添加到 ~/.zshrc（以 Surge 6152 为例）:
{ echo ''; echo 'all_proxy_on() {';
  echo '  export http_proxy="http://127.0.0.1:6152"';
  echo '  export https_proxy="http://127.0.0.1:6152"';
  echo '  export HTTP_PROXY="http://127.0.0.1:6152"';
  echo '  export HTTPS_PROXY="http://127.0.0.1:6152"';
  echo '  export no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"';
  echo '  export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"';
  echo '  echo "ProxyOn"'; echo '}'; } >> ~/.zshrc && source ~/.zshrc
取消: 从 ~/.zshrc 删除 all_proxy_on 函数块
""",
                       command: "grep -c 'all_proxy_on' ~/.zshrc 2>/dev/null ; true",
                       priority: .a2),

            AuditCheck(id: "m9.proxy_off", name: "all_proxy_off 函数", module: id,
                       description: """
代理关闭函数 all_proxy_off 不存在于 ~/.zshrc。
与 all_proxy_on 配套，用于快速关闭所有代理变量（访问国内服务时使用）。
添加到 ~/.zshrc:
{ echo 'all_proxy_off() {';
  echo '  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY';
  echo '  echo "ProxyOff"'; echo '}'; } >> ~/.zshrc && source ~/.zshrc
取消: 从 ~/.zshrc 删除 all_proxy_off 函数块
""",
                       command: "grep -c 'all_proxy_off' ~/.zshrc 2>/dev/null ; true",
                       priority: .a2),

            AuditCheck(id: "m9.brew_analytics", name: "HOMEBREW_NO_ANALYTICS", module: id,
                       description: """
Homebrew 默认会收集匿名使用统计（安装的 formulae、错误信息等）并上报到 Google Analytics。
关闭方法：
  方法1（推荐）: brew analytics off
  方法2（环境变量）: echo 'export HOMEBREW_NO_ANALYTICS=1' >> ~/.zshrc && source ~/.zshrc
验证: brew analytics
重新开启: brew analytics on
注意：关闭后 HOMEBREW_NO_ANALYTICS 变量应显示为 1。
""",
                       command: "echo ${HOMEBREW_NO_ANALYTICS:-not set}",
                       fixRisk: .low,
                       fixCommand: "brew analytics off && grep -q 'HOMEBREW_NO_ANALYTICS' ~/.zshrc 2>/dev/null || echo 'export HOMEBREW_NO_ANALYTICS=1' >> ~/.zshrc",
                       priority: .a2),

            AuditCheck(id: "m9.git_name", name: "Git user.name", module: id,
                       description: """
Git 全局用户名（出现在每次提交记录中，是公开可见的身份信息）。
⚠ 安全提醒: Claude Code 会读取 git user.name 并上报到 GrowthBook 作为身份信号。
设置: git config --global user.name "Your Name"
建议使用与 GitHub/GitLab 账号一致的名称，避免留空。
查看所有 git 配置: git config --global --list
""",
                       command: "git config --global user.name 2>/dev/null || echo 'not set'",
                       priority: .a2),

            AuditCheck(id: "m9.git_email", name: "Git user.email", module: id,
                       description: """
Git 全局邮箱（出现在每次提交记录中）。
⚠ 重要安全提醒: Claude Code 会读取 git user.email 并上报到 GrowthBook 系统，即使未使用 OAuth 登录。
这是一个容易被忽略的身份泄露点。
设置: git config --global user.email "you@example.com"
建议：与 Claude/Anthropic 账号邮箱保持一致，避免多个不同邮箱造成身份混乱。
""",
                       command: "git config --global user.email 2>/dev/null || echo 'not set'",
                       priority: .a2),

            AuditCheck(id: "m9.ssh_config", name: "SSH config", module: id,
                       description: """
~/.ssh/config 文件不存在。SSH 配置文件可大幅提升远程连接效率和安全性。
创建基础配置（含连接复用和保活）:
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  cat > ~/.ssh/config << 'EOF'
Host *
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  ServerAliveCountMax 3
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 600
EOF
  chmod 600 ~/.ssh/config
关键配置说明：
  ControlMaster: 复用已有连接，避免重复认证
  ServerAliveInterval: 60 秒发送一次保活包，防止空闲断连
""",
                       command: "test -f ~/.ssh/config && echo 'exists' || echo 'missing'",
                       fixRisk: .low,
                       fixCommand: "mkdir -p ~/.ssh && chmod 700 ~/.ssh && [ ! -f ~/.ssh/config ] && printf 'Host *\\n  AddKeysToAgent yes\\n  IdentityFile ~/.ssh/id_ed25519\\n  ServerAliveInterval 60\\n  ServerAliveCountMax 3\\n  ControlMaster auto\\n  ControlPath ~/.ssh/cm-%%r@%%h:%%p\\n  ControlPersist 600\\n' > ~/.ssh/config && chmod 600 ~/.ssh/config; true",
                       priority: .a2),

            AuditCheck(id: "m9.ssh_controlmaster", name: "SSH ControlMaster", module: id,
                       description: """
SSH ControlMaster 允许多个 SSH 连接复用同一个底层 TCP 连接。
优点：避免重复认证（如反复输入密码）、显著提升批量 SSH 操作速度。
在 ~/.ssh/config 的 Host * 段添加:
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 600
添加配置（如已有 ~/.ssh/config）:
  grep -q 'ControlMaster' ~/.ssh/config || printf '\\nHost *\\n  ControlMaster auto\\n  ControlPath ~/.ssh/cm-%%r@%%h:%%p\\n  ControlPersist 600\\n' >> ~/.ssh/config
取消: 从 ~/.ssh/config 删除 ControlMaster/ControlPath/ControlPersist 三行
""",
                       command: "grep -c 'ControlMaster' ~/.ssh/config 2>/dev/null ; true",
                       fixRisk: .low,
                       fixCommand: "grep -q 'ControlMaster' ~/.ssh/config 2>/dev/null || printf '\\nHost *\\n  ControlMaster auto\\n  ControlPath ~/.ssh/cm-%%r@%%h:%%p\\n  ControlPersist 600\\n' >> ~/.ssh/config",
                       priority: .a2),

            AuditCheck(id: "m9.ulimit_n", name: "ulimit -n", module: id,
                       description: """
文件描述符上限（open files limit）。macOS 默认值 256 过低。
Claude Code 高并发操作（多文件编辑、MCP 连接、并行构建）可能触发 "Too many open files" 错误。
推荐值：65536（当前 session 立即生效）
持久化方案（重启后保持）:
  echo 'ulimit -n 65536' >> ~/.zshrc  # 每次打开终端生效
  或创建 LaunchDaemon（参见 m9.maxfiles_plist）
取消: 从 ~/.zshrc 删除 ulimit -n 行
""",
                       command: "ulimit -n", expected: "65536",
                       fixRisk: .low,
                       fixCommand: "ulimit -n 65536 && grep -q 'ulimit -n 65536' ~/.zshrc 2>/dev/null || echo 'ulimit -n 65536' >> ~/.zshrc",
                       priority: .a2),

            AuditCheck(id: "m9.ulimit_u", name: "ulimit -u", module: id,
                       description: """
最大进程数上限。macOS 默认约 1418，对于开发工作通常足够，但运行大量并发任务时可能不足。
推荐值：2048（用于多模型推理/大型构建系统）
提升方法:
  ulimit -u 2048                              # 当前 session 生效
  echo 'ulimit -u 2048' >> ~/.zshrc           # 持久化
验证: ulimit -u
""",
                       command: "ulimit -u",
                       fixRisk: .low,
                       fixCommand: "ulimit -u 2048 && grep -q 'ulimit -u 2048' ~/.zshrc 2>/dev/null || echo 'ulimit -u 2048' >> ~/.zshrc",
                       priority: .a2),

            AuditCheck(id: "m9.dangerous_alias", name: "危险别名检测", module: id,
                       description: """
检测 ~/.zshrc / ~/.zprofile 中含有 'dangerously' 字样的危险配置。
常见危险配置：alias claude='claude --dangerously-skip-permissions'
风险：跳过权限检查允许 Claude Code 执行任意系统命令，无需确认。
查找危险配置: grep -n 'dangerously' ~/.zshrc ~/.zprofile 2>/dev/null
手动删除（确认行号后）: sed -i '' '/dangerously/d' ~/.zshrc
恢复（如需恢复被删除的别名）: 从备份中恢复对应行
""",
                       command: "r=$(grep -c 'dangerously' ~/.zshrc ~/.zprofile 2>/dev/null | awk -F: '{s+=$2} END{print s}'); echo \"${r:-0}\"",
                       expected: "0", risk: .medium,
                       fixRisk: .medium,
                       fixCommand: "sed -i '' '/dangerously/d' ~/.zshrc ~/.zprofile 2>/dev/null; true",
                       priority: .a2),

            AuditCheck(id: "m9.lang_check", name: "LANG 语言环境", module: id,
                       description: """
⚠ 地区身份信号: LANG 变量含 zh_CN 或 zh_TW 会直接暴露中文地区特征。
Claude Code 及第三方服务可读取此值推断用户地理位置。
与代理 IP 地区保持一致的建议：
  美国代理 IP → LANG=en_US.UTF-8
  日本代理 IP → LANG=ja_JP.UTF-8
修复（以美国为例）: echo 'export LANG=en_US.UTF-8' >> ~/.zshrc && source ~/.zshrc
取消: sed -i '' '/export LANG=/d' ~/.zshrc && source ~/.zshrc
注意：修改后需同步修改 LC_ALL（见 m9.lc_all）。
""",
                       command: "echo ${LANG:-$(locale 2>/dev/null | grep '^LANG=' | cut -d= -f2 | tr -d '\"' || echo 'not set')}",
                       expected: nil,
                       priority: .a2),  // info only — 用户需确认值与代理地区一致

            AuditCheck(id: "m9.lc_all", name: "LC_ALL 语言覆盖", module: id,
                       description: """
LC_ALL 的优先级高于 LANG，会覆盖所有 LC_* 语言设置。
若设为 zh_CN.UTF-8，即使 LANG 正确也会被覆盖，直接暴露中文地区。
建议与 LANG 保持一致:
  修复（以美国为例）: echo 'export LC_ALL=en_US.UTF-8' >> ~/.zshrc && source ~/.zshrc
  若不需要 LC_ALL 覆盖: sed -i '' '/export LC_ALL=/d' ~/.zshrc && unset LC_ALL
验证: locale
""",
                       command: "echo ${LC_ALL:-not set}",
                       expected: nil,
                       priority: .a2),  // info only

            AuditCheck(id: "m9.system_lang", name: "macOS 系统语言", module: id,
                       description: """
macOS 系统语言首选项列表（第一项为主要语言）。
⚠ 风险: 中文（zh-Hans, zh-Hant）排在首位时，浏览器 User-Agent 会含中文 Accept-Language 头，
暴露地区特征（即使终端 LANG 已修改，浏览器语言受系统语言控制）。
修复步骤:
  System Settings → Language & Region → 点击「+」添加 English（United States）→ 拖拽到首位
  或命令行（需重启生效）: defaults write -g AppleLanguages '("en-US", "zh-Hans")'
验证: defaults read -g AppleLanguages
""",
                       command: "defaults read -g AppleLanguages 2>/dev/null | grep -m1 '\"' | tr -d '\" ,' || echo 'not set'",
                       expected: nil,
                       priority: .a2),  // info only

            AuditCheck(id: "m9.zsh_history_cjk", name: "zsh_history 中文命令", module: id,
                       description: """
检测 ~/.zsh_history 中含有中文字符的命令记录数。
中文 shell 历史可能泄露使用习惯和语言特征（如曾执行中文参数的命令）。
只删除含中文的历史条目（保留其他）:
  python3 -c 'import re,os; h=os.path.expanduser("~/.zsh_history"); lines=open(h,"rb").read().decode("utf-8","replace").split(chr(10)); clean=[l for l in lines if not re.search("[\\u4e00-\\u9fff]",l)]; open(h,"w").write(chr(10).join(clean))'
清空全部历史记录（更彻底）:
  echo "" > ~/.zsh_history && fc -R ~/.zsh_history
注意：操作前建议备份: cp ~/.zsh_history ~/.zsh_history.bak
""",
                       command: "python3 -c 'import re,os; h=os.path.expanduser(\"~/.zsh_history\"); d=open(h,\"rb\").read().decode(\"utf-8\",\"replace\") if os.path.exists(h) else \"\"; p=re.compile(\"[\"+chr(0x4e00)+\"-\"+chr(0x9fff)+\"]\"); print(sum(1 for l in d.split(chr(10)) if p.search(l)))' 2>/dev/null || echo 0",
                       expected: "0", risk: .safe,
                       fixRisk: .medium,
                       fixCommand: "python3 -c 'import re,os; h=os.path.expanduser(\"~/.zsh_history\"); lines=open(h,\"rb\").read().decode(\"utf-8\",\"replace\").split(chr(10)) if os.path.exists(h) else []; p=re.compile(\"[\"+chr(0x4e00)+\"-\"+chr(0x9fff)+\"]\"); clean=[l for l in lines if not p.search(l)]; open(h,\"w\").write(chr(10).join(clean))' 2>/dev/null; true",
                       priority: .a2),

            AuditCheck(id: "m9.maxfiles_plist", name: "maxfiles 持久化", module: id,
                       description: """
/Library/LaunchDaemons/limit.maxfiles.plist 不存在。
ulimit -n 65536 仅在当前 session 有效，重启后恢复默认值 256。
需创建 LaunchDaemon 实现持久化（每次启动时自动设置）:
  sudo tee /Library/LaunchDaemons/limit.maxfiles.plist << 'EOF'
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>Label</key><string>limit.maxfiles</string>
    <key>ProgramArguments</key>
    <array>
      <string>launchctl</string><string>limit</string>
      <string>maxfiles</string><string>65536</string><string>524288</string>
    </array>
    <key>RunAtLoad</key><true/>
  </dict></plist>
  EOF
  sudo launchctl load /Library/LaunchDaemons/limit.maxfiles.plist
取消（恢复默认）:
  sudo launchctl unload /Library/LaunchDaemons/limit.maxfiles.plist
  sudo rm /Library/LaunchDaemons/limit.maxfiles.plist
""",
                       command: "test -f /Library/LaunchDaemons/limit.maxfiles.plist && echo 'exists' || echo 'missing'",
                       fixRisk: .high,
                       fixCommand: "sudo /usr/libexec/PlistBuddy -c 'Add Label string limit.maxfiles' -c 'Add ProgramArguments array' -c 'Add ProgramArguments:0 string launchctl' -c 'Add ProgramArguments:1 string limit' -c 'Add ProgramArguments:2 string maxfiles' -c 'Add ProgramArguments:3 string 65536' -c 'Add ProgramArguments:4 string 524288' -c 'Add RunAtLoad bool true' /Library/LaunchDaemons/limit.maxfiles.plist 2>/dev/null && sudo launchctl load /Library/LaunchDaemons/limit.maxfiles.plist 2>/dev/null; true",
                       priority: .a2),

            AuditCheck(id: "m9.dotfiles", name: "dotfiles 数量", module: id,
                       description: """
主目录中的隐藏配置文件（dotfiles）总数。
定期审查 dotfiles 可防止：
  1. 遗留配置暴露个人信息（如 .netrc 含密码）
  2. 旧工具残留文件占用磁盘（如 .cache 目录）
  3. 冲突配置干扰当前工具链
查看所有 dotfiles: ls -la ~/ | grep '^\\.\\.'
查找潜在敏感文件: grep -rl 'password\\|token\\|secret\\|key' ~/.[!.]*  2>/dev/null
清理建议: 删除已卸载工具的 rc 文件（如不再使用 .rvm .rbenv .nvm 时删除对应目录）
""",
                       command: "ls -d ~/.[!.]* 2>/dev/null | wc -l | tr -d ' '",
                       priority: .a2),
        ]
    }

    public func run(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture, executor: ShellExecutor) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
