// Components.swift — 可复用 UI 组件（矩阵动画、脉冲指示器、审计标签、环形图表等）
import SwiftUI

// MARK: - Matrix Falling Dots (Dashboard background decoration)

/// 在给定区域内随机生成缓慢下落的绿点，类似 Matrix 字雨但稀疏
/// 使用 TimelineView(.animation) 驱动，无需 @State，GPU 友好
struct MatrixFallingDots: View {
    struct DotSpec: Sendable {
        let xFraction: CGFloat   // 0...1
        let phaseOffset: Double  // seconds, stagger start times
        let duration: Double     // seconds per cycle
        let baseOpacity: Double
        let dotSize: CGFloat
    }

    private let dots: [DotSpec]
    private let color: Color

    init(count: Int = 5, color: Color = .neonGreen) {
        self.color = color
        // 固定随机种子的感觉：init 时生成一组分布，避免每次 render 重新随机
        // 避开最左 15% 和最右 10%（防止和左侧 LOGO 视觉干扰）
        self.dots = (0..<count).map { i in
            DotSpec(
                xFraction: [0.22, 0.38, 0.54, 0.71, 0.86][i % 5]
                    + CGFloat.random(in: -0.03...0.03),
                phaseOffset: Double.random(in: 0...6),
                duration: Double.random(in: 4.5...7.5),
                baseOpacity: Double.random(in: 0.35...0.7),
                dotSize: CGFloat.random(in: 3...5)
            )
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { ctx in
            Canvas { gctx, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                for dot in dots {
                    let cycle = (t + dot.phaseOffset).truncatingRemainder(dividingBy: dot.duration)
                    let progress = cycle / dot.duration
                    let y = size.height * CGFloat(progress)
                    let x = size.width * dot.xFraction
                    let fade = Self.fadeProfile(progress) * dot.baseOpacity
                    let rect = CGRect(
                        x: x - dot.dotSize / 2,
                        y: y - dot.dotSize / 2,
                        width: dot.dotSize,
                        height: dot.dotSize
                    )
                    gctx.fill(Path(rect), with: .color(color.opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 0-0.1 淡入，0.1-0.85 满，0.85-1 淡出
    private static func fadeProfile(_ p: Double) -> Double {
        if p < 0.1 { return p / 0.1 }
        if p > 0.85 { return (1 - p) / 0.15 }
        return 1
    }
}

// MARK: - Center Falling Dot (prominent, through ring)

/// 单点从容器顶部缓慢下落到底部，用于 Dashboard Ring 内部做「扫描点」装饰
struct CenterFallingDot: View {
    var duration: Double = 5
    var color: Color = .neonGreen
    var dotSize: CGFloat = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { ctx in
            Canvas { gctx, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let progress = t.truncatingRemainder(dividingBy: duration) / duration
                let y = size.height * CGFloat(progress)
                let fade = Self.fadeProfile(progress)
                let rect = CGRect(
                    x: size.width / 2 - dotSize / 2,
                    y: y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                gctx.fill(Path(rect), with: .color(color.opacity(fade)))
            }
        }
        .allowsHitTesting(false)
    }

    private static func fadeProfile(_ p: Double) -> Double {
        if p < 0.08 { return p / 0.08 }
        if p > 0.9 { return (1 - p) / 0.1 }
        return 1
    }
}

// MARK: - Pulse Indicator (breathing square)

struct PulseIndicator: View {
    var color: Color = .neonGreen
    var size: CGFloat = 7

    @State private var opacity: Double = 0.4

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Audit Chip (status badge)

struct AuditChip: View {
    let text: String
    var color: Color = .neonGreen
    var bgColor: Color = .neonGreen.opacity(0.12)

    var body: some View {
        Text(text)
            .font(.mono(11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .overlay(
                Rectangle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Ghost Border container

struct GhostBorderBox<Content: View>: View {
    let content: Content
    var bgColor: Color = .surfaceLow

    init(bgColor: Color = .surfaceLow, @ViewBuilder content: () -> Content) {
        self.bgColor = bgColor
        self.content = content()
    }

    var body: some View {
        content
            .background(bgColor)
            .overlay(
                Rectangle()
                    .stroke(Color.ghostBorder, lineWidth: 1)
            )
    }
}

// MARK: - Spectral Button

struct SpectralButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonVariant = .primary

    enum ButtonVariant { case primary, ghost }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if style == .ghost {
                    // 设计稿风格：深色背景 + 亮绿边框 + [ ] 装饰
                    HStack(spacing: 0) {
                        Text("[ ")
                            .foregroundStyle(Color.neonGreen.opacity(0.6))
                        Text(title)
                            .foregroundStyle(isHovered ? Color.neonGreen : Color.neonGreen.opacity(0.85))
                        Text(" ]")
                            .foregroundStyle(Color.neonGreen.opacity(0.6))
                    }
                    .font(.mono(14, weight: .bold))
                    .tracking(4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.4))
                    .overlay(
                        Rectangle()
                            .stroke(
                                isHovered ? Color.neonGreen : Color.neonGreen.opacity(0.5),
                                lineWidth: 1
                            )
                    )
                } else {
                    // primary：绿色填充
                    Text(title)
                        .font(.spectralDisplay(18, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(LinearGradient.spectral)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Ring Chart

struct RingChart: View {
    let score: Int
    var maxScore: Int = 100
    var size: CGFloat = 380
    var showStatus: Bool = true

    private let trackWidth: CGFloat = 2
    private let progressWidth: CGFloat = 8
    private var progress: Double { Double(score) / Double(maxScore) }

    var body: some View {
        ZStack {
            // Outer decorative ghost ring
            Circle()
                .stroke(Color.neonGreen.opacity(0.05), lineWidth: 1)
                .frame(width: size + 24, height: size + 24)

            // Track ring
            Circle()
                .stroke(Color.surfaceLow, lineWidth: trackWidth)
                .frame(width: size, height: size)

            // Progress arc — thin, sharp, with glow
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.neonGreen,
                    style: StrokeStyle(lineWidth: progressWidth, lineCap: .butt)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: .neonGreen.opacity(0.6), radius: 12)
                .shadow(color: .neonGreen.opacity(0.3), radius: 24)

            // Center readout
            VStack(spacing: 8) {
                Text("SYSTEM SCORE")
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(.neonGreen)
                    .tracking(5)

                HStack(alignment: .bottom, spacing: 2) {
                    Text("\(score)")
                        .font(.spectralDisplay(96))
                        .foregroundStyle(.textPrimary)
                    Text("/\(maxScore)")
                        .font(.spectralDisplay(34))
                        .foregroundStyle(.neonGreen)
                        .padding(.bottom, 14)
                }

                HStack(spacing: 8) {
                    PulseIndicator(size: 6)
                    Text(statusLabel)
                        .font(.mono(11, weight: .bold))
                        .foregroundStyle(.neonGreen)
                        .tracking(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.neonGreen.opacity(0.08))
                .overlay(Rectangle().stroke(Color.neonGreen.opacity(0.2), lineWidth: 1))
                .opacity(showStatus ? 1 : 0)
            }
        }
    }

    private var statusLabel: String {
        switch score {
        case 90...100: return "OPTIMAL DEFENSE"
        case 70..<90:  return "MODERATE RISK"
        case 50..<70:  return "ELEVATED RISK"
        default:       return "CRITICAL RISK"
        }
    }
}

// MARK: - Module Row (results list)

struct ModuleRow: View {
    let name: String
    let passed: Int
    let total: Int
    var isActive: Bool = false

    private var score: Int { total > 0 ? passed * 100 / total : 0 }
    private var color: Color {
        score >= 90 ? .neonGreen : score >= 70 ? .statusWarn : .statusFail
    }

    var body: some View {
        HStack(spacing: 0) {
            // 设计稿：左侧 border-l-2 色条
            Rectangle()
                .fill(isActive ? color : color.opacity(0.3))
                .frame(width: 2)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(name.uppercased())
                        .font(.mono(16, weight: .bold))
                        .foregroundStyle(isActive ? .textPrimary : Color(hex: "#BACCB0"))
                        .tracking(0.5)
                        .lineLimit(2)
                    Text("\(passed)/\(total) CHECKS PASSED")
                        .font(.mono(14))
                        .foregroundStyle(Color(hex: "#5A6B52"))
                }

                Spacer()

                Text("\(score)%")
                    .font(.mono(22, weight: .bold))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .contentShape(Rectangle())
    }
}
