// PublicEntry.swift — GUI 公共入口，注册自定义字体和资源 Bundle
import SwiftUI
import CoreText

/// Public entry point for the MacAuditUI framework.
/// Called by the MacAuditApp executable launcher.
@MainActor
public func makeMacAuditRootView() -> some View {
    registerBundledFonts()
    return ContentView()
}

// MARK: - Font Registration

/// 注册打包在 MacAuditUI bundle 里的自定义字体。
/// 必须在任何 SwiftUI 视图渲染之前调用，否则 Font.custom() 找不到字体会回退到系统默认。
private func registerBundledFonts() {
    let fontNames = [
        "SpaceGrotesk-Bold",
        "SpaceGrotesk-Medium",
        "SpaceGrotesk-Regular",
        "SpaceGrotesk-Light",
        "JetBrainsMono-Bold",
        "JetBrainsMono-Medium",
        "JetBrainsMono-Regular",
    ]
    let extensions = ["otf", "ttf"]
    let bundle = Bundle.module

    for name in fontNames {
        for ext in extensions {
            guard let url = bundle.url(forResource: name, withExtension: ext) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            break  // 找到一种格式即可
        }
    }
}
