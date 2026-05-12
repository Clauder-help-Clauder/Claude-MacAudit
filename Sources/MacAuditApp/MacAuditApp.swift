// MacAudit SwiftUI 应用入口 — 通过 MacAuditUI 模块构建图形界面，
// 提供与 CLI 工具相同功能的可视化审计体验

import SwiftUI
import MacAuditUI

@main
struct MacAuditApp: App {
    var body: some Scene {
        WindowGroup {
            makeMacAuditRootView()
                .frame(minWidth: 1280, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 860)
        .windowResizability(.contentMinSize)
    }
}
