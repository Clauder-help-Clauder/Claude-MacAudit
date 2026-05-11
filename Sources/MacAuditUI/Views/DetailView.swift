// DetailView.swift — 模块详情页，展示单个审计模块的检测结果和修复操作
import SwiftUI
import MacAuditCore

struct DetailView: View {
    @Environment(AppViewModel.self) private var vm
    let checkId: String
    @State private var fixCopied = false
    @State private var descHovered = false

    private var result: AuditResult? { vm.result(for: checkId) }
    private var check: AuditCheck?  { vm.check(for: checkId) }

    private var currentModuleId: String? { result?.moduleId }

    // 左侧导航：只显示同模块检测项
    private var failChecks: [AuditResult] {
        guard let moduleId = currentModuleId else {
            return vm.results.filter { $0.status == .fail }
        }
        let fails = vm.results.filter { $0.moduleId == moduleId && $0.status == .fail }
        let passes = vm.results.filter { $0.moduleId == moduleId && $0.status == .pass }.prefix(8)
        return fails + Array(passes)
    }

    private var moduleDisplayName: String {
        guard let moduleId = currentModuleId else { return "SYSTEM_INTEGRITY" }
        return vm.moduleName(for: moduleId).uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: Fail Check Navigation List ──────────────
            VStack(alignment: .leading, spacing: 0) {
                // Back button — 左侧顶部，模块名上方
                Button {
                    vm.selectedScreen = .results
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("BACK TO RESULTS")
                            .font(.mono(T.small, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(.neonGreen.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.15))
                    .frame(height: 1)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(moduleDisplayName)
                        .font(.spectralDisplay(T.titleSm, weight: .bold))
                        .foregroundStyle(.textPrimary)
                        .tracking(-0.5)
                    Text("\(vm.results.filter { $0.moduleId == currentModuleId && $0.status == .fail }.count) VULNERABILITIES")
                        .font(.mono(T.small))
                        .foregroundStyle(.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.15))
                    .frame(height: 1)

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(failChecks, id: \.checkId) { r in
                            navRow(r)
                        }
                        // Also show pass items dimmed (same module only)
                        let passChecks = vm.results.filter { $0.status == .pass && $0.moduleId == currentModuleId }.prefix(8)
                        ForEach(Array(passChecks), id: \.checkId) { r in
                            navRow(r)
                        }
                    }
                }
            }
            .frame(width: 300)
            .background(Color(hex: "#0A0A0C"))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.15))
                    .frame(width: 1)
            }

            // ── Right: Remediation Detail ──────────────────────
            ZStack(alignment: .topLeading) {
                CyberGrid()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        if let result, let check {
                            detailContent(result: result, check: check)
                        } else {
                            Text("Check not found")
                                .foregroundStyle(.textMuted)
                                .padding(28)
                        }
                    }
                }
            }
            .background(Color.voidBase)
        }
        .keyboardShortcut("r", modifiers: .command) // Cmd+R → back then re-run not implemented here, ESC handled above
    }

    @ViewBuilder
    private func navRow(_ r: AuditResult) -> some View {
        let isSelected = r.checkId == checkId
        let color: Color = r.status == .fail ? .statusFail : .neonGreen

        Button {
            vm.selectedScreen = .detail(checkId: r.checkId)
        } label: {
            HStack(spacing: 12) {
                // Status indicator
                Rectangle()
                    .fill(isSelected ? color : color.opacity(0.3))
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(r.checkName)
                        .font(.mono(T.body, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .textPrimary : Color(hex: "#BACCB0"))
                        .lineLimit(2)
                    Text(r.moduleId.uppercased())
                        .font(.mono(T.micro))
                        .foregroundStyle(Color(hex: "#5A6B52"))
                        .tracking(1)
                }

                Spacer()

                Text(r.status == .fail ? "FAIL" : "PASS")
                    .font(.mono(T.small, weight: .bold))
                    .foregroundStyle(color.opacity(isSelected ? 1 : 0.5))
                    .tracking(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? color.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Rectangle()
            .fill(Color(hex: "#3C4B35").opacity(0.08))
            .frame(height: 1)
    }

    @ViewBuilder
    private func detailContent(result: AuditResult, check: AuditCheck) -> some View {
        VStack(alignment: .leading, spacing: 1) {

            // ── Header ───────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text(">> Remediation Protocol \(check.id.prefix(6).uppercased())")
                    .font(.mono(T.small, weight: .bold))
                    .foregroundStyle(.textMuted)
                    .tracking(2)

                                AuditChip(
                                    text: result.status.rawValue.uppercased(),
                                    color: .statusFail,
                                    bgColor: .statusFail.opacity(0.1)
                                )
                                Text(check.name)
                                    .font(.spectralDisplay(T.titleMd, weight: .bold))
                                    .foregroundStyle(.textPrimary)
                                    .tracking(-0.5)
                                Text("ID: \(check.id)")
                                    .font(.mono(T.small))
                                    .foregroundStyle(.textMuted)
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 24)

                            Rectangle()
                                .fill(Color(hex: "#3C4B35").opacity(0.15))
                                .frame(height: 1)
                                .padding(.bottom, 1)

                            // ── Risk Analysis ────────────────────────────
                            sectionHeader(">> Executing Risk Analysis")
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Analyzing configuration state...")
                                    .font(.mono(T.body))
                                    .foregroundStyle(.textPrimary)
                                    .textSelection(.enabled)
                                if result.status == .fail {
                                    Text("Vulnerability Detected: \(check.name) not at expected value.")
                                        .font(.mono(T.body))
                                        .foregroundStyle(.statusFail)
                                        .textSelection(.enabled)
                                }
                                if !check.description.isEmpty {
                                    ZStack(alignment: .topTrailing) {
                                        Text(check.description)
                                            .font(.mono(T.body))
                                            .foregroundStyle(.textMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(12)
                                        // hover 时显示复制提示图标
                                        if descHovered {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color(hex: "#5A6B52"))
                                                .padding(8)
                                        }
                                    }
                                    .background(descHovered ? Color.surfaceLow : Color(hex: "#0D0D0F"))
                                    .overlay(Rectangle().stroke(
                                        descHovered ? Color(hex: "#5A6B52").opacity(0.4) : Color(hex: "#3C4B35").opacity(0.15),
                                        lineWidth: 1
                                    ))
                                    .animation(.easeInOut(duration: 0.12), value: descHovered)
                                    .onHover { descHovered = $0 }
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .padding(.bottom, 8)

                            // ── Current / Target Comparison ───────────────
                            sectionHeader("Comparison")
                            HStack(spacing: 1) {
                                stateBlock(
                                    label: "Current State",
                                    value: result.actualValue ?? "N/A",
                                    color: .statusFail
                                )
                                stateBlock(
                                    label: "Target State",
                                    value: check.expectedValue ?? "N/A",
                                    color: .neonGreen
                                )
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 8)

                            // ── Risk Level ────────────────────────────────
                            if let risk = check.fixRiskLevel {
                                infoBlock(
                                    label: "RISK LEVEL",
                                    value: risk.label.uppercased(),
                                    valueColor: .statusWarn
                                )
                            }

                            // ── Fix Command ───────────────────────────────
                            if let fixCmd = check.fixCommand {
                                sectionHeader("Manual Resolution")
                                commandBlock(label: "FIX COMMAND", command: fixCmd)
                                    .padding(.bottom, 8)

                                // Ghost action buttons (设计稿风格)
                                VStack(spacing: 8) {
                                    primaryActionButton(
                                        label: fixCopied ? "[ COPIED ]" : "[ COPY FIX SHELL COMMAND ]",
                                        active: fixCopied
                                    ) {
                                        NSPasteboard.general.clearContents()
                                        let copyCmd = fixCmd.hasPrefix("sudo ") ? fixCmd : "sudo \(fixCmd)"
                                        NSPasteboard.general.setString(copyCmd, forType: .string)
                                        fixCopied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { fixCopied = false }
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.bottom, 16)
                            }
                        }
    }

    // MARK: - Sub-components

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.mono(T.small, weight: .bold))
            .foregroundStyle(.textMuted)
            .tracking(3)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
    }

    @ViewBuilder
    private func stateBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.mono(T.small))
                .foregroundStyle(.textMuted)
                .tracking(2)
            Text(value)
                .font(.spectralDisplay(T.titleSm, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceLow)
        .overlay(Rectangle().stroke(
            label == "Target State" ? color.opacity(0.2) : Color(hex: "#3C4B35").opacity(0.1),
            lineWidth: 1
        ))
    }

    @ViewBuilder
    private func infoBlock(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.mono(T.small, weight: .bold))
                .foregroundStyle(.textMuted)
                .tracking(3)
            Text(value)
                .font(.mono(T.bodyLg, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceLow)
        .padding(.horizontal, 28)
        .padding(.bottom, 1)
    }

    @ViewBuilder
    private func commandBlock(label: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.mono(T.small, weight: .bold))
                    .foregroundStyle(.textMuted)
                    .tracking(3)
                Spacer()
                Text("OSX_KERNEL_CTL")
                    .font(.mono(T.small))
                    .foregroundStyle(.linkCyan.opacity(0.6))
            }

            // Code block
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("# Apply fix")
                        .font(.mono(T.body))
                        .foregroundStyle(.linkCyan.opacity(0.6))
                    Text(command)
                        .font(.mono(T.body))
                        .foregroundStyle(.neonGreen)
                        .textSelection(.enabled)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#0A0A0C"))

                // Terminal dots
                HStack(spacing: 4) {
                    ForEach([Color.statusFail, Color.statusWarn, Color.neonGreen], id: \.self) { c in
                        Rectangle().fill(c).frame(width: 6, height: 6)
                    }
                }
                .padding(8)
            }
            .overlay(Rectangle().stroke(Color(hex: "#3C4B35").opacity(0.2), lineWidth: 1))
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func ghostActionButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.mono(T.body, weight: .bold))
                .tracking(3)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .overlay(Rectangle().stroke(color, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func primaryActionButton(label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.mono(T.body, weight: .bold))
                .tracking(3)
                .foregroundStyle(Color(hex: "#032800"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if active {
                            AnyView(Color.neonGreen)
                        } else {
                            AnyView(LinearGradient.spectral)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

