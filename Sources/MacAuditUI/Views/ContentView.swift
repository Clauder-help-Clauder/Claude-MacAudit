// ContentView.swift — 应用根视图，包含侧边栏导航、顶栏、状态栏和主内容区域的布局
import SwiftUI
import MacAuditCore

// MARK: - Sidebar Navigation

struct SidebarView: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 0) {

            // ── Logo ──────────────────────────────────────
            HStack(spacing: 16) {
                ZStack {
                    Rectangle()
                        .stroke(Color.neonGreen, lineWidth: 2.5)
                        .frame(width: 48, height: 48)
                    Text("_")
                        .font(.mono(26, weight: .bold))
                        .foregroundStyle(.neonGreen)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("M_A")
                        .font(.spectralDisplay(40, weight: .bold))
                        .foregroundStyle(.neonGreen)
                        .tracking(-1)
                    Text("MACAUDIT \(AppConstants.version)")
                        .font(.mono(10))
                        .foregroundStyle(.neonGreen.opacity(0.4))
                        .tracking(2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 40)

            // ── Nav ────────────────────────────────────────
            navItem(.dashboard,  icon: "square.grid.2x2.fill",  label: "Dashboard")
            navItem(.results,    icon: "shield.lefthalf.filled", label: "Security")
            navItem(.history,    icon: "clock.fill",             label: "History")
            proxyRuleNavItem()
            navItem(.settings,   icon: "gearshape.fill",         label: "Settings")

            Spacer(minLength: 16)

            // ── System Info ────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.neonGreen.opacity(0.4))
                        .frame(width: 14, height: 1)
                    Text("SYSTEM")
                        .font(.mono(8, weight: .bold))
                        .foregroundStyle(Color(hex: "#3C4B35"))
                        .tracking(3)
                    Rectangle()
                        .fill(Color.neonGreen.opacity(0.4))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)

                SystemInfoPanel(compact: true)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)

