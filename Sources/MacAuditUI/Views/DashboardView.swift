// DashboardView.swift — 仪表盘主页，展示审计概览、模块状态、统计图表和快捷操作
import SwiftUI
import MacAuditCore

struct DashboardView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var decorRotation: Double = 0
    @State private var lastResultsHovered = false

    // Static formatter — 避免在 view body 每次渲染时重建
    private static let snapshotFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd  HH:mm"; return f
    }()

    var body: some View {
        ZStack {
            CyberGrid()

            // Matrix 风格稀疏下落绿点 (5个，随机 x / 相位 / 速度)
            MatrixFallingDots(count: 5, color: .neonGreen)
                .padding(.horizontal, 40)
                .allowsHitTesting(false)

            // Spectral glow orbs (设计稿背景装饰)
            GeometryReader { geo in
                // 右上绿色 glow
                Circle()
                    .fill(Color.neonGreen.opacity(0.05))
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .offset(x: geo.size.width * 0.65, y: -geo.size.height * 0.15)
                // 左下青色 glow
                Circle()
                    .fill(Color.linkCyan.opacity(0.04))
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .offset(x: -geo.size.width * 0.15, y: geo.size.height * 0.65)
            }
            .allowsHitTesting(false)

            if vm.results.isEmpty {
                emptyState
            } else {
                loadedState
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GeometryReader { geo in
            // 响应式 Ring 尺寸：不超过可用高度的 48%，也不超过 360
            let ringSize = max(200, min(360, geo.size.height * 0.48))
            let decorPad: CGFloat = 40  // 装饰圈比 ring 大 40
            let cornerOffset = (ringSize + decorPad) / 2 + 10

        VStack(spacing: 36) {
            Spacer(minLength: 16)

            // Ring + decorative orbital elements
            ZStack {
                // 外层装饰大环
                Circle()
                    .stroke(Color(hex: "#3C4B35").opacity(0.15), lineWidth: 1)
                    .frame(width: ringSize + decorPad, height: ringSize + decorPad)

                // 旋转 dashed 装饰圆（设计稿 border-dashed border-primary/10 animate-spin）
                Circle()
                    .stroke(
                        Color.neonGreen.opacity(0.08),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 12])
                    )
                    .frame(width: ringSize + decorPad + 20, height: ringSize + decorPad + 20)
                    .rotationEffect(.degrees(decorRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                            decorRotation = 360
                        }
                    }

                // Corner accent pulsars (呼吸) — 相对 ring 尺寸自适应
                ForEach([(0.0, -cornerOffset, true), (0.0, cornerOffset, true), (-cornerOffset, 0.0, false), (cornerOffset, 0.0, false)], id: \.0) { x, y, isGreen in
                    PulseIndicator(color: isGreen ? .neonGreen : .linkCyan, size: 5)
                        .offset(x: x, y: y)
                }

                // 中心下落点 — 覆盖环的区域，从上往下缓慢扫过
                CenterFallingDot(duration: 5)
                    .frame(width: ringSize, height: ringSize)

                RingChart(score: 0, size: ringSize, showStatus: false)
            }

            VStack(spacing: 8) {
                Text("NO AUDIT DATA")
                    .font(.mono(16, weight: .bold))
                    .foregroundStyle(.textMuted)
                    .tracking(5)
                Text("Run a full system scan to generate your security score")
                    .font(.label(14))
                    .foregroundStyle(Color(hex: "#4A6244"))
            }
            VStack(spacing: 12) {
                SpectralButton(
                    title: vm.hasSavedSnapshot ? "INITIATE NEW AUDIT" : "INITIATE FULL SYSTEM AUDIT",
                    action: { Task { await vm.startAudit() } },
                    style: .ghost
                )
                .frame(width: 440)

                // 上次结果入口 — 在主按钮下方，低调灰色风格
                if vm.hasSavedSnapshot, let snap = vm.savedSnapshot {
                    Button { vm.restoreFromSnapshot() } label: {
                        VStack(spacing: 5) {
                            Text("LAST RESULTS")
                                .font(.mono(14, weight: .bold))
                                .foregroundStyle(lastResultsHovered ? .textMuted : Color(hex: "#5A6B52"))
                                .tracking(3)
                            Text("\(Self.snapshotFmt.string(from: snap.timestamp))  ·  \(snap.systemScore)%  ·  \(snap.results.filter { $0.status == .fail }.count) failed")
                                .font(.mono(10))
                                .foregroundStyle(lastResultsHovered ? Color(hex: "#5A6B52") : Color(hex: "#3C4B35"))
                        }
                        .frame(width: 440)
                        .padding(.vertical, 12)
                        .background(lastResultsHovered ? Color.neonGreen.opacity(0.04) : Color.clear)
                        .overlay(Rectangle().stroke(
                            lastResultsHovered ? Color(hex: "#5A6B52").opacity(0.6) : Color(hex: "#3C4B35").opacity(0.4),
                            lineWidth: 1
                        ))
                        .animation(.easeInOut(duration: 0.15), value: lastResultsHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { lastResultsHovered = $0 }
                }

                // Proxy Rule [WARN] — 醒目红色警告按钮
                Button {
                    vm.selectedScreen = .proxyRule
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Proxy Rule")
                            .font(.spectralDisplay(18, weight: .bold))
                            .tracking(2)
                        Text("[WARN]")
                            .font(.mono(12, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(Color(hex: "#FF4444"))
                    .frame(width: 440)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#FF4444").opacity(0.06))
                    .overlay(Rectangle().stroke(Color(hex: "#FF4444").opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                // [ GITHUB LINK ] + check update
                Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit")!) {
                    VStack(spacing: 4) {
                        Text("[ GITHUB LINK ]")
                            .font(.mono(12, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.linkCyan)
                        Text("check update")
                            .font(.mono(8))
                            .tracking(1)
                            .foregroundStyle(Color.linkCyan.opacity(0.6))
                    }
                    .frame(width: 440)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Text("QUANTUM-LEVEL HEURISTIC SCAN READY")
                    .font(.mono(9))
                    .foregroundStyle(Color(hex: "#353437"))
                    .tracking(3)
            }
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 60)
        .frame(width: geo.size.width, height: geo.size.height)
        }  // end GeometryReader
    }

    // MARK: - Loaded State

    private var loadedState: some View {
        VStack(spacing: 0) {
            // Center: ring + stats — 响应式：Ring 尺寸根据剩余空间计算
            GeometryReader { geo in
                // 可用高度 = 总高度 - 底部固定条（72 + 64 = 136）
                // Ring 占剩余空间的一部分，但不超过 360
                let ringSize = max(200, min(360, geo.size.height * 0.45))
                VStack(spacing: 24) {
                    Spacer(minLength: 12)
                    ZStack {
                        // 中心下落点 — 经过 Ring 的装饰
                        CenterFallingDot(duration: 5)
                            .frame(width: ringSize, height: ringSize)
                        RingChart(score: vm.systemScore, size: ringSize)
                    }
                    statsRow
                    VStack(spacing: 10) {
                        SpectralButton(title: "RE-RUN AUDIT", action: {
                            Task { await vm.startAudit() }
                        }, style: .ghost)
                        .frame(width: 320)

                        // [ GITHUB LINK ] + check update
                        Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit")!) {
                            VStack(spacing: 4) {
                                Text("[ GITHUB LINK ]")
                                    .font(.mono(12, weight: .bold))
                                    .tracking(2)
                                    .foregroundStyle(Color.linkCyan)
                                Text("check update")
                                    .font(.mono(8))
                                    .tracking(1)
                                    .foregroundStyle(Color.linkCyan.opacity(0.6))
                            }
                            .frame(width: 440)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        Text("QUANTUM-LEVEL HEURISTIC SCAN READY")
                            .font(.mono(9))
                            .foregroundStyle(Color(hex: "#353437"))
                            .tracking(3)
                    }
                    Spacer(minLength: 12)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            // Bottom module strip
            moduleStrip

            // Bottom footer info bar (设计稿 Hardware/OS + Audit Metrics)
            dashboardFooter
        }
    }

    private var dashboardFooter: some View {
        HStack(alignment: .bottom) {
            // Left: Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text("HARDWARE / OS")
                    .font(.mono(9, weight: .bold))
                    .foregroundStyle(Color(hex: "#353437"))
                    .tracking(3)
                HStack(spacing: 8) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 16))
                        .foregroundStyle(.linkCyan)
                    Text(deviceInfoString)
                        .font(.spectralDisplay(15, weight: .bold))
                        .foregroundStyle(.textPrimary)
                }
            }

            Spacer()

            // Center: GitHub link
            Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit")!) {
                Text("</> github.com/Clauder-help-Clauder/Claude-MacAudit")
                    .font(.mono(8))
                    .foregroundStyle(Color(hex: "#3C4B35"))
            }
            .buttonStyle(.plain)

            Spacer()

            // Right: Audit Metrics
            HStack(spacing: 32) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("LAST AUDIT")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(.neonGreen.opacity(0.5))
                        .tracking(2)
                    if let date = vm.lastAuditDate {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(relativeTime(date))
                                .font(.spectralDisplay(18, weight: .bold))
                                .foregroundStyle(.textPrimary)
                        }
                    } else {
                        Text("--")
                            .font(.spectralDisplay(18, weight: .bold))
                            .foregroundStyle(Color(hex: "#3C4B35"))
                    }
                }
                VStack(alignment: .trailing, spacing: 4) {
                    Text("FAILED CHECKS")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(.statusFail.opacity(0.6))
                        .tracking(2)
                    HStack(spacing: 6) {
                        let failCount = vm.results.filter { $0.status == .fail }.count
                        if failCount > 0 {
                            Rectangle()
                                .fill(Color.statusFail)
                                .frame(width: 7, height: 7)
                        }
                        Text(failCount > 0 ? "\(failCount) Critical" : "None")
                            .font(.spectralDisplay(18, weight: .bold))
                            .foregroundStyle(failCount > 0 ? .statusFail : .neonGreen)
                    }
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .frame(height: 64)
        .background(Color(hex: "#0D0D0F"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#3C4B35").opacity(0.1))
                .frame(height: 1)
        }
    }

    private var deviceInfoString: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(os.majorVersion).\(os.minorVersion)"
    }

    private func relativeTime(_ date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "JUST NOW" }
        if mins < 60 { return "\(mins) MIN AGO" }
        let hrs = mins / 60
        return "\(hrs) HR AGO"
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statBlock(
                label: "PASSED",
                value: "\(vm.results.filter { $0.status == .pass }.count)",
                color: .neonGreen
            )
            divider
            statBlock(
                label: "FAILED",
                value: "\(vm.results.filter { $0.status == .fail }.count)",
                color: .statusFail
            )
            divider
            statBlock(
                label: "TOTAL",
                value: "\(vm.results.count)",
                color: .textMuted
            )
            divider
            statBlock(
                label: "MODULES",
                value: "\(vm.moduleSummaries.count)",
                color: .linkCyan
            )
        }
        .padding(.vertical, 20)
        .background(Color.surfaceLow)
        .overlay(Rectangle().stroke(Color.neonGreen.opacity(0.1), lineWidth: 1))
        .frame(maxWidth: 560)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.neonGreen.opacity(0.1))
            .frame(width: 1, height: 50)
    }

    // MARK: - Module Strip

    private var moduleStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(vm.moduleSummaries.enumerated()), id: \.element.id) { idx, summary in
                moduleCard(summary)
                if idx < vm.moduleSummaries.count - 1 {
                    Rectangle()
                        .fill(Color(hex: "#3C4B35").opacity(0.15))
                        .frame(width: 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(Color(hex: "#0A0A0C"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#3C4B35").opacity(0.15))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func moduleCard(_ summary: ModuleSummary) -> some View {
        let color: Color = summary.score >= 90 ? .neonGreen
            : summary.score >= 70 ? .statusWarn
            : .statusFail
        let short = shortName(summary.name)
        let hasFails = (summary.total - summary.passed) > 0

        Button {
            vm.selectedScreen = .results
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                // Module short name
                Text(short)
                    .font(.mono(9, weight: .bold))
                    .foregroundStyle(Color(hex: "#5A6B52"))
                    .tracking(1)
                    .lineLimit(1)

                // Score large
                Text("\(summary.score)%")
                    .font(.mono(20, weight: .bold))
                    .foregroundStyle(color)

                // Pass / total
                HStack(spacing: 4) {
                    if hasFails {
                        Rectangle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                    Text("\(summary.passed)/\(summary.total)")
                        .font(.mono(9))
                        .foregroundStyle(Color(hex: "#3A5234"))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(color).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func shortName(_ name: String) -> String {
        let map: [String: String] = [
            "系统信息": "SYSINFO",
            "网络安全机制及调优": "NETWORK",
            "隐私与遥测": "PRIVACY",
            "视觉动画优化": "ANIM",
            "服务状态": "SERVICES",
            "电源配置": "POWER",
            "终端环境": "SHELL",
            "AI服务调优": "AI-SVC",
            "开发工具": "DEV",
            "IP 质量检测": "IP",
            "Chrome 浏览器": "CHROME",
            "Safari 浏览器": "SAFARI",
        ]
        return map[name] ?? name.uppercased()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Text(value)
                .font(.mono(40, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.mono(12, weight: .bold))
                .foregroundStyle(Color(hex: "#4A6244"))
                .tracking(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

// MARK: - Cyber Grid Background

struct SpectralBackground: View {
    var body: some View {
        ZStack {
            // 1. The Void Base
            Color(hex: "#0A0A0C").ignoresSafeArea()
            
            // 2. Giant Spectral Glow Orbs (from Stitch Design)
            GeometryReader { geo in
                ZStack {
                    // Top Right - Primary Glow
                    Circle()
                        .fill(Color.neonGreen.opacity(0.05))
                        .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                        .blur(radius: 120)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.2)
                    
                    // Bottom Left - Secondary Glow
                    Circle()
                        .fill(Color.linkCyan.opacity(0.05))
                        .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                        .blur(radius: 120)
                        .position(x: geo.size.width * 0.2, y: geo.size.height * 0.9)
                }
            }
            .allowsHitTesting(false)
            
            // 3. Mathematical Grid
            Canvas { context, size in
                let step: CGFloat = 48
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(Color(hex: "#3C4B35").opacity(0.10)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

struct CyberGrid: View {
    var body: some View {
        SpectralBackground()
    }
}

// MARK: - Preview

#if canImport(PreviewsMacros)
@_spi(Experimental) import PreviewsMacros
#Preview("Dashboard — Empty") {
    DashboardView()
        .environment(AppViewModel())
        .frame(width: 960, height: 700)
        .background(Color.voidBase)
}
#endif
