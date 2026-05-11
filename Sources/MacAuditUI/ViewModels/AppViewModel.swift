// AppViewModel.swift — 应用主 ViewModel，管理导航、审计状态、扫描进度和通知
import SwiftUI
import MacAuditCore
import os.log

private let snapshotLogger = Logger(
    subsystem: "com.macaudit.ui",
    category: "snapshot"
)

// MARK: - App State

enum AppScreen: Hashable {
    case dashboard
    case scanning
    case results
    case detail(checkId: String)
    case history
    case proxyRule
    case settings
}

enum AuditMode: String, CaseIterable {
    case essential = "A0 Essential"
    case full = "Full Audit"
}

// MARK: - App Constants

enum AppConstants {
    static let version = "v0.3.1"
    static let displayName = "MacAudit \(version)"
    static let buildInfo = "Swift 6.0 · Universal Binary"
    static let moduleCount = 12
    static let checkCount = "476+"
}

// MARK: - Module Summary

struct ModuleSummary: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let passed: Int
    let failed: Int
    let total: Int
    var score: Int { total > 0 ? passed * 100 / total : 100 }
}

// MARK: - Saved Audit Snapshot

struct SavedAuditSnapshot: Codable, Sendable {
    let timestamp: Date
    let version: String
    let systemScore: Int
    let results: [AuditResult]
    let moduleSummaries: [ModuleSummary]
}

// MARK: - App ViewModel

@MainActor
@Observable
final class AppViewModel {
    // Navigation
    var selectedScreen: AppScreen = .dashboard
    var selectedCheckId: String? = nil
    var selectedModuleId: String? = nil   // 持久化已选模块，BACK 返回时不重置

    // Settings / preferences (persisted via UserDefaults)
    var preferredVersion: MacOSVersion = {
        let raw = UserDefaults.standard.string(forKey: "ma_version") ?? ""
        return MacOSVersion(rawValue: raw) ?? .sequoia
    }()
    var preferredDevice: DeviceType = {
        let raw = UserDefaults.standard.string(forKey: "ma_device") ?? ""
        return DeviceType(rawValue: raw) ?? .laptop
    }()

    func savePreferences() {
        UserDefaults.standard.set(preferredVersion.rawValue, forKey: "ma_version")
        UserDefaults.standard.set(preferredDevice.rawValue, forKey: "ma_device")
        invalidateChecksCache()  // 版本/设备变更后缓存失效，下次 check(for:) 时重建
    }