            // ── Status ─────────────────────────────────────
            HStack(spacing: 10) {
                PulseIndicator(size: 8)
                Text("KERNEL: CONNECTED")
                    .font(.mono(12, weight: .bold))
                    .foregroundStyle(.neonGreen.opacity(0.6))
                    .tracking(2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            // ── CTA ────────────────────────────────────────
            Link(destination: URL(string: "https://github.com/Clauder-help-Clauder/Claude-MacAudit")!) {
                VStack(spacing: 4) {
                    Text("GITHUB LINK")
                        .font(.spectralDisplay(18, weight: .bold))
                        .tracking(5)
                        .foregroundStyle(Color(hex: "#032800"))
                    Text("CHECK UPDATA")
                        .font(.mono(9, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color(hex: "#032800").opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(LinearGradient.spectral)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
        }
        .frame(width: 300)
        .background(Color(hex: "#080809"))
    }

    @ViewBuilder
    private func navItem(_ screen: AppScreen, icon: String, label: String) -> some View {
        let isActive = vm.selectedScreen == screen
        Button {
            vm.selectedScreen = screen
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 24)
                Text(label.uppercased())
                    .font(.spectralDisplay(20, weight: isActive ? .bold : .medium))
                    .tracking(2)
                Spacer()
            }
            .foregroundStyle(isActive ? Color.neonGreen : Color(hex: "#6B8F62"))
            .padding(.vertical, 18)
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
            .background(isActive ? Color.neonGreen.opacity(0.06) : Color.clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isActive ? Color.neonGreen : Color.clear)
                    .frame(width: 2)
            }
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func proxyRuleNavItem() -> some View {
        let isActive = vm.selectedScreen == .proxyRule
        Button {
            vm.selectedScreen = .proxyRule
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 24)
                Text("PROXY RULES")
                    .font(.spectralDisplay(20, weight: isActive ? .bold : .medium))
                    .tracking(2)
                Spacer()
                Text("[WARN]")
                    .font(.mono(7, weight: .bold))
                    .foregroundStyle(Color(hex: "#FF4444"))
                    .tracking(0.5)
            }
            .foregroundStyle(isActive ? Color(hex: "#FF4444") : Color(hex: "#FF6666").opacity(0.8))
            .padding(.vertical, 18)
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .contentShape(Rectangle())
            .background(isActive ? Color(hex: "#FF4444").opacity(0.06) : Color.clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isActive ? Color(hex: "#FF4444") : Color.clear)
                    .frame(width: 2)
            }
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Top Bar

struct TopBar: View {
    let screen: AppScreen
    @Environment(AppViewModel.self) private var vm
    @State private var notifHovered = false
    @State private var termHovered  = false
    @State private var showNotifPanel = false

    private var pathString: String {
        switch screen {
        case .dashboard:    return "PATH: /ROOT/MACAUDIT/DASHBOARD"
        case .scanning:     return "PATH: /ROOT/MACAUDIT/SCAN_IN_PROGRESS"
        case .results:      return "PATH: /VOLUMES/MAC_HD/SYSTEM/SECURITY"
        case .detail:       return "PATH: /ROOT/AUDIT/REMEDIATION_PROTOCOL"
        case .history:      return "PATH: /ROOT/AUDIT/HISTORY_LOG"
        case .proxyRule:    return "PATH: /ROOT/MACAUDIT/PROXY_RULES"
        case .settings:     return "PATH: /ROOT/MACAUDIT/CONFIG"
        }
    }

    var body: some View {
        HStack {
            // Left: pulse + path
            HStack(spacing: 10) {
                PulseIndicator(size: 7)
                Text(pathString)
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(Color(hex: "#3C4B35"))
                    .tracking(2)
            }

            Spacer()

            // Right: version + icons
            HStack(spacing: 20) {
                Text("MAC_AUDIT_TERMINAL.\(AppConstants.version)")
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(.neonGreen.opacity(0.5))
                    .tracking(2)

                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.3))
                    .frame(width: 1, height: 14)

                // Notifications
                Button {
                    showNotifPanel.toggle()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: vm.notificationsEnabled
                            ? (vm.notificationCenter.unreadCount > 0 ? "bell.badge" : "bell")
                            : "bell.slash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(notifHovered ? Color.linkCyan : Color(hex: "#353437"))
                        if vm.notificationCenter.unreadCount > 0 && vm.notificationsEnabled {
                            Text("\(vm.notificationCenter.unreadCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.voidBase)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.neonGreen)
                                .clipShape(Capsule())
                                .offset(x: 6, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .onHover { notifHovered = $0 }
                .help("Notifications")
                .popover(isPresented: $showNotifPanel) {
                    NotificationPanel()
                }

                // Terminal → 打开系统 Terminal.app
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
                } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(termHovered ? Color.linkCyan : Color(hex: "#353437"))
                }
                .buttonStyle(.plain)
                .onHover { termHovered = $0 }
                .help("Open Terminal")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(Color.voidBase)
    }
}

// MARK: - Status Bar (bottom)

struct StatusBar: View {
    @Environment(AppViewModel.self) private var vm
    @State private var sessionStart = Date()
    @State private var ticker = 0

    private var sessionDuration: String {
        let mins = Int(-sessionStart.timeIntervalSinceNow / 60)
        if mins < 60 { return "\(mins)m" }
        return "\(mins/60)h \(mins%60)m"
    }

    var body: some View {
        HStack {
            // Left — SYSTEM HEALTH + DAEMON + SYNC
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    PulseIndicator(color: .neonGreen, size: 5)
                    Text("SYSTEM HEALTH: OPTIMAL")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(.neonGreen)
                        .tracking(2)
                }
                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.3))
                    .frame(width: 1, height: 12)
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.linkCyan)
                    Text("DAEMON: ACTIVE")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(.linkCyan)
                        .tracking(2)
                }
                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.3))
                    .frame(width: 1, height: 12)
                HStack(spacing: 5) {
                    PulseIndicator(color: .neonGreen, size: 4)
                    Text("SYNC_SECURED")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(.neonGreen.opacity(0.6))
                        .tracking(2)
                }
            }

            Spacer()

            // Right — LATENCY / SESSION / PID / VERSION
            HStack(spacing: 16) {
                Text("SCAN: \(vm.lastAuditDurationMs > 0 ? "\(vm.lastAuditDurationMs)ms" : "—")")
                    .font(.mono(9))
                    .foregroundStyle(Color(hex: "#353437"))
                Text("SESSION: \(sessionDuration)")
                    .font(.mono(9))
                    .foregroundStyle(Color(hex: "#353437"))
                    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in ticker += 1 }
                Text("LOC: 127.0.0.1")
                    .font(.mono(9))
                    .foregroundStyle(Color(hex: "#353437"))
                Text("SECURE SHELL v4.2")
                    .font(.mono(9))
                    .foregroundStyle(Color.neonGreen.opacity(0.5))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 26)
        .background(Color.surfaceDim)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#3C4B35").opacity(0.15))
                .frame(height: 1)
        }
    }
}

