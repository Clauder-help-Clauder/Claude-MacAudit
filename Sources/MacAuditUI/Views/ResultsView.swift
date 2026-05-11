// ResultsView.swift — 审计结果列表页，展示检测项详情和内联修复操作
import SwiftUI
import MacAuditCore
import UniformTypeIdentifiers

struct ResultsView: View {
    @Environment(AppViewModel.self) private var vm
    // selectedModuleId 移至 AppViewModel，BACK 后状态保留
    @State private var searchQuery: String = ""
    @State private var showRepairSheet = false
    @State private var copiedModuleId: String? = nil

    private var failCount: Int { vm.results.filter { $0.status == .fail }.count }
    private var warnCount: Int { vm.results.filter { $0.status == .warn }.count }
    private var passCount: Int { vm.results.filter { $0.status == .pass }.count }

    private var filteredSummaries: [ModuleSummary] {
        guard !searchQuery.isEmpty else { return vm.moduleSummaries }
        return vm.moduleSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top summary header (设计稿 audit_results 风格) ──
            HStack(alignment: .bottom) {
                // Mini ring + big title
                HStack(spacing: 20) {
                    // Mini gauge
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#353437"), lineWidth: 2)
                            .frame(width: 80, height: 80)
                        let total = vm.results.filter { $0.status != .skip && $0.status != .info }.count
                        let progress = total > 0 ? Double(passCount) / Double(total) : 0
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.neonGreen, style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: .neonGreen.opacity(0.5), radius: 6)
                        VStack(spacing: 0) {
                            Text("\(vm.systemScore)%")
                                .font(.mono(16, weight: .bold))
                                .foregroundStyle(.neonGreen)
                            Text("Health")
                                .font(.mono(8))
                                .foregroundStyle(Color(hex: "#353437"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Security Audit")
                            .font(.spectralDisplay(44, weight: .bold))
                            .foregroundStyle(.textPrimary)
                            .tracking(-2)
                        if let date = vm.lastAuditDate {
                            Text("TIMESTAMP: \(isoString(date)) // STATUS: \(failCount > 0 ? "THREATS_DETECTED" : "SECURE")")
                                .font(.mono(10))
                                .foregroundStyle(.linkCyan.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Count cards
                HStack(spacing: 8) {
                    countCard(label: "Critical", value: failCount, color: .statusFail)
                    countCard(label: "Warnings", value: warnCount, color: .statusWarn)
                    countCard(label: "Passed",   value: passCount, color: .neonGreen)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.voidBase)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(hex: "#3C4B35").opacity(0.15)).frame(height: 1)
            }

            // ── Split view ──
            HSplitView {
                // Left: module list
                VStack(alignment: .leading, spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "#3C4B35"))
                        TextField("QUERY SYSTEM...", text: $searchQuery)
                            .font(.mono(11))
                            .foregroundStyle(.neonGreen)
                            .textFieldStyle(.plain)
                            .tint(.neonGreen)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#0A0A0C"))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(hex: "#3C4B35").opacity(0.15)).frame(height: 1)
                    }

                    // Filter chips
                    HStack(spacing: 6) {
                        if failCount > 0 {
                            AuditChip(text: "\(failCount) ISSUES", color: .statusFail, bgColor: .statusFail.opacity(0.1))
                        } else {
                            AuditChip(text: "ALL CLEAR", color: .neonGreen, bgColor: .neonGreen.opacity(0.1))
                        }
                        Text("\(vm.results.count) CHECKS")
                            .font(.mono(10))
                            .foregroundStyle(.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Rectangle().fill(Color(hex: "#3C4B35").opacity(0.15)).frame(height: 1)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredSummaries) { summary in
                                let hasFails = summary.failed > 0
                                let isCopied = copiedModuleId == summary.id
                                let isActive = vm.selectedModuleId == summary.id
                                let rowScore = summary.total > 0 ? summary.passed * 100 / summary.total : 0
                                let rowColor: Color = rowScore >= 90 ? .neonGreen : rowScore >= 70 ? .statusWarn : .statusFail

                                HStack(spacing: 0) {
                                    ModuleRow(
                                        name: summary.name,
                                        passed: summary.passed,
                                        total: summary.total,
                                        isActive: isActive
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { vm.selectedModuleId = summary.id }

                                    // 仅有失败项的模块显示 COPY 按钮
                                    if hasFails {
                                        Button {
                                            let script = vm.generateModuleFixScript(moduleId: summary.id)
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(script, forType: .string)
                                            copiedModuleId = summary.id
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                if copiedModuleId == summary.id { copiedModuleId = nil }
                                            }
                                        } label: {
                                            Text(isCopied ? "✓" : "COPY")
                                                .font(.mono(8, weight: .bold))
                                                .tracking(1)
                                                .foregroundStyle(isCopied ? Color(hex: "#032800") : .statusFail)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 4)
                                                .background(isCopied ? Color.neonGreen : Color.statusFail.opacity(0.12))
                                                .overlay(
                                                    Rectangle().stroke(
                                                        isCopied ? Color.neonGreen : Color.statusFail.opacity(0.4),
                                                        lineWidth: 1
                                                    )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 10)
                                        .help("Copy fix script for \(summary.name)")
                                    }
                                }
                                .background(isActive ? rowColor.opacity(0.06) : Color.clear)
                                Rectangle()
                                    .fill(Color(hex: "#3C4B35").opacity(0.08))
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .frame(minWidth: 260, maxWidth: 320)
                .background(Color.surfaceDim)
                .onAppear {
                    if vm.selectedModuleId == nil { vm.selectedModuleId = vm.defaultSelectedModuleId }
                }
                .onChange(of: vm.moduleSummaries.count) { _, _ in
                    if vm.selectedModuleId == nil { vm.selectedModuleId = vm.defaultSelectedModuleId }
                }

                // Right: check detail
                if let moduleId = vm.selectedModuleId {
                    CheckListView(moduleId: moduleId)
                } else {
                    emptyState
                }
            }

            // ── Batch Repair Action Bar — 仅当前模块有失败项时显示 ──
            let currentModuleFails = vm.selectedModuleId.map { id in
                vm.results.filter { $0.moduleId == id && $0.status == .fail }.count
            } ?? failCount
            if currentModuleFails > 0 {
                batchRepairBar
            }

            // GitHub footer link
            HStack {
                Spacer()
                githubLink
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Batch Repair Bar

    private var batchRepairBar: some View {
        let moduleId = vm.selectedModuleId
        let moduleName = moduleId.flatMap { id in
            vm.moduleSummaries.first(where: { $0.id == id })?.name
        } ?? "All Modules"
        let currentFails = moduleId.map { id in
            vm.results.filter { $0.moduleId == id && $0.status == .fail }.count
        } ?? failCount
        return HStack(spacing: 0) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(moduleId != nil ? moduleName.uppercased() : "ALL MODULES")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(.neonGreen)
                        .tracking(2)
                        .lineLimit(1)
                    Text("\(String(format: "%02d", currentFails)) FAILED")
                        .font(.spectralDisplay(18, weight: .bold))
                        .foregroundStyle(.textPrimary)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Text("COPY ALL FIX SHELL COMMANDS")
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(Color(hex: "#5A6B52"))
                    .tracking(2)
                Button {
                    showRepairSheet = true
                } label: {
                    Text("COMMAND DETAILS")
                        .font(.spectralDisplay(13, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(Color(hex: "#032800"))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(LinearGradient.spectral)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.surfaceLow)
        .overlay(alignment: .top) {
            Rectangle().stroke(Color.neonGreen.opacity(0.2), lineWidth: 1)
        }
        .sheet(isPresented: $showRepairSheet) {
            RepairScriptSheet(isPresented: $showRepairSheet, moduleId: vm.selectedModuleId)
                .environment(vm)
        }
    }

    private var failTagSamples: [String] {
        vm.results.filter { $0.status == .fail }.prefix(3).map {
            $0.checkId.components(separatedBy: ".").last?.uppercased() ?? $0.checkId
        }
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 48))
                .foregroundStyle(.textGhost)
            Text("SELECT A MODULE")
                .font(.mono(13, weight: .bold))
                .foregroundStyle(.textGhost)
                .tracking(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func countCard(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.mono(9, weight: .bold))
                .foregroundStyle(color.opacity(0.7))
                .tracking(2)
            Text(String(format: "%02d", value))
                .font(.mono(28, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceLow)
        .overlay(Rectangle().stroke(Color(hex: "#3C4B35").opacity(0.15), lineWidth: 1))
        .frame(minWidth: 90)
    }

    private func isoString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd_HH:mm:ss"
        return fmt.string(from: date)
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

// MARK: - Check List

struct CheckListView: View {
    @Environment(AppViewModel.self) private var vm
    let moduleId: String

    var body: some View {
        // fail 우선 정렬 (AppViewModel.results(for:) 에서 처리)
        let moduleResults = vm.results(for: moduleId)
        let failCount = moduleResults.filter { $0.status == .fail }.count

        VStack(alignment: .leading, spacing: 0) {
            // 모듈 헤더
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(vm.moduleName(for: moduleId))
                        .font(.spectralDisplay(20, weight: .bold))
                        .foregroundStyle(.textPrimary)
                    Text("\(moduleResults.count) CHECKS")
                        .font(.mono(12))
                        .foregroundStyle(.textMuted)
                }
                Spacer()
                if failCount > 0 {
                    AuditChip(
                        text: "\(failCount) FAILED",
                        color: .statusFail,
                        bgColor: .statusFail.opacity(0.1)
                    )
                } else {
                    AuditChip(
                        text: "ALL PASS",
                        color: .neonGreen,
                        bgColor: .neonGreen.opacity(0.08)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Rectangle().fill(Color.neonGreen.opacity(0.08)).frame(height: 1)

            if moduleResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.textGhost)
                    Text("NO DATA")
                        .font(.mono(11, weight: .bold))
                        .foregroundStyle(.textGhost)
                        .tracking(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if moduleId == "services" {
                            // ── Services 专用：按分组（Siri/AI、媒体/娱乐 等）排列，toggle 不改变顺序 ──
                            let structure = serviceStructure
                            ForEach(structure.groups, id: \.name) { group in
                                let disabledCount = group.checks.filter { check in
                                    moduleResults.first(where: { $0.checkId == check.id })?.actualValue == "disabled"
                                }.count
                                svcGroupHeader(label: group.name, disabled: disabledCount, total: group.checks.count)
                                ForEach(group.checks, id: \.id) { check in
                                    if let result = moduleResults.first(where: { $0.checkId == check.id }) {
                                        ServiceCheckRow(
                                            result: result,
                                            moduleId: moduleId,
                                            hint: structure.hints[check.id] ?? ""
                                        )
                                        .opacity(result.actualValue == "disabled" ? 0.65 : 1.0)
                                    }
                                    rowDivider
                                }
                            }
                        } else {
                        // ── CRITICAL group ──
                        let failItems = moduleResults.filter { $0.status == .fail }
                        if !failItems.isEmpty {
                            groupHeader(
                                label: "CRITICAL THREATS (\(String(format: "%02d", failItems.count)))",
                                color: .statusFail
                            )
                            ForEach(Array(failItems.enumerated()), id: \.element.checkId) { idx, result in
                                let isSkipped = vm.userSkippedIds.contains(result.checkId)
                                let fixCmd = vm.check(for: result.checkId)?.fixCommand ?? ""
                                let needsSudo = fixCmd.contains("sudo ")
                                HStack(spacing: 0) {
                                    CheckRow(result: result, applyBackground: false)
                                        .contentShape(Rectangle())
                                        .onTapGesture { vm.selectedScreen = .detail(checkId: result.checkId) }
                                        .opacity(isSkipped ? 0.4 : 1.0)
                                    if !isSkipped {
                                        // sudo 命令标记
                                        if needsSudo {
                                            Text("!SUDO")
                                                .font(.mono(10, weight: .bold))
                                                .foregroundStyle(Color.statusWarn.opacity(0.75))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 4)
                                                .overlay(Rectangle().stroke(Color.statusWarn.opacity(0.3), lineWidth: 1))
                                                .padding(.trailing, 8)
                                        }
                                        InlineFixButton(checkId: result.checkId, moduleId: moduleId)
                                        // SKIP 按钮
                                        Button {
                                            vm.skipCheck(result.checkId)
                                        } label: {
                                            Text("SKIP")
                                                .font(.mono(10, weight: .bold))
                                                .tracking(1)
                                                .foregroundStyle(Color(hex: "#5A6B52"))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .overlay(Rectangle().stroke(Color(hex: "#3C4B35").opacity(0.5), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 14)
                                    } else {
                                        Text("SKIPPED")
                                            .font(.mono(9, weight: .bold))
                                            .foregroundStyle(Color(hex: "#3C4B35"))
                                            .tracking(2)
                                            .padding(.trailing, 20)
                                    }
                                }
                                .background(isSkipped ? Color.clear : Color.statusFail.opacity(0.04))
                                .contentShape(Rectangle())
                                if idx < failItems.count - 1 { rowDivider }
                            }
                        }

                        // ── WARNINGS group ──
                        let warnItems = moduleResults.filter { $0.status == .warn }
                        if !warnItems.isEmpty {
                            groupHeader(
                                label: "SYSTEM WARNINGS (\(String(format: "%02d", warnItems.count)))",
                                color: .statusWarn
                            )
                            ForEach(Array(warnItems.enumerated()), id: \.element.checkId) { idx, result in
                                let wCmd = vm.check(for: result.checkId)?.fixCommand ?? ""
                                HStack(spacing: 0) {
                                    CheckRow(result: result, applyBackground: false)
                                        .contentShape(Rectangle())
                                        .onTapGesture { vm.selectedScreen = .detail(checkId: result.checkId) }
                                    if !wCmd.isEmpty && !wCmd.contains("sudo ") {
                                        InlineFixButton(checkId: result.checkId, moduleId: moduleId)
                                    }
                                }
                                .background(Color.statusWarn.opacity(0.02))
                                if idx < warnItems.count - 1 { rowDivider }
                            }
                        }

                        // ── SECURE group ──
                        let passItems = moduleResults.filter { $0.status == .pass }
                        if !passItems.isEmpty {
                            groupHeader(
                                label: "SYSTEM SECURE (\(String(format: "%02d", passItems.count)))",
                                color: .neonGreen
                            )
                            ForEach(Array(passItems.enumerated()), id: \.element.checkId) { idx, result in
                                CheckRow(result: result)
                                    .contentShape(Rectangle())
                                    .onTapGesture { vm.selectedScreen = .detail(checkId: result.checkId) }
                                    .opacity(0.7)
                                if idx < passItems.count - 1 { rowDivider }
                            }
                        }

                        // ── INFO / SKIP group ──
                        let otherItems = moduleResults.filter { $0.status != .fail && $0.status != .warn && $0.status != .pass }
                        if !otherItems.isEmpty {
                            groupHeader(label: "INFO (\(otherItems.count))", color: .linkCyan)
                            ForEach(Array(otherItems.enumerated()), id: \.element.checkId) { idx, result in
                                CheckRow(result: result)
                                    .contentShape(Rectangle())
                                    .onTapGesture { vm.selectedScreen = .detail(checkId: result.checkId) }
                                    .opacity(0.5)
                                if idx < otherItems.count - 1 { rowDivider }
                            }
                        }
                        // IP 质量模块：底部外部附加检查说明（与 TUI 内容一致）
                        if moduleId == "ip_quality" {
                            VStack(alignment: .leading, spacing: 20) {
                                // 标题
                                HStack(spacing: 8) {
                                    Rectangle().fill(Color.linkCyan).frame(width: 3, height: 18)
                                    Text("【外部附加检查】  ! 请打开全局代理后再操作")
                                        .font(.mono(T.body, weight: .bold))
                                        .foregroundStyle(.linkCyan)
                                }

                                // 1. ipleak.net
                                ipCheckBlock(
                                    index: "1",
                                    url: "ipleak.net",
                                    subtitle: "检查 DNS 实际出口",
                                    items: [
                                        ("操作", "打开 ipleak.net"),
                                        ("检查项", "DNS 实际请求来自哪个国家 — 必须与代理 IP 所在地一致"),
                                    ]
                                )

                                // 2. browserleaks WebRTC
                                ipCheckBlock(
                                    index: "2",
                                    url: "browserleaks.com/webrtc",
                                    subtitle: "检查 WebRTC 泄漏",
                                    items: [
                                        ("WebRTC Leak Test", "显示 No Leak 才合格"),
                                        ("Public IP Address", "必须是代理 IP，不能是真实 IP"),
                                        ("Local IP Address", "显示空（-）才合格"),
                                    ]
                                )

                                // 3. browserleaks JavaScript
                                ipCheckBlock(
                                    index: "3",
                                    url: "browserleaks.com/javascript",
                                    subtitle: "检查时区与语言",
                                    items: [
                                        ("Timezone", "必须与代理 IP 所在地一致（如 America/Los_Angeles）"),
                                        ("Language", "必须是 en-US"),
                                    ]
                                )

                                // 4. whoer.net
                                ipCheckBlock(
                                    index: "4",
                                    url: "whoer.net",
                                    subtitle: "IP 地址综合评分",
                                    items: [
                                        ("评分标准", "85分以上合格，90分以上优秀"),
                                        ("Proxy",    "显示 No（未被识别为代理）"),
                                        ("Anonymizer", "显示 No"),
                                        ("Blacklist", "显示 No（IP 不在黑名单）"),
                                    ]
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .background(Color.linkCyan.opacity(0.04))
                            .overlay(Rectangle().stroke(Color.linkCyan.opacity(0.15), lineWidth: 1))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        } // end else (non-services)
                    }
                }
            }
        }
        .background(Color.voidBase)
    }

    // MARK: - Services 分组结构（分组名有序 + hint 字典，只调用一次）
    private var serviceStructure: (groups: [(name: String, checks: [AuditCheck])], hints: [String: String]) {
        let allChecks = ServicesModule().checks(for: vm.preferredVersion, device: vm.preferredDevice, arch: .detect())
        var groupOrder = [String]()
        var groupedChecks = [String: [AuditCheck]]()
        var hints = [String: String]()
        for check in allChecks {
            let grp = check.tags.first ?? "其他"
            if groupedChecks[grp] == nil {
                groupOrder.append(grp)
                groupedChecks[grp] = []
            }
            groupedChecks[grp]!.append(check)
            let hint = check.description
                .components(separatedBy: "\n")
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
            if !hint.isEmpty { hints[check.id] = hint }
        }
        return (groupOrder.map { (name: $0, checks: groupedChecks[$0]!) }, hints)
    }

    @ViewBuilder
    private func ipCheckBlock(index: String, url: String, subtitle: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行（可点击打开）
            Button {
                if let u = URL(string: "https://\(url)") { NSWorkspace.shared.open(u) }
            } label: {
                HStack(spacing: 8) {
                    Text("\(index). \(url)")
                        .font(.mono(T.body, weight: .bold))
                        .foregroundStyle(.linkCyan)
                    Text(subtitle)
                        .font(.mono(T.small))
                        .foregroundStyle(.textMuted)
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundStyle(.linkCyan.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            // 子项
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.0) { key, val in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.mono(T.small))
                            .foregroundStyle(Color(hex: "#3C4B35"))
                        Text(key + ":")
                            .font(.mono(T.small, weight: .bold))
                            .foregroundStyle(.textMuted)
                        Text(val)
                            .font(.mono(T.small))
                            .foregroundStyle(Color(hex: "#7AAD72"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func ipLink(_ url: String, _ desc: String) -> some View {
        Button {
            if let u = URL(string: "https://\(url)") { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.linkCyan.opacity(0.7))
                Text(url)
                    .font(.mono(T.small, weight: .bold))
                    .foregroundStyle(.linkCyan)
                Text("— \(desc)")
                    .font(.mono(T.small))
                    .foregroundStyle(.textMuted)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func svcGroupHeader(label: String, disabled: Int, total: Int) -> some View {
        let color: Color = disabled == total ? .neonGreen : disabled > 0 ? .statusWarn : .statusFail
        HStack {
            HStack(spacing: 6) {
                Rectangle().fill(color).frame(width: 3, height: 12)
                Text(label.uppercased())
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(color)
                    .tracking(3)
            }
            Spacer()
            Text("\(disabled)/\(total) DISABLED")
                .font(.mono(9, weight: .bold))
                .foregroundStyle(color.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.08))
                .overlay(Rectangle().stroke(color.opacity(0.2), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(color.opacity(0.04))
        .overlay(alignment: .top) { Rectangle().fill(color.opacity(0.15)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(color.opacity(0.08)).frame(height: 1) }
    }

    @ViewBuilder
    private func groupHeader(label: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.mono(9, weight: .bold))
                .foregroundStyle(color)
                .tracking(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(color.opacity(0.05))
        .overlay(alignment: .top) {
            Rectangle().fill(color.opacity(0.15)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(color.opacity(0.1)).frame(height: 1)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(hex: "#3C4B35").opacity(0.08))
            .frame(height: 1)
    }
}

// MARK: - Check Row

struct CheckRow: View {
    let result: AuditResult
    var applyBackground: Bool = true

    private var statusColor: Color {
        switch result.status {
        case .pass:  return .neonGreen
        case .fail:  return .statusFail
        case .warn:  return .statusWarn
        case .info:  return .linkCyan
        default:     return Color(hex: "#3C4B35")
        }
    }

    private var statusLabel: String {
        switch result.status {
        case .pass:  return "PASS"
        case .fail:  return "FAIL"
        case .warn:  return "WARN"
        case .info:  return "INFO"
        default:     return "SKIP"
        }
    }

    private var isTappable: Bool { result.status == .fail }

    var body: some View {
        HStack(spacing: 0) {
            // 设计稿：左侧 4px 状态色条
            Rectangle()
                .fill(statusColor)
                .frame(width: 3)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.checkName)
                        .font(.mono(15, weight: isTappable ? .bold : .regular))
                        .foregroundStyle(isTappable ? .textPrimary : Color(hex: "#D4E4CC"))
                        .lineLimit(2)
                    if let actual = result.actualValue, !actual.isEmpty, actual != "N/A" {
                        Text(actual)
                            .font(.mono(13))
                            .foregroundStyle(Color(hex: "#8DAE84"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 右侧状态标签
                HStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.mono(13, weight: .bold))
                        .foregroundStyle(statusColor)
                        .tracking(2)
                    if isTappable {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(statusColor.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(applyBackground && isTappable ? statusColor.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Inline Fix Button（非 sudo 类 fixCommand 的内联修复按钮）

struct InlineFixButton: View {
    @Environment(AppViewModel.self) private var vm
    let checkId: String
    let moduleId: String
    @State private var isExecuting = false
    @State private var isDone = false
    @State private var isFailed = false

    private var fixCommand: String? {
        vm.check(for: checkId)?.fixCommand
    }
    private var isSafeCmd: Bool {
        guard let cmd = fixCommand else { return false }
        return !cmd.contains("sudo ")
    }

    var body: some View {
        if isSafeCmd {
            Button {
                guard let cmd = fixCommand, !isExecuting else { return }
                isExecuting = true
                isFailed = false
                Task {
                    let result = await vm.executeCommand(cmd)
                    if result.isSuccess {
                        await vm.refreshModule(moduleId)
                        isDone = true
                    } else {
                        isFailed = true
                    }
                    isExecuting = false
                    // 2 秒后重置
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    isDone = false
                    isFailed = false
                }
            } label: {
                Text(isExecuting ? "···" : isDone ? "✓" : isFailed ? "✗" : "FIX")
                    .font(.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(isFailed ? Color.white : Color(hex: "#032800"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        isFailed ? Color.red
                        : isDone ? Color.neonGreen
                        : isExecuting ? Color.neonGreen.opacity(0.3)
                        : Color.neonGreen.opacity(0.75)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isExecuting || isDone)
            .padding(.trailing, 14)
        }
    }
}

// MARK: - Service Check Row (services 模块专用：含 hint 描述 + DISABLE/ENABLE 开关)

struct ServiceCheckRow: View {
    @Environment(AppViewModel.self) private var vm
    let result: AuditResult
    let moduleId: String
    @State private var isExecuting = false

    private var serviceName: String {
        let raw = result.checkId.replacingOccurrences(of: "m6.", with: "")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return raw.unicodeScalars.allSatisfy { allowed.contains($0) } ? raw : ""
    }

    private var isDisabled: Bool { result.actualValue == "disabled" }

    // hint 由外部注入，不在 row 内部调用 vm.check(for:)
    let hint: String

    private var statusColor: Color {
        switch result.status {
        case .pass: return .neonGreen
        case .fail: return .statusFail
        case .warn: return .statusWarn
        default:    return Color(hex: "#3C4B35")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(statusColor).frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                // 服务短名
                Text(result.checkName)
                    .font(.mono(14, weight: .bold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)

                // hint 描述（第一行）
                if !hint.isEmpty {
                    Text(hint)
                        .font(.mono(12))
                        .foregroundStyle(Color(hex: "#7AAD72"))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer()

            // 服务开关按钮（与 FIX 同款风格）
            Button {
                guard !isExecuting, !serviceName.isEmpty else { return }
                isExecuting = true
                Task {
                    let uid = getuid()
                    let target = "gui/\(uid)/\(serviceName)"
                    if isDisabled {
                        await vm.executeCommand("/bin/launchctl enable \(target)")
                    } else {
                        await vm.executeCommand("/bin/launchctl disable \(target)")
                        await vm.executeCommand("/bin/launchctl bootout \(target) 2>/dev/null; true")
                    }
                    await vm.refreshModule(moduleId)
                    isExecuting = false
                }
            } label: {
                Text(isExecuting ? "···" : (isDisabled ? "ENABLE" : "DISABLE"))
                    .font(.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color(hex: "#032800"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isDisabled ? Color.neonGreen.opacity(0.5) : Color.statusFail.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(isExecuting)
            .padding(.trailing, 20)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Repair Script Sheet

struct RepairScriptSheet: View {
    @Environment(AppViewModel.self) private var vm
    @Binding var isPresented: Bool
    let moduleId: String?      // nil = 全部模块

    @State private var scriptContent = ""
    @State private var copied = false

    private var moduleName: String {
        moduleId.flatMap { id in vm.moduleSummaries.first(where: { $0.id == id })?.name }
            ?? "All Modules"
    }
    private var scope: String {
        moduleId != nil ? moduleName : "All Modules"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.neonGreen)
                            .frame(width: 3, height: 18)
                        Text("COMMAND DETAILS")
                            .font(.spectralDisplay(28, weight: .bold))
                            .foregroundStyle(.textPrimary)
                            .tracking(-1)
                    }
                    Text("Scope: \(scope.uppercased())")
                        .font(.mono(13))
                        .foregroundStyle(.textMuted)
                        .padding(.leading, 13)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button { saveToFile() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 13))
                            Text("SAVE .SH")
                                .font(.mono(11, weight: .bold))
                                .tracking(2)
                        }
                        .foregroundStyle(Color(hex: "#5A6B52"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().stroke(Color(hex: "#3C4B35").opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "#5A6B52"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Rectangle().fill(Color(hex: "#3C4B35").opacity(0.15)).frame(height: 1)

            // ── Script preview — 带注释，可选择性复制 ──────────────
            ScrollView {
                Text(scriptContent)
                    .font(.mono(15))
                    .foregroundStyle(.neonGreen.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .textSelection(.enabled)  // 用户可以选中任意行单独复制
            }
            .background(Color(hex: "#0A0A0C"))

            Rectangle().fill(Color(hex: "#3C4B35").opacity(0.15)).frame(height: 1)

            // ── Footer actions ──────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Text("COPY ALL FIX SHELL COMMANDS")
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(Color(hex: "#5A6B52"))
                    .tracking(3)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            HStack(spacing: 12) {
                // Copy all
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(scriptContent, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                        Text(copied ? "[ COPIED ]" : "[ COPY ALL ]")
                            .font(.mono(16, weight: .bold))
                            .tracking(3)
                    }
                    .foregroundStyle(copied ? Color(hex: "#032800") : .neonGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(copied ? Color.neonGreen : Color.clear)
                    .overlay(Rectangle().stroke(
                        copied ? Color.neonGreen : Color.neonGreen.opacity(0.5),
                        lineWidth: 1
                    ))
                }
                .buttonStyle(.plain)

                // Hint
                Text("Tip: select any line to copy individually")
                    .font(.mono(12))
                    .foregroundStyle(Color(hex: "#5A6B52"))
                    .frame(maxWidth: 200)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(hex: "#0D0D0F"))
        }
        .frame(width: 880, height: 660)
        .background(Color(hex: "#0D0D0F"))
        .overlay(Rectangle().stroke(Color(hex: "#3C4B35").opacity(0.2), lineWidth: 1))
        .onAppear { loadScript() }
        .onChange(of: moduleId) { _, _ in loadScript() }
    }

    private func loadScript() {
        if let id = moduleId {
            scriptContent = vm.generateModuleFixScript(moduleId: id)
        } else {
            scriptContent = vm.generateRepairScript()
        }
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.title = "Save Repair Script"
        let safeName = moduleName.replacingOccurrences(of: " ", with: "_").lowercased()
        // .command 在 macOS 双击可直接在 Terminal 里执行；.sh 会弹"找不到 App"对话框
        panel.nameFieldStringValue = "macaudit_\(safeName)_repair.command"
        if let cmdType = UTType(filenameExtension: "command") {
            panel.allowedContentTypes = [cmdType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            try? scriptContent.write(to: url, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}