    // 用户手动跳过的检测项（持久化）
    var userSkippedIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "ma_user_skipped") ?? [])
    }()

    var skippedCount: Int { userSkippedIds.count }

    func skipCheck(_ checkId: String) {
        userSkippedIds.insert(checkId)
        UserDefaults.standard.set(Array(userSkippedIds), forKey: "ma_user_skipped")
        rebuildModuleSummaries()
        AuditLogger.logAction(action: "skipCheck", detail: checkId, success: true, error: nil)
    }

    func resetAllSkips() {
        userSkippedIds.removeAll()
        UserDefaults.standard.removeObject(forKey: "ma_user_skipped")
        rebuildModuleSummaries()
    }

    private func rebuildModuleSummaries() {
        let grouped = Dictionary(grouping: results, by: { $0.moduleId })
        moduleSummaries = moduleSummaries.map { summary in
            guard let moduleResults = grouped[summary.id] else { return summary }
            let nonSkipped = moduleResults.filter { !userSkippedIds.contains($0.checkId) }
            let passCount = nonSkipped.filter { $0.status == .pass }.count
            let infoCount = nonSkipped.filter { $0.status == .info }.count
            let isPersonal = summary.id == "services" || summary.id == "dev" || summary.id == "animation"
            let failed = isPersonal ? 0 : nonSkipped.filter { $0.status == .fail }.count
            let isInfoOnly = passCount == 0 && failed == 0 && infoCount > 0
            let passed = isInfoOnly ? infoCount : passCount
            let total  = isInfoOnly ? infoCount : nonSkipped.filter { $0.status != .skip && $0.status != .info }.count
            return ModuleSummary(
                id: summary.id, name: summary.name,
                passed: passed, failed: failed, total: total
            )
        }
    }

    // 上次审查快照（App 启动时自动加载）
    var savedSnapshot: SavedAuditSnapshot? = nil

    // Notifications
    let notificationCenter = AuditNotificationCenter()

    var notificationsEnabled: Bool = {
        let raw = UserDefaults.standard.object(forKey: "ma_notifications_enabled") as? Bool
        return raw ?? true
    }() {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "ma_notifications_enabled")
        }
    }

    func postAuditNotification(failCount: Int, warnCount: Int, durationMs: Int) {
        guard notificationsEnabled else { return }
        let severity: AuditNotification.Severity
        if failCount >= 5 {
            severity = .critical
        } else if failCount > 0 {
            severity = .warning
        } else {
            severity = .info
        }
        let title = failCount > 0
            ? "Audit Complete: \(failCount) issue\(failCount == 1 ? "" : "s") found"
            : "Audit Complete: All checks passed"
        let body = "Duration: \(durationMs)ms\(warnCount > 0 ? " · \(warnCount) warning\(warnCount == 1 ? "" : "s")" : "")"
        notificationCenter.add(title: title, body: body, severity: severity)
    }

    // Audit state
    var isScanning: Bool = false
    var auditMode: AuditMode = .essential
    var scanProgress: Double = 0
    var currentScanningModule: String = ""
    var results: [AuditResult] = []
    var moduleSummaries: [ModuleSummary] = []
    var lastAuditDate: Date? = nil
    var lastAuditDurationMs: Int = 0
    var scanLog: [String] = []  // live log lines for ScanningView terminal

    // System score（排除 skip/info/服务状态模块/用户跳过的项）
    // 服务状态（services）属于用户个人选择，不参与系统评分
    var systemScore: Int {
        guard !results.isEmpty else { return 0 }
        let applicable = results.filter {
            $0.status != .skip &&
            $0.status != .info &&
            $0.moduleId != "services" &&    // 服务状态：用户个人选择
            $0.moduleId != "dev" &&         // 开发工具：用户个人使用习惯
            $0.moduleId != "animation" &&   // 视觉动画优化：个人偏好建议
            !userSkippedIds.contains($0.checkId)
        }
        let passed = applicable.filter { $0.status == .pass }.count
        guard applicable.count > 0 else { return 100 }
        return passed * 100 / applicable.count
    }

    // Modules
    private let allModules: [any AuditModule] = [
        SystemInfoModule(),
        NetworkSecurityModule(),
        PrivacyModule(),
        AnimationModule(),
        ServicesModule(),
        PowerModule(),
        ShellModule(),
        ClaudeProtectionModule(),
        DevEnvironmentModule(),
        IPQualityModule(),
        ChromeModule(),
        SafariModule(),
    ]

    // MARK: - Audit Execution

    @ObservationIgnored private var auditTask: Task<Void, Never>?

    func startAudit() async {
        await startAudit(version: preferredVersion, device: preferredDevice)
    }

    func startAudit(version: MacOSVersion, device: DeviceType) async {
        guard !isScanning else { return }
        auditTask = Task { [weak self] in
            guard let self else { return }
            defer { isScanning = false }
            await self.performAudit(version: version, device: device, arch: .detect())
        }
        await auditTask?.value
    }

    func cancelAudit() {
        auditTask?.cancel()
        auditTask = nil
        isScanning = false
        results = []
        moduleSummaries = []
        selectedScreen = .dashboard
    }

    private func performAudit(version: MacOSVersion, device: DeviceType, arch: CPUArchitecture) async {
        isScanning = true
        scanProgress = 0
        results = []
        moduleSummaries = []
        selectedScreen = .scanning
        let auditStart = ContinuousClock.now

        let maxPriority: CheckPriority = auditMode == .essential ? .a0 : .a3
        let applicableModules: [any AuditModule] = maxPriority < .a3
            ? allModules.filter { $0.checks(for: version, device: device, arch: arch, maxPriority: maxPriority).count > 0 }
            : allModules
        let runner = AuditRunner(modules: applicableModules, version: version, device: device, arch: arch, maxPriority: maxPriority)
        let totalModules = Double(applicableModules.count)
        var completedModules = 0.0
        scanLog = []

        runner.onModuleComplete = { [weak self] name, moduleResults in
            guard let self else { return }
            completedModules += 1
            self.scanProgress = completedModules / totalModules
            self.currentScanningModule = name
            self.results.append(contentsOf: moduleResults)

            // Append live log entry
            let failCount = moduleResults.filter { $0.status == .fail }.count
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss"
            let ts = fmt.string(from: Date())
            let line = "\(ts)  \(name.uppercased()): \(moduleResults.count) checks, \(failCount) failed"
            self.scanLog.append(line)
            if self.scanLog.count > 20 {
                self.scanLog = Array(self.scanLog.suffix(20))
            }

            let moduleId = moduleResults.first?.moduleId ?? name
            let passCount = moduleResults.filter { $0.status == .pass }.count
            let infoCount = moduleResults.filter { $0.status == .info }.count
            let isPersonalModule = moduleId == "services" || moduleId == "dev" || moduleId == "animation"
            let failed = isPersonalModule ? 0 : moduleResults.filter { $0.status == .fail }.count
            let nonSkip = moduleResults.filter { $0.status != .skip }.count
            let isInfoOnly = passCount == 0 && failed == 0 && infoCount > 0
            let passed = isInfoOnly ? infoCount : passCount
            let total  = isInfoOnly ? infoCount : nonSkip - infoCount
            self.moduleSummaries.append(ModuleSummary(
                id: moduleId,
                name: name,
                passed: passed,
                failed: failed,
                total: total
            ))
        }

        _ = await runner.runAll()

        // Only finalize if not cancelled mid-run
        guard !Task.isCancelled else { return }
        let elapsed = ContinuousClock.now - auditStart
        lastAuditDurationMs = Int(elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
        lastAuditDate = Date()
        selectedScreen = .results
        saveAuditToDisk()

        AuditLogger.logAudit(
            results: results,
            version: version,
            device: device,
            arch: arch,
            duration: elapsed,
            mode: auditMode == .essential ? "essential (A0)" : "full",
            appVersion: AppConstants.version
        )

        let failCount = results.filter {
            $0.status == .fail &&
            $0.moduleId != "services" &&
            $0.moduleId != "dev" &&
            $0.moduleId != "animation"
        }.count
        let warnCount = results.filter {
            $0.status == .warn &&
            $0.moduleId != "services" &&
            $0.moduleId != "dev" &&
            $0.moduleId != "animation"
        }.count
        postAuditNotification(failCount: failCount, warnCount: warnCount, durationMs: lastAuditDurationMs)
    }

    // MARK: - Results Helpers

    /// 返回指定模块的结果，fail 项排在最前
    func results(for moduleId: String) -> [AuditResult] {
        let moduleResults = results.filter { $0.moduleId == moduleId }
        let failed = moduleResults.filter { $0.status == .fail }
        let others = moduleResults.filter { $0.status != .fail }
        return failed + others
    }

    /// 返回指定模块的失败项
    func failedResults(for moduleId: String) -> [AuditResult] {
        results.filter { $0.moduleId == moduleId && $0.status == .fail }
    }

    /// 返回模块的友好显示名，找不到时返回 id 本身
    func moduleName(for moduleId: String) -> String {
        moduleSummaries.first(where: { $0.id == moduleId })?.name ?? moduleId
    }

    /// 默认选中第一个模块 id（有数据时）
    var defaultSelectedModuleId: String? {
        moduleSummaries.first?.id
    }

    var failedResults: [AuditResult] {
        results.filter { $0.status == .fail }
    }

    // MARK: - Batch Repair Script

    private func allFixActions() -> (safe: [FixAction], medium: [FixAction], critical: [FixAction]) {
        let allChecks = allModules.flatMap { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) }
        let actions = FixEngine.extractFixActions(from: results, checks: allChecks)
        let safe     = actions.filter { $0.riskLevel <= .low  && !$0.requiresSudo && !$0.networkRisk }
        let medium   = actions.filter { ($0.riskLevel == .medium || $0.requiresSudo) && !$0.networkRisk }
        let critical = actions.filter { $0.networkRisk }
        return (safe, medium, critical)
    }

    /// Safe 脚本（无 sudo，无网络风险，可直接执行）
    func generateSafeScript() -> String {
        let (safe, _, _) = allFixActions()
        guard !safe.isEmpty else { return "# No safe fixes available" }
        let date = ISO8601DateFormatter().string(from: Date())
        var lines = [
            "#!/bin/bash",
            "# MacAudit — SAFE Fixes (\(safe.count) items)",
            "# Generated: \(date)",
            "# These commands require NO sudo and carry no network risk.",
            "# Safe to run directly in Terminal.",
            "",
            "set -euo pipefail",
            "echo '[MacAudit] Applying \(safe.count) safe fixes...'",
            "",
        ]
        for a in safe {
            lines += ["# \(a.name)", a.command, ""]
        }
        lines += ["echo '[MacAudit] Done. Re-run audit to verify.'"]
        return lines.joined(separator: "\n")
    }

    /// Medium 脚本（需要 sudo，逐条 y/N 确认）
    func generateMediumScript() -> String {
        let (_, medium, _) = allFixActions()
        guard !medium.isEmpty else { return "# No medium-risk fixes available" }
        let date = ISO8601DateFormatter().string(from: Date())
        var lines = [
            "#!/bin/bash",
            "# MacAudit — MEDIUM Fixes (\(medium.count) items, sudo required)",
            "# Generated: \(date)",
            "# Each command will prompt for confirmation before running.",
            "",
            "echo '[MacAudit] \(medium.count) fixes require sudo. You will be prompted for each.'",
            "",
        ]
        for a in medium {
            lines += [
                "# \(a.name)",
                "printf '  Apply? [y/N] '; read -r _ans </dev/tty",
                "[[ \"$_ans\" =~ ^[Yy] ]] && { \(a.command) && echo '  ✓ done'; } || echo '  — skipped'",
                "",
            ]
        }
        lines += ["echo '[MacAudit] Done. Re-run audit to verify.'"]
        return lines.joined(separator: "\n")
    }

    /// Critical 脚本（网络风险，统一 y/N 但每条加显眼 WARNING）
    func generateCriticalScript() -> String {
        let (_, _, critical) = allFixActions()
        guard !critical.isEmpty else { return "# No critical fixes available" }
        let date = ISO8601DateFormatter().string(from: Date())
        var lines = [
            "#!/bin/bash",
            "# MacAudit — CRITICAL Fixes (\(critical.count) items, NETWORK RISK)",
            "# Generated: \(date)",
            "# WARNING: These commands may disrupt network connectivity!",
            "",
            "echo '[MacAudit] WARNING: \(critical.count) fixes may affect network. Proceed carefully.'",
            "",
        ]
        for a in critical {
            lines += [
                "# ⚠ \(a.name)",
                "echo ''",
                "echo '🔴 HIGH RISK: \(a.name) — 此操作可能断开当前网络连接（含 SSH 会话）'",
                "printf '  Apply? [y/N] '; read -r _ans </dev/tty",
                "[[ \"$_ans\" =~ ^[Yy] ]] && { \(a.command) && echo '  ✓ done'; } || echo '  — skipped'",
                "",
            ]
        }
        lines += ["echo '[MacAudit] Done. Re-run audit to verify.'"]
        return lines.joined(separator: "\n")
    }

    /// 旧版：全合并脚本（保留供 SaveAs 使用）
    func generateRepairScript() -> String {
        let (safe, medium, critical) = allFixActions()
        if safe.isEmpty && medium.isEmpty && critical.isEmpty {
            return "# MacAudit: 无需修复的项目\n"
        }
        return [generateSafeScript(), generateMediumScript(), generateCriticalScript()]
            .filter { !$0.hasPrefix("# No ") }
            .joined(separator: "\n\n# ─────────────────────────────────\n\n")
    }

    /// 为指定模块生成修复脚本（按模块分类复制用）
    func generateModuleFixScript(moduleId: String) -> String {
        let allChecks = allModules.flatMap { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) }
        let moduleResults = results.filter { $0.moduleId == moduleId && $0.status == .fail }
        let actions = FixEngine.extractFixActions(from: moduleResults, checks: allChecks)
        guard !actions.isEmpty else { return "# No fixable items in this module" }

        let modName = moduleSummaries.first(where: { $0.id == moduleId })?.name ?? moduleId
        let date = ISO8601DateFormatter().string(from: Date())
        var lines = [
            "#!/bin/bash",
            "# MacAudit — \(modName)",
            "# Generated: \(date)",
            "# \(actions.count) fix\(actions.count == 1 ? "" : "es")",
            "",
        ]
        for a in actions {
            let isSudo   = a.requiresSudo
            let isNet    = a.networkRisk
            lines += ["# \(a.name)"]
            if isNet {
                lines += [
                    "echo '🔴 HIGH RISK: \(a.name) — 此操作可能断开当前网络连接（含 SSH 会话）'",
                    "printf '  Apply? [y/N] '; read -r _ans </dev/tty",
                    "[[ \"$_ans\" =~ ^[Yy] ]] && { \(a.command) && echo '  ✓ done'; } || echo '  — skipped'",
                ]
            } else if isSudo {
                lines += [
                    "printf '  Apply [\(a.name)]? [y/N] '; read -r _ans </dev/tty",
                    "[[ \"$_ans\" =~ ^[Yy] ]] && { \(a.command) && echo '  ✓ done'; } || echo '  — skipped'",
                ]
            } else {
                lines += [a.command]
            }
            lines += [""]
        }
        lines += ["echo '✓ \(modName) fixes applied.'"]
        return lines.joined(separator: "\n")
    }

    /// 每个模块的可修复项计数
    var moduleFixCounts: [(id: String, name: String, fixable: Int)] {
        let allChecks = allModules.flatMap { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) }
        return moduleSummaries.compactMap { summary in
            let moduleResults = results.filter { $0.moduleId == summary.id && $0.status == .fail }
            let actions = FixEngine.extractFixActions(from: moduleResults, checks: allChecks)
            guard !actions.isEmpty else { return nil }
            return (summary.id, summary.name, actions.count)
        }
    }
    func generateSingleFixScript(for checkId: String) -> String? {
        let allChecks = allModules.flatMap { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) }
        guard let check = allChecks.first(where: { $0.id == checkId }),
              let fixCmd = check.fixCommand,
              let fixRisk = check.fixRiskLevel else { return nil }

        let result = results.first(where: { $0.checkId == checkId })
        let currentVal = result?.actualValue ?? "N/A"
        let expected   = check.expectedValue ?? "N/A"
        let isSudo     = fixCmd.hasPrefix("sudo ")
        let isNetwork  = check.networkRisk

        var lines = [
            "#!/bin/bash",
            "# MacAudit Single Fix: \(check.name)",
            "# Risk: \(fixRisk.label)\(isSudo ? " · sudo required" : "")\(isNetwork ? " · network risk" : "")",
            "# Current: \(currentVal)  →  Expected: \(expected)",
            "",
        ]

        if isNetwork {
            lines += [
                "echo '🔴 HIGH RISK: 此操作可能断开当前网络连接（含 SSH 会话）'",
                "printf '  Apply? [y/N] '; read -r _ans </dev/tty",
                "[[ \"$_ans\" =~ ^[Yy] ]] || { echo 'Aborted.'; exit 1; }",
                "",
            ]
        } else if isSudo {
            lines += [
                "printf 'Apply fix? [y/N] '; read -r _ans </dev/tty",
                "[[ \"$_ans\" =~ ^[Yy] ]] || { echo 'Aborted.'; exit 1; }",
                "",
            ]
        }

        lines += [fixCmd, "", "echo '✓ Fix applied.'"]
        return lines.joined(separator: "\n")
    }
    var hasRepairActions: Bool {
        let allChecks = allModules.flatMap { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) }
        return !FixEngine.extractFixActions(from: results, checks: allChecks).isEmpty
    }

    /// 修复动作分类计数
    var repairActionCounts: (safe: Int, medium: Int, critical: Int) {
        let allChecks = allModules.flatMap { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) }
        let actions = FixEngine.extractFixActions(from: results, checks: allChecks)
        let safe   = actions.filter { $0.riskLevel <= .low  && !$0.requiresSudo && !$0.networkRisk }.count
        let medium = actions.filter { ($0.riskLevel == .medium || $0.requiresSudo) && !$0.networkRisk }.count
        let crit   = actions.filter { $0.networkRisk }.count
        return (safe, medium, crit)
    }

    func result(for checkId: String) -> AuditResult? {
        results.first { $0.checkId == checkId }
    }

    // MARK: - Single Module Audit（分模块审查）

    var singleModuleRunning: String? = nil   // 当前正在运行的模块 id

    func runSingleModule(_ moduleId: String) async {
        // 全局审查进行中时禁止单模块审查，防止并发修改 results/moduleSummaries
        guard let module = allModules.first(where: { $0.id == moduleId }),
              singleModuleRunning == nil,
              !isScanning else { return }
        singleModuleRunning = moduleId
        let executor = ShellExecutor()
        var newResults = await module.run(version: preferredVersion, device: preferredDevice, arch: .detect(), executor: executor)
        // Essential 模式下过滤非 A0 检测项结果
        let maxPriority: CheckPriority = auditMode == .essential ? .a0 : .a3
        if maxPriority < .a3 {
            let allowedIds = Set(module.checks(for: preferredVersion, device: preferredDevice, arch: .detect(), maxPriority: maxPriority).map(\.id))
            newResults = newResults.filter { allowedIds.contains($0.checkId) }
        }
        singleModuleRunning = nil

        // 更新 results
        results.removeAll { $0.moduleId == moduleId }
        results.append(contentsOf: newResults)

        // 更新 moduleSummaries
        let passed = newResults.filter { $0.status == .pass }.count
        let failed = newResults.filter { $0.status == .fail }.count
        let total  = newResults.filter { $0.status != .skip && $0.status != .info }.count
        if let idx = moduleSummaries.firstIndex(where: { $0.id == moduleId }) {
            moduleSummaries[idx] = ModuleSummary(
                id: moduleId, name: moduleSummaries[idx].name,
                passed: passed, failed: failed, total: total
            )
        } else {
            moduleSummaries.append(ModuleSummary(
                id: moduleId, name: module.name,
                passed: passed, failed: failed, total: total
            ))
        }
        // 审查完后跳转到对应模块结果
        selectedModuleId = moduleId
        selectedScreen = .results
        AuditLogger.logAction(
            action: "runSingleModule",
            detail: "\(moduleId): pass=\(passed) fail=\(failed) total=\(total)",
            success: true, error: nil
        )
    }

    // MARK: - Single Module Refresh

    /// 重新运行单个模块并更新结果（用于服务切换后刷新）
    func refreshModule(_ moduleId: String) async {
        guard let module = allModules.first(where: { $0.id == moduleId }) else { return }
        let executor = ShellExecutor()
        var newResults = await module.run(version: preferredVersion, device: preferredDevice, arch: .detect(), executor: executor)
        let maxPriority: CheckPriority = auditMode == .essential ? .a0 : .a3
        if maxPriority < .a3 {
            let allowedIds = Set(module.checks(for: preferredVersion, device: preferredDevice, arch: .detect(), maxPriority: maxPriority).map(\.id))
            newResults = newResults.filter { allowedIds.contains($0.checkId) }
        }
        // 使用动画避免列表项位置跳变
        let passed = newResults.filter { $0.status == .pass }.count
        let failed = newResults.filter { $0.status == .fail }.count
        let total  = newResults.filter { $0.status != .skip && $0.status != .info }.count
        withAnimation(.easeInOut(duration: 0.3)) {
            results.removeAll { $0.moduleId == moduleId }
            results.append(contentsOf: newResults)
            if let idx = moduleSummaries.firstIndex(where: { $0.id == moduleId }) {
                moduleSummaries[idx] = ModuleSummary(
                    id: moduleId, name: moduleSummaries[idx].name,
                    passed: passed, failed: failed, total: total
                )
            }
        }
        AuditLogger.logAction(
            action: "refreshModule",
            detail: "\(moduleId): pass=\(passed) fail=\(failed) total=\(total)",
            success: true, error: nil
        )
    }

    // MARK: - Audit Persistence

    // URL 计算只做路径拼接，目录创建移至 saveAuditToDisk（只在写入时执行一次）
    private var snapshotFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appendingPathComponent("MacAudit", isDirectory: true)
            .appendingPathComponent("last_audit.json")
    }

    /// 审查完成后自动保存快照到磁盘（后台写盘，不阻塞 MainActor）
    func saveAuditToDisk() {
        let snapshot = SavedAuditSnapshot(
            timestamp: lastAuditDate ?? Date(),
            version: AppConstants.version,
            systemScore: systemScore,
            results: results,
            moduleSummaries: moduleSummaries
        )
        savedSnapshot = snapshot  // 状态更新在 MainActor
        let url = snapshotFileURL
        Task.detached(priority: .utility) {
            do {
                let directory = url.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                }
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                snapshotLogger.error("Failed to save audit snapshot: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// App 启动时记录环境信息到日志
    func logAppLaunch() {
        AuditLogger.logAction(
            action: "appLaunch",
            detail: "version=\(AppConstants.version) macOS=\(MacOSVersion.versionString) device=\(DeviceType.detect().displayName) arch=\(CPUArchitecture.detect().rawValue)",
            success: true, error: nil
        )
    }

    /// App 启动时加载上次快照（后台读盘，不阻塞主线程）
    func loadSavedSnapshot() {
        let url = snapshotFileURL
        Task { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                let snapshot = try JSONDecoder().decode(SavedAuditSnapshot.self, from: data)
                self?.savedSnapshot = snapshot
            } catch {
                snapshotLogger.debug("No saved snapshot or load failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// 从快照恢复上次审查结果（无需重新扫描）
    func restoreFromSnapshot() {
        guard let snapshot = savedSnapshot else { return }
        let maxPriority: CheckPriority = auditMode == .essential ? .a0 : .a3
        if maxPriority < .a3 {
            let applicableIds = Set(
                allModules
                    .filter { $0.checks(for: preferredVersion, device: preferredDevice, arch: .detect(), maxPriority: maxPriority).count > 0 }
                    .map(\.id)
            )
            results = snapshot.results.filter { applicableIds.contains($0.moduleId) }
            moduleSummaries = snapshot.moduleSummaries.filter { applicableIds.contains($0.id) }
        } else {
            results = snapshot.results
            moduleSummaries = snapshot.moduleSummaries
        }
        lastAuditDate = snapshot.timestamp
        selectedScreen = .results
    }

    var hasSavedSnapshot: Bool { savedSnapshot != nil }


    /// 执行单条 shell 命令（用于服务 toggle / inline fix）
    func executeCommand(_ cmd: String) async -> ShellResult {
        let executor = ShellExecutor()
        let result = await executor.run(cmd)
        AuditLogger.logAction(
            action: "executeCommand",
            detail: cmd,
            success: result.isSuccess,
            error: result.isSuccess ? nil : result.stderr
        )
        return result
    }

    // 缓存 checks lookup 字典，避免在 View 渲染时重复 flatMap（防止 NetworkSecurityModule
    // 的 Process() 在主线程 SwiftUI layout 阶段造成 RunLoop 重入崩溃）
    @ObservationIgnored
    private var _checksCache: [String: AuditCheck]?

    func check(for checkId: String) -> AuditCheck? {
        if _checksCache == nil {
            // 使用 preferredVersion + preferredDevice，确保 Tahoe 专属检测项也包含在缓存中
            var map = [String: AuditCheck]()
            for module in allModules {
                for check in module.checks(for: preferredVersion, device: preferredDevice, arch: .detect()) {
                    map[check.id] = check
                }
            }
            _checksCache = map
        }
        return _checksCache?[checkId]
    }

    // 版本/设备偏好变更时重置缓存
    func invalidateChecksCache() {
        _checksCache = nil
    }

    // MARK: - Test Support

    /// 测试用：直接注入结果数据（不走真实审计流程）
    func injectTestResults(_ testResults: [AuditResult]) {
        self.results = testResults
    }

    /// 测试用：直接注入模块汇总
    func injectTestSummaries(_ summaries: [ModuleSummary]) {
        self.moduleSummaries = summaries
    }
}
