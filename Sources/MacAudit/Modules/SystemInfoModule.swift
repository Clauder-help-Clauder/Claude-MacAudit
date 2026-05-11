//
//  SystemInfoModule.swift
//  MacAudit
//
//  M1: 系统信息模块
//  收集基本系统信息，包括 macOS 版本、硬件型号、内核版本、CPU 架构、
//  内存大小、磁盘空间、主机名、用户名、运行时间、内存压力、APFS 快照、登录项等。
//  所有检查项均为信息展示（priority: a3），不影响系统评分。
//

import Foundation
import MacAuditCore

/// M1: 系统信息模块
struct SystemInfoModule: AuditModule {
    /// 模块唯一标识
    let id = "system_info"
    /// 模块显示名称
    let name = "系统信息"
    /// 模块功能描述
    let description = "基本系统信息收集"

    /// 生成系统信息检查项：macOS 版本、硬件、内核、CPU、内存、磁盘、主机名、运行时间等
    func checks(for version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) -> [AuditCheck] {
        [
            AuditCheck(id: "m1.macos_version", name: "macOS 版本", module: id,
                       description: """
当前 macOS 版本。建议保持系统最新以获取安全补丁和性能改进。
查看更新: System Settings → General → Software Update
命令行检查更新: softwareupdate -l
命令行安装所有更新: softwareupdate -i -a
""",
                       command: "sw_vers -productVersion",
                       priority: .a0),

            AuditCheck(id: "m1.hardware_model", name: "硬件型号", module: id,
                       description: """
当前 Mac 硬件标识符（如 Mac15,3 = MacBook Pro M3，Mac14,2 = MacBook Pro M2）。
查看详细型号: system_profiler SPHardwareDataType | grep 'Model Identifier'
查看序列号: system_profiler SPHardwareDataType | grep 'Serial Number'
""",
                       command: "sysctl -n hw.model",
                       priority: .a0),

            AuditCheck(id: "m1.software_info", name: "内核版本", module: id,
                       description: """
Darwin XNU 内核版本（如 24.x = macOS 15 Sequoia，25.x = macOS 26 Tahoe）。
内核版本决定了可用的系统调用和安全特性支持情况。
查看完整内核信息: uname -a
""",
                       command: "uname -r",
                       priority: .a0),

            AuditCheck(id: "m1.cpu_arch", name: "CPU 架构", module: id,
                       description: """
CPU 架构：arm64 = Apple Silicon（M 系列），x86_64 = Intel。此项仅作信息展示，不影响系统评分。
Apple Silicon 优势：Metal GPU 加速本地 AI 推理（Ollama/MLX）效率提升 5-10 倍，统一内存架构，续航更好。
若使用 Intel Mac：软件功能不受影响（本工具为 Universal Binary），但跑本地大模型性能较弱，可考虑后续升级。
""",
                       command: "uname -m",
                       priority: .a0),

            AuditCheck(id: "m1.memory", name: "内存大小", module: id,
                       description: """
物理内存（统一内存）总量。Apple Silicon 采用统一内存架构，CPU/GPU 共享。
建议配置：
- 日常开发（Claude Code）: 16GB+
- 运行本地 LLM（Ollama 7B 模型）: 16GB+
- 运行大模型（Llama 3 70B）: 64GB+
- 专业 AI 开发（MLX 训练）: 128GB+
查看内存压力: Memory 压力表 → Activity Monitor → Memory 标签
""",
                       command: "echo \"$(( $(sysctl -n hw.memsize) / 1073741824 )) GB\"",
                       priority: .a0),

            AuditCheck(id: "m1.disk_space", name: "磁盘空间", module: id,
                       description: """
根目录可用磁盘空间。建议保持 20GB+ 以确保系统更新和工具链正常运行。
快速清理步骤：
1. 清理 Homebrew 缓存: brew cleanup --prune=all
2. 清理 Xcode 派生数据: rm -rf ~/Library/Developer/Xcode/DerivedData
3. 清理 npm/yarn 缓存: npm cache clean --force
4. 清理 Docker 镜像: docker system prune -a
5. 查找大文件: ncdu / 或 du -sh ~/Library/* | sort -rh | head -20
6. 清理 pip 缓存: pip cache purge
""",
                       command: "df -h / | tail -1 | awk '{print $4}'",
                       priority: .a0),

            AuditCheck(id: "m1.hostname", name: "主机名", module: id,
                       description: """
当前主机名（会出现在日志、SSH 连接和网络广播中）。
建议避免使用包含真实姓名或设备型号的默认名称（如 "John-iPhone" 类型的名称会暴露身份）。
修改主机名（三处需同步修改）:
  sudo scutil --set HostName "myhost"
  sudo scutil --set LocalHostName "myhost"
  sudo scutil --set ComputerName "My Mac"
验证修改: hostname && scutil --get LocalHostName
""",
                       command: "hostname",
                       priority: .a0),

            AuditCheck(id: "m1.username", name: "当前用户", module: id,
                       description: """
当前登录用户名（会出现在文件路径 /Users/xxx 和系统日志中）。
若用户名包含真实姓名（如 johndoe），路径中会直接暴露身份信息。
注意：macOS 用户名建立后更改较复杂，需在系统恢复模式下操作。
查看完整用户信息: id && groups
""",
                       command: "whoami",
                       priority: .a0),

            AuditCheck(id: "m1.uptime", name: "运行时间", module: id,
                       description: """
系统已连续运行时间。
注意事项：
- 超过 30 天未重启：可能错过安全补丁生效（部分更新需重启才能应用）
- 内存压力高时：重启可清理内存泄漏
- 内核扩展更新后：必须重启才能加载新版本
安全重启（先关闭所有应用）: sudo shutdown -r now
""",
                       command: "uptime | sed 's/.*up //' | sed 's/,.*//'"  ,
                       priority: .a0),

            AuditCheck(id: "m1.memory_pressure", name: "内存压力", module: id,
                       description: """
内存压力级别（0=正常，1=警告，2=紧急）。
级别说明：
- 0 (Normal): 内存充足，系统运行正常
- 1 (Warning): 内存紧张，开始大量使用 swap，性能下降
- 2 (Critical): 内存严重不足，系统可能不稳定
缓解内存压力步骤：
1. 关闭不使用的应用（Activity Monitor → Memory 列排序）
2. 清理内存缓存（慎用）: sudo purge
3. 检查内存泄漏: leaks <PID>
4. 减少浏览器标签页（每个标签约消耗 50-200MB）
""",
                       command: "sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 0",
                       priority: .a0),

            AuditCheck(id: "m1.apfs_snapshots", name: "APFS 快照数", module: id,
                       description: """
Time Machine 在本地磁盘创建的 APFS 快照数量。
每个快照可能占用数 GB 磁盘空间（取决于更改量）。
快照管理命令：
  查看所有快照: tmutil listlocalsnapshots /
  删除所有快照（释放空间）: tmutil deletelocalsnapshots /
  删除指定日期快照: tmutil deletelocalsnapshots / 2024-01-15-120000
  查看快照占用空间: df -h（快照影响显示的可用空间）
注意：删除快照不影响 Time Machine 远程备份。
""",
                       command: "tmutil listlocalsnapshots / 2>/dev/null | wc -l | tr -d ' '",
                       fixRisk: .low,
                       fixCommand: "tmutil deletelocalsnapshots / 2>/dev/null; true",
                       priority: .a0),

            AuditCheck(id: "m1.login_items", name: "登录项", module: id,
                       description: """
用户级 LaunchAgents 目录中的文件数量（登录时自动启动的后台进程）。
过多登录项会：拖慢开机速度、持续消耗 CPU/内存、增加攻击面。
审查和管理登录项：
  GUI 方式: System Settings → General → Login Items & Extensions
  命令行查看: ls -la ~/Library/LaunchAgents/
  命令行禁用: launchctl disable gui/$(id -u)/com.xxx.yyy
  查看哪些应用添加了登录项: find ~/Library/LaunchAgents/ -name "*.plist" -exec grep -l ProgramArguments {} \\;
建议：超过 10 个登录项时，逐一审查是否必要。
""",
                       command: "ls ~/Library/LaunchAgents/ 2>/dev/null | wc -l | tr -d ' '",
                       priority: .a0),
        ]
    }

    /// 执行系统信息收集，返回检测结果
    func run(
        version: MacOSVersion,
        device: DeviceType,
        arch: CPUArchitecture,
        executor: ShellExecutor
    ) async -> [AuditResult] {
        await runChecks(checks(for: version, device: device, arch: arch), executor: executor, moduleName: name)
    }
}
