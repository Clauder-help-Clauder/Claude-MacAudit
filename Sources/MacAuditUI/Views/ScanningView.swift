// ScanningView.swift — 扫描中页面，展示实时扫描进度和终端风格日志
import SwiftUI
import MacAuditCore

struct ScanningView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var sweepAngle: Double = 0

    var body: some View {
        ZStack {
            CyberGrid()

            // Glow orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.neonGreen.opacity(0.05))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: geo.size.width * 0.6, y: -80)
                Circle()
                    .fill(Color.linkCyan.opacity(0.04))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -80, y: geo.size.height * 0.6)
            }
            .allowsHitTesting(false)

            VStack(spacing: 40) {
                Spacer()

                // Scanner radar
                ZStack {
                    // Background rings
                    ForEach([480.0, 360.0, 240.0], id: \.self) { d in
                        Circle()
                            .stroke(Color(hex: "#3C4B35").opacity(0.2), lineWidth: 1)
                            .frame(width: d, height: d)
                    }

                    // Sweep
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(
                            AngularGradient(
                                colors: [.neonGreen.opacity(0), .neonGreen.opacity(0.35)],
                                center: .center
                            ),
                            lineWidth: 200
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(sweepAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                                sweepAngle = 360
                            }
                        }

                    // Rotating dashed ring
                    Circle()
                        .stroke(Color.neonGreen.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
                        .frame(width: 460, height: 460)
                        .rotationEffect(.degrees(-sweepAngle * 0.2))

                    // Corner accent squares
                    ForEach([(0.0, -240.0), (0.0, 240.0), (-240.0, 0.0), (240.0, 0.0)], id: \.0) { x, y in
                        Rectangle()
                            .fill(x == 0 ? Color.neonGreen : Color.linkCyan)
                            .frame(width: 6, height: 6)
                            .offset(x: x, y: y)
                    }

                    // Center readout
                    VStack(spacing: 6) {
                        Text("SYSTEM SCAN IN PROGRESS")
                            .font(.mono(9, weight: .bold))
                            .foregroundStyle(.neonGreen)
                            .tracking(4)
                        Text("\(Int(vm.scanProgress * 100))%")
                            .font(.spectralDisplay(56, weight: .bold))
                            .foregroundStyle(.textPrimary)
                            .monospacedDigit()
                        Text(vm.currentScanningModule.uppercased())
                            .font(.mono(11))
                            .foregroundStyle(.linkCyan)
                            .lineLimit(1)
                        if vm.currentScanningModule.contains("开发工具") {
                            Text("DEV TOOLS SCAN — 最长约 60 秒")
                                .font(.mono(9, weight: .bold))
                                .foregroundStyle(.statusWarn.opacity(0.8))
                                .tracking(2)
                                .lineLimit(1)
                        } else {
                            Text("THREAT_VECTOR: ANALYZING")
                                .font(.mono(9))
                                .foregroundStyle(Color(hex: "#85967C"))
                                .tracking(2)
                        }
                    }
                }
                .frame(width: 480, height: 480)

                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("KERNEL INTEGRITY")
                            .font(.mono(9, weight: .bold))
                            .foregroundStyle(.neonGreen)
                            .tracking(4)
                        Spacer()
                        Text("\(Int(vm.scanProgress * 100))%")
                            .font(.mono(11, weight: .bold))
                            .foregroundStyle(Color(hex: "#85967C"))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.surfaceLow).frame(height: 2)
                            Rectangle()
                                .fill(Color.neonGreen)
                                .frame(width: geo.size.width * vm.scanProgress, height: 2)
                                .shadow(color: .neonGreen.opacity(0.8), radius: 6)
                        }
                    }
                    .frame(height: 2)

                    // Phase segments
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { i in
                            let filled = vm.scanProgress > Double(i) * 0.25
                            Rectangle()
                                .fill(filled ? Color.neonGreen.opacity(0.5) : Color.surfaceLow)
                                .frame(height: 3)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(width: 480)

                // Terminal log window — 绑定真实 vm.scanLog
                VStack(alignment: .leading, spacing: 0) {
                    // Window title bar
                    HStack(spacing: 6) {
                        ForEach([Color.statusFail, Color.statusWarn, Color.neonGreen], id: \.self) { c in
                            Circle().fill(c).frame(width: 8, height: 8)
                        }
                        Spacer()
                        Text("AUDIT_LOG_STREAM")
                            .font(.mono(9))
                            .foregroundStyle(Color(hex: "#85967C"))
                            .tracking(3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(hex: "#3C4B35").opacity(0.2))
                            .frame(height: 1)
                    }

                    // Log lines from vm
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(vm.scanLog.enumerated()), id: \.offset) { idx, line in
                                    Text(line)
                                        .font(.mono(10))
                                        .foregroundStyle(line.contains("failed: 0") ? Color.neonGreen : .textMuted)
                                        .id(idx)
                                }
                                Text("_")
                                    .font(.mono(10))
                                    .foregroundStyle(.neonGreen)
                                    .id("cursor")
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: vm.scanLog.count) { _, _ in
                                proxy.scrollTo("cursor", anchor: .bottom)
                            }
                        }
                        .frame(height: 100)
                    }
                }
                .frame(width: 480)
                .background(Color(hex: "#0E0E10").opacity(0.85))
                .overlay(
                    Rectangle()
                        .stroke(Color(hex: "#3C4B35").opacity(0.2), lineWidth: 1)
                )

                Spacer()
            }
            .padding(48)
        }
    }
}
