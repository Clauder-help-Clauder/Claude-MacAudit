// MacAuditApp.swift — SwiftUI 应用入口，配置窗口样式和默认尺寸

import SwiftUI

@main
struct MacAuditApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1280, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 860)
        .windowResizability(.contentMinSize)
    }
}
