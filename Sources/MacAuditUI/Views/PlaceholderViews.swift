// PlaceholderViews.swift — 辅助页面（历史记录、系统设置、系统信息、代理规则指南）
import SwiftUI
import MacAuditCore
import Darwin

// MARK: - History View (Fix Timeline)

struct HistoryView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var batches: [FixBatch] = []
    @State private var copiedBatchId: String? = nil
    @State private var displayCount: Int = 6

    var body: some View {
        ZStack {
            CyberGrid()

            if batches.isEmpty {
                emptyState
            } else {
                timelineView
            }
        }
        .onAppear { loadHistory() }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Text("FIX HISTORY")
                    .font(.spectralDisplay(56, weight: .bold))
                    .foregroundStyle(.textPrimary)
                    .tracking(-2)
                Text("Sequential ledger of all system modifications and security patches.")
                    .font(.mono(12))
                    .foregroundStyle(.textMuted)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(.horizontal, 48)

            VStack(spacing: 32) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: "#3C4B35"))
                Text("NO FIX RECORDS")
                    .font(.mono(14, weight: .bold))
                    .foregroundStyle(Color(hex: "#3C4B35"))
                    .tracking(5)
                Text("Run an audit and apply fixes to begin tracking history.")
                    .font(.mono(11))
                    .foregroundStyle(Color(hex: "#353437"))
            }
            Spacer()
            githubLink
                .padding(.horizontal, 48)
        }
    }

    // MARK: Timeline

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FIX HISTORY")
                        .font(.spectralDisplay(48, weight: .bold))
                        .foregroundStyle(.textPrimary)
                        .tracking(-2)
                    Text("Sequential ledger of all system modifications and security patches.")
                        .font(.mono(11))
                        .foregroundStyle(.textMuted)
                }
                Spacer()
                // Stats
                HStack(spacing: 12) {
                    statBox(
                        label: "TOTAL FIXES",
                        value: "\(batches.flatMap(\.records).count)",
                        color: .neonGreen
                    )
                    statBox(
                        label: "BATCHES",
                        value: "\(min(displayCount, batches.count))/\(batches.count)",
                        color: .linkCyan
                    )
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 36)
            .padding(.bottom, 28)

            Rectangle()
                .fill(Color(hex: "#3C4B35").opacity(0.15))
                .frame(height: 1)

            // Timeline
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let displayed = Array(batches.reversed().prefix(displayCount))
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { idx, batch in
                        timelineEntry(batch: batch, isLast: idx == displayed.count - 1)
                    }

                    // ── Load More ──────────────────────────────────
                    if displayCount < batches.count {
                        HStack {
                            Spacer()
                            Button {
                                displayCount += 10
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 13, weight: .medium))
                                    Text("LOAD MORE  (\(batches.count - displayCount) remaining)")
                                        .font(.mono(11, weight: .bold))
                                        .tracking(2)
                                }
                                .foregroundStyle(.neonGreen.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .overlay(Rectangle().stroke(Color.neonGreen.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.vertical, 24)
                    }

                    Spacer(minLength: 48)
                }
                .padding(.horizontal, 48)
                .padding(.top, 32)
            }
        }
        .background(Color.voidBase)
    }

    @ViewBuilder
    private func timelineEntry(batch: FixBatch, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline indicator column
            VStack(spacing: 0) {
                // Node
                ZStack {
                    Rectangle()
                        .fill(Color.neonGreen)
                        .frame(width: 14, height: 14)
                    Rectangle()
                        .fill(Color.voidBase)
                        .frame(width: 6, height: 6)
                }
                // Line
                if !isLast {
                    Rectangle()
                        .fill(Color(hex: "#3C4B35").opacity(0.2))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 32)
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Batch header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedDate(batch.timestamp))
                            .font(.mono(10, weight: .bold))
                            .foregroundStyle(Color(hex: "#353437"))
                            .tracking(2)
                        Text(formattedTime(batch.timestamp))
                            .font(.mono(9))
                            .foregroundStyle(.neonGreen.opacity(0.5))
                    }
                    .frame(width: 120, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Batch \(batch.id.prefix(8).uppercased())")
                            .font(.spectralDisplay(17, weight: .bold))
                            .foregroundStyle(.textPrimary)
                        Text("\(batch.records.count) fix\(batch.records.count == 1 ? "" : "es") applied")
                            .font(.mono(11))
                            .foregroundStyle(.textMuted)

                        // Tags
                        HStack(spacing: 6) {
                            tagChip("ID: \(batch.id.prefix(6).uppercased())", color: .linkCyan)
                            tagChip("TYPE: AUTO_FIX", color: .neonGreen)
                        }
                        .padding(.top, 4)
                    }

                    Spacer()

                    // Status + rollback button
                    HStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("STATUS")
                                .font(.mono(9, weight: .bold))
                                .foregroundStyle(.neonGreen)
                                .tracking(2)
                            Text("SUCCESSFUL")
                                .font(.mono(10))
                                .foregroundStyle(.textPrimary)
                        }
                        rollbackButton(for: batch)
                    }
                }

                // Records
                VStack(spacing: 1) {
                    ForEach(batch.records.prefix(3), id: \.checkId) { record in
                        recordRow(record)
                    }
                    if batch.records.count > 3 {
                        Text("+ \(batch.records.count - 3) more fixes")
                            .font(.mono(10))
                            .foregroundStyle(Color(hex: "#3C4B35"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.surfaceLow.opacity(0.4))
                    }
                }
                .padding(.leading, 120)
            }
            .padding(.leading, 16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func recordRow(_ record: FixRecord) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.neonGreen.opacity(0.4))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(.textPrimary)
                HStack(spacing: 8) {
                    Text(record.previousValue)
                        .font(.mono(10))
                        .foregroundStyle(.statusFail)
                    Text("→")
                        .font(.mono(10))
                        .foregroundStyle(Color(hex: "#3C4B35"))
                    Text(record.newValue)
                        .font(.mono(10))
                        .foregroundStyle(.neonGreen)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.surfaceLow)
    }

    @ViewBuilder
    private func rollbackButton(for batch: FixBatch) -> some View {
        let isCopied = copiedBatchId == batch.id
        Button {
            let script = FixHistory().generateUndoScript(for: batch)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(script, forType: .string)
            copiedBatchId = batch.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if copiedBatchId == batch.id { copiedBatchId = nil }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCopied ? "checkmark" : "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
                Text(isCopied ? "[ COPIED ]" : "[ ROLLBACK ]")
                    .font(.mono(10, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(isCopied ? Color(hex: "#032800") : Color(hex: "#85967C"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isCopied ? Color.neonGreen : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(
                        isCopied ? Color.neonGreen : Color(hex: "#3C4B35").opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Copy rollback script to clipboard")
    }

    @ViewBuilder
    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.mono(9, weight: .bold))
                .foregroundStyle(Color(hex: "#353437"))
                .tracking(2)
            Text(value)
                .font(.mono(28, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(16)
        .background(Color.surfaceLow)
        .overlay(Rectangle().stroke(Color(hex: "#3C4B35").opacity(0.15), lineWidth: 1))
        .frame(minWidth: 100)
    }

    @ViewBuilder
    private func tagChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.mono(9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.surfaceLow)
    }

    // MARK: Helpers

    private func loadHistory() {
        batches = FixHistory().loadAll()
    }

    private func formattedDate(_ iso: String) -> String {
        let parts = iso.prefix(10).replacingOccurrences(of: "-", with: ".")
        return parts.uppercased()
    }

    private func formattedTime(_ iso: String) -> String {
        guard iso.count >= 19 else { return "" }
        let t = String(iso.dropFirst(11).prefix(8))
        return "\(t) UTC"
    }

    private var githubLink: some View {
        Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit")!) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.mono(9))
                Text("github.com/Clauder-help-Clauder/Claude-MacAudit")
                    .font(.mono(9))
            }
            .foregroundStyle(Color.linkCyan.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            CyberGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SETTINGS")
                            .font(.spectralDisplay(48, weight: .bold))
                            .foregroundStyle(.textPrimary)
                            .tracking(-2)
                        Text("Configure audit target and preferences.")
                            .font(.mono(11))
                            .foregroundStyle(.textMuted)
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                    Rectangle()
                        .fill(Color(hex: "#3C4B35").opacity(0.15))
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 24) {

                        // ── Audit Mode ──────────────────────
                        settingSection(label: "AUDIT MODE") {
                            HStack(spacing: 8) {
                                ForEach(AuditMode.allCases, id: \.self) { mode in
                                    toggleButton(
                                        label: mode.rawValue.uppercased(),
                                        isOn: vm.auditMode == mode
                                    ) {
                                        vm.auditMode = mode
                                    }
                                }
                            }
                            Text(vm.auditMode == .essential ? "仅运行 A0 防封核心检测项（~50 项，~2 秒）" : "运行全部检测项（含 A1/A2/A3，~400 项，~10 秒）")
                                .font(.mono(10))
                                .foregroundStyle(Color(hex: "#3C4B35"))
                        }

                        dividerLine

                        // ── macOS Version ──────────────────────
                        settingSection(label: "MACOS VERSION") {
                            HStack(spacing: 8) {
                                ForEach([MacOSVersion.sequoia, .tahoe], id: \.self) { ver in
                                    toggleButton(
                                        label: ver.rawValue.uppercased(),
                                        isOn: vm.preferredVersion == ver
                                    ) {
                                        vm.preferredVersion = ver
                                        vm.savePreferences()
                                    }
                                }
                            }
                        }

                        dividerLine

                        // ── Device Type ────────────────────────
                        settingSection(label: "DEVICE TYPE") {
                            HStack(spacing: 8) {
                                ForEach([DeviceType.laptop, .desktop], id: \.self) { dev in
                                    toggleButton(
                                        label: dev.rawValue.uppercased(),
                                        isOn: vm.preferredDevice == dev,
                                        icon: dev == .laptop ? "laptopcomputer" : "desktopcomputer"
                                    ) {
                                        vm.preferredDevice = dev
                                        vm.savePreferences()
                                    }
                                }
                            }
                        }

                        dividerLine

                        // ── Audit Actions ──────────────────────
                        settingSection(label: "AUDIT ACTIONS") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 16) {
                                    Button {
                                        Task { await vm.startAudit() }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 11))
                                            Text("[ RUN FULL AUDIT ]")
                                                .font(.mono(12, weight: .bold))
                                                .tracking(3)
                                        }
                                        .foregroundStyle(.neonGreen)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.clear)
                                        .overlay(Rectangle().stroke(Color.neonGreen.opacity(0.5), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)

                                    Text("⌘R")
                                        .font(.mono(10))
                                        .foregroundStyle(Color(hex: "#3C4B35"))
                                }

                                Text("Runs all 12 modules for the selected OS version and device type.")
                                    .font(.mono(10))
                                    .foregroundStyle(Color(hex: "#3C4B35"))
                            }
                        }

                        dividerLine

                        // ── Skip Management ────────────────────
                        settingSection(label: "SKIP MANAGEMENT") {
                            VStack(alignment: .leading, spacing: 10) {
                                if vm.skippedCount > 0 {
                                    Button {
                                        vm.resetAllSkips()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.system(size: 11))
                                            Text("[ RESET ALL SKIPS (\(vm.skippedCount)) ]")
                                                .font(.mono(12, weight: .bold))
                                                .tracking(2)
                                        }
                                        .foregroundStyle(.statusWarn)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .overlay(Rectangle().stroke(Color.statusWarn.opacity(0.4), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    Text("恢复所有被跳过的检测项，重新参与评分")
                                        .font(.mono(10))
                                        .foregroundStyle(Color(hex: "#3C4B35"))
                                } else {
                                    Text("NO SKIPPED CHECKS")
                                        .font(.mono(11, weight: .bold))
                                        .foregroundStyle(Color(hex: "#3C4B35"))
                                        .tracking(3)
                                }
                            }
                        }

                        dividerLine

                        // ── About ──────────────────────────────
                        settingSection(label: "ABOUT") {
                            VStack(alignment: .leading, spacing: 8) {
                                infoRow("VERSION",   AppConstants.displayName)
                                infoRow("MODULES",   "\(AppConstants.moduleCount) audit modules")
                                infoRow("CHECKS",    "\(AppConstants.checkCount) security checks")
                                infoRow("PLATFORM",  "macOS 15+ (Sequoia / Tahoe)")
                                infoRow("BUILD",     "Swift 6.0 · Universal Binary")
                            }
                        }

                        dividerLine

                        // ── GitHub ──────────────────────────────
                        HStack {
                            Spacer()
                            githubLink
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.voidBase)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingSection(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label)
                .font(.mono(9, weight: .bold))
                .foregroundStyle(Color(hex: "#5A6B52"))
                .tracking(4)
            content()
        }
    }

    @ViewBuilder
    private func toggleButton(
        label: String,
        isOn: Bool,
        icon: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .font(.mono(11, weight: .bold))
                    .tracking(2)
            }
            .foregroundStyle(isOn ? Color(hex: "#032800") : Color.neonGreen.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isOn ? Color.neonGreen : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isOn ? Color.neonGreen : Color.neonGreen.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.mono(10, weight: .bold))
                .foregroundStyle(Color(hex: "#3C4B35"))
                .tracking(2)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.mono(10))
                .foregroundStyle(.textMuted)
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color(hex: "#3C4B35").opacity(0.15))
            .frame(height: 1)
    }

    private var githubLink: some View {
        Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit")!) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.mono(9))
                Text("github.com/Clauder-help-Clauder/Claude-MacAudit")
                    .font(.mono(9))
            }
            .foregroundStyle(Color.linkCyan.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - System Info Panel

struct SystemInfoPanel: View {
    var compact: Bool = false

    // MARK: sysctl helpers
    private func sysctlStr(_ key: String) -> String {
        var size = 0
        sysctlbyname(key, nil, &size, nil, 0)
        guard size > 0 else { return "N/A" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(key, &buf, &size, nil, 0)
        let uint8Buf = buf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }; return String(decoding: uint8Buf, as: UTF8.self)
    }

    private func sysctlU64(_ key: String) -> UInt64 {
        var val: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(key, &val, &size, nil, 0)
        return val
    }

    private func sysctlInt32(_ key: String) -> Int32 {
        var val: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname(key, &val, &size, nil, 0)
        return val
    }

    // MARK: computed values
    private var osName: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.majorVersion >= 26 { return "macOS Tahoe \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" }
        if v.majorVersion >= 15 { return "macOS Sequoia \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" }
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var kernelVersion: String {
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.release) { ptr in
            guard let base = ptr.baseAddress else { return "N/A" }; let len = strnlen(base.assumingMemoryBound(to: CChar.self), ptr.count); return String(decoding: UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: len), as: UTF8.self)
        }
    }

    private var cpuArch: String { sysctlStr("hw.machine") }
    private var hwModel: String { sysctlStr("hw.model") }
    private var memGB: String { "\(sysctlU64("hw.memsize") / 1_073_741_824) GB" }

    private var diskFree: String {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        let free = (attrs?[.systemFreeSize] as? Int64) ?? 0
        let gb = free / 1_073_741_824
        return "\(gb) GB"
    }

    private var diskFreeGB: Int {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        return Int(((attrs?[.systemFreeSize] as? Int64) ?? 0) / 1_073_741_824)
    }

    private var hostname: String {
        ProcessInfo.processInfo.hostName
            .replacingOccurrences(of: ".local", with: "")
    }

    private var username: String { NSUserName() }

    private var memPressure: (label: String, color: Color) {
        let level = sysctlInt32("kern.memorystatus_vm_pressure_level")
        switch level {
        case 0: return ("NORMAL", .neonGreen)
        case 1: return ("WARNING", .statusWarn)
        default: return ("CRITICAL", .statusFail)
        }
    }

    private var uptimeStr: String {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &boottime, &size, nil, 0)
        let secs = Int(Date().timeIntervalSince1970) - Int(boottime.tv_sec)
        let days = secs / 86400
        let hrs  = (secs % 86400) / 3600
        let mins = (secs % 3600) / 60
        if days > 0 { return "\(days)d \(hrs)h \(mins)m" }
        if hrs  > 0 { return "\(hrs)h \(mins)m" }
        return "\(mins)m"
    }

    // MARK: body

    var body: some View {
        VStack(spacing: 0) {
            row("OS",       osName,        .neonGreen,   idx: 0)
            row("KERNEL",   kernelVersion, .textMuted,   idx: 1)
            row("HARDWARE", hwModel,       .linkCyan,    idx: 2)
            row("CPU ARCH", cpuArch,       cpuArch == "arm64" ? .neonGreen : .statusWarn, idx: 3)
            row("MEMORY",   memGB,         .textPrimary, idx: 4)
            row("DISK FREE",diskFree,      diskFreeGB < 20 ? .statusFail : diskFreeGB < 50 ? .statusWarn : .neonGreen, idx: 5)
            row("HOST",     hostname,      .textMuted,   idx: 6)
            row("USER",     username,      .textMuted,   idx: 7)
            row("UPTIME",   uptimeStr,     .linkCyan,    idx: 8)

            let (pressLabel, pressColor) = memPressure
            row("MEM PRESSURE", pressLabel, pressColor,  idx: 9)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String, _ valueColor: Color, idx: Int = 0) -> some View {
        let labelW: CGFloat = compact ? 80 : 110
        let labelSize: CGFloat = compact ? 10 : 9
        let valueSize: CGFloat = compact ? 11 : 11
        let vPad: CGFloat = compact ? 5 : 8
        let hPad: CGFloat = compact ? 12 : 14

        HStack(spacing: 0) {
            Text(label)
                .font(.mono(labelSize, weight: .bold))
                .foregroundStyle(Color(hex: "#4A5E42"))
                .tracking(1)
                .frame(width: labelW, alignment: .leading)

            Text("//")
                .font(.mono(8))
                .foregroundStyle(Color(hex: "#3C4B35").opacity(0.5))
                .padding(.horizontal, compact ? 4 : 8)

            Text(value)
                .font(.mono(valueSize, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
    }
}

// MARK: - Proxy Rule View

struct ProxyRuleView: View {
    @State private var markdownContent: AttributedString = AttributedString("Loading…")
    private static let remoteURL = URL(string: "https://raw.githubusercontent.com/Clauder-help-Clauder/Claude-MacAudit/main/docs/proxy_rules.md")!

    private static func parse(_ raw: String) -> AttributedString {
        AttributedString(raw)
    }

    var body: some View {
        ZStack {
            CyberGrid()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color(hex: "#FF4444"))
                                .frame(width: 3, height: 24)
                            Text("PROXY RULES")
                                .font(.spectralDisplay(48, weight: .bold))
                                .foregroundStyle(.textPrimary)
                                .tracking(-2)
                        }
                        Text("Source: GitHub → Clauder-help-Clauder/Claude-MacAudit")
                            .font(.mono(9))
                            .foregroundStyle(Color(hex: "#5A6B52"))
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 36)
                    .padding(.bottom, 28)

                    Rectangle()
                        .fill(Color(hex: "#FF4444").opacity(0.2))
                        .frame(height: 1)

                    Text(markdownContent)
                        .font(.mono(15))
                        .foregroundStyle(.textMuted)
                        .tint(.linkCyan)
                        .textSelection(.enabled)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 32)

                    Spacer(minLength: 48)

                    githubLink
                        .padding(.horizontal, 48)
                        .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.voidBase)
        .task(id: "proxy-fetch") { await loadContent() }
        .onAppear { Task { await loadContent() } }
    }

    private func loadContent() async {
        if let url = Bundle.module.url(forResource: "proxy_rules", withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let raw = String(data: data, encoding: .utf8) {
            markdownContent = Self.parse(raw)
        }
        var request = URLRequest(url: Self.remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let (data, _) = try? await URLSession.shared.data(for: request),
           let raw = String(data: data, encoding: .utf8) {
            markdownContent = Self.parse(raw)
        }
    }

    private var githubLink: some View {
        Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit/blob/main/docs/proxy_rules.md")!) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.mono(9))
                Text("View on GitHub")
                    .font(.mono(9))
            }
            .foregroundStyle(Color.linkCyan.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}
