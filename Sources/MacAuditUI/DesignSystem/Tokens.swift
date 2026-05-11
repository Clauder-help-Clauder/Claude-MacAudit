// Tokens.swift — 设计令牌（颜色、字体、间距、渐变），统一视觉风格
import SwiftUI

// MARK: - Spectral Minimalism Design Tokens

extension Color {
    // Base surfaces
    static let voidBase     = Color(hex: "#0A0A0C")
    static let surfaceDim   = Color(hex: "#131315")
    static let surfaceLow   = Color(hex: "#1C1B1D")
    static let surfaceMid   = Color(hex: "#201F21")
    static let surfaceHigh  = Color(hex: "#2A2A2C")
    static let surfaceTop   = Color(hex: "#353437")

    // Primary — Neon Green
    static let neonGreen    = Color(hex: "#39FF14")
    static let neonGreenDim = Color(hex: "#2AE500")
    static let neonGreenSoft = Color(hex: "#79FF5B")
    static let neonGreenDeep = Color(hex: "#107100")

    // Secondary — Link Cyan
    static let linkCyan     = Color(hex: "#00F4FE")
    static let cyanDim      = Color(hex: "#00DCE5")

    // Text
    static let textPrimary  = Color(hex: "#E5E1E4")
    static let textMuted    = Color(hex: "#BACCB0")
    static let textGhost    = Color(hex: "#5A6B52")

    // Status
    static let statusPass   = Color(hex: "#39FF14")
    static let statusFail   = Color(hex: "#FFB4AB")
    static let statusWarn   = Color(hex: "#FFD700")
    static let statusInfo   = Color(hex: "#00F4FE")

    // Ghost border
    static let ghostBorder  = Color(hex: "#3C4B35").opacity(0.15)
    static let outlineVariant = Color(hex: "#3C4B35")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

extension Font {
    // Space Grotesk — headlines (PostScript names, no weight modifier)
    static func spectralDisplay(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        switch weight {
        case .black, .heavy, .bold: return .custom("SpaceGrotesk-Bold", size: size)
        case .semibold, .medium:    return .custom("SpaceGrotesk-Medium", size: size)
        case .light, .thin:         return .custom("SpaceGrotesk-Light", size: size)
        default:                    return .custom("SpaceGrotesk-Regular", size: size)
        }
    }

    // JetBrains Mono — data / code
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .black, .heavy, .bold, .semibold: return .custom("JetBrainsMono-Bold", size: size)
        case .medium:                           return .custom("JetBrainsMono-Medium", size: size)
        default:                                return .custom("JetBrainsMono-Regular", size: size)
        }
    }

    // Inter — labels (system font)
    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Typography Scale（统一字号规范）

enum T {
    // Monospace — JetBrainsMono
    static let micro:  CGFloat = 11   // 追踪标签、badge、module ID
    static let small:  CGFloat = 13   // 次要文字、状态值、ID 字符串
    static let body:   CGFloat = 15   // 正文、描述、检测项名称
    static let bodyLg: CGFloat = 17   // 大正文、section label

    // Display — SpaceGrotesk
    static let titleSm: CGFloat = 20  // 小标题
    static let titleMd: CGFloat = 28  // 中标题（页面主检测项名）
    static let titleLg: CGFloat = 44  // 大标题（页面名）
    static let titleXl: CGFloat = 56  // 超大标题

    // Spacing shortcuts
    static let rowV:  CGFloat = 12   // 行内竖向 padding
    static let rowH:  CGFloat = 20   // 行内横向 padding
}

// MARK: - Spacing

enum Spacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 40
    static let xxl: CGFloat = 64
}

// MARK: - Gradients

extension LinearGradient {
    static let spectral = LinearGradient(
        colors: [.neonGreen, .neonGreenDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - ShapeStyle convenience (so .foregroundStyle(.neonGreen) works)

extension ShapeStyle where Self == Color {
    static var neonGreen: Color    { .neonGreen }
    static var linkCyan: Color     { .linkCyan }
    static var textPrimary: Color  { .textPrimary }
    static var textMuted: Color    { .textMuted }
    static var textGhost: Color    { .textGhost }
    static var statusPass: Color   { .statusPass }
    static var statusFail: Color   { .statusFail }
    static var statusWarn: Color   { .statusWarn }
    static var statusInfo: Color   { .statusInfo }
    static var voidBase: Color     { .voidBase }
    static var surfaceDim: Color   { .surfaceDim }
    static var surfaceLow: Color   { .surfaceLow }
    static var ghostBorder: Color  { .ghostBorder }
}