// MARK: - Content View (root)

struct ContentView: View {
    @State private var vm = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar
                SidebarView()

                // Ghost border divider — outline-variant/15
                Rectangle()
                    .fill(Color(hex: "#3C4B35").opacity(0.15))
                    .frame(width: 1)

                // Main
                VStack(spacing: 0) {
                    TopBar(screen: vm.selectedScreen)
                    Rectangle()
                        .fill(Color(hex: "#3C4B35").opacity(0.15))
                        .frame(height: 1)

                    Group {
                        switch vm.selectedScreen {
                        case .dashboard:      DashboardView()
                        case .scanning:       ScanningView()
                        case .results:        ResultsView()
                        case .detail(let id): DetailView(checkId: id)
                        case .history:        HistoryView()
                        case .proxyRule:      ProxyRuleView()
                        case .settings:       SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.18), value: vm.selectedScreen)
                }
                .background(Color.voidBase)
            }

            // ── Status Bar ──────────────────────────────────────
            StatusBar()
        }
        .environment(vm)
        .background(Color.voidBase)
        .onAppear { vm.logAppLaunch(); vm.loadSavedSnapshot() }
        // Cmd+R → start audit from anywhere
        .keyboardShortcut("r", modifiers: .command)
        .onKeyPress(.init("r"), phases: .down) { _ in
            Task { await vm.startAudit() }
            return .handled
        }
    }
}

// MARK: - Notification Panel

struct NotificationPanel: View {
    @Environment(AppViewModel.self) private var vm

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NOTIFICATIONS")
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(.neonGreen)
                    .tracking(2)
                Spacer()
                if !vm.notificationCenter.notifications.isEmpty {
                    Button("Clear All") {
                        vm.notificationCenter.clearAll()
                    }
                    .font(.mono(9))
                    .foregroundStyle(.linkCyan)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if vm.notificationCenter.notifications.isEmpty {
                Text("No notifications")
                    .font(.mono(10))
                    .foregroundStyle(Color(hex: "#353437"))
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.notificationCenter.notifications) { notif in
                            NotificationRow(notification: notif)
                                .onTapGesture {
                                    vm.notificationCenter.markRead(id: notif.id)
                                }
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 280)
        .background(Color.voidBase)
    }
}

struct NotificationRow: View {
    @Environment(AppViewModel.self) private var vm
    let notification: AuditNotification

    private var severityColor: Color {
        switch notification.severity {
        case .info: return .neonGreen
        case .warning: return .linkCyan
        case .critical: return Color(hex: "#FF4444")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(notification.isRead ? Color.clear : severityColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(Color(hex: notification.isRead ? "#353437" : "#E0E0E0"))
                Text(notification.body)
                    .font(.mono(9))
                    .foregroundStyle(Color(hex: "#6B8F62"))
            }

            Spacer()

            Button {
                vm.notificationCenter.dismiss(id: notification.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: "#353437"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(notification.isRead ? Color.clear : Color.neonGreen.opacity(0.03))
    }
}

// MARK: - Preview

#if canImport(PreviewsMacros)
@_spi(Experimental) import PreviewsMacros
#Preview("MacAudit App") {
    ContentView()
        .frame(width: 1200, height: 760)
}
#endif
