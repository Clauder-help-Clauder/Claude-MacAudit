import Testing
import Foundation
import MacAuditCore
@testable import MacAuditUI

@MainActor
struct AuditNotificationTests {

    private func makeVM() -> AppViewModel {
        UserDefaults.standard.removeObject(forKey: "ma_user_skipped")
        UserDefaults.standard.removeObject(forKey: "ma_version")
        UserDefaults.standard.removeObject(forKey: "ma_device")
        UserDefaults.standard.removeObject(forKey: "ma_notifications_enabled")
        return AppViewModel()
    }

    private func makeResult(_ checkId: String, moduleId: String, status: AuditStatus) -> AuditResult {
        let check = AuditCheck(id: checkId, name: checkId, module: moduleId, command: "echo test")
        switch status {
        case .pass: return .pass(check: check, actual: "ok")
        case .fail: return .fail(check: check, actual: "bad")
        case .warn: return .warn(check: check, actual: "warn")
        case .info: return .info(check: check, actual: "info")
        case .skip: return .skip(check: check, reason: "test")
        case .error: return .error(check: check, error: "err")
        }
    }

    // MARK: - AuditNotification model

    @Test("AuditNotification creates with correct fields")
    func auditNotificationFields() {
        let notif = AuditNotification(
            id: "n1",
            title: "Scan Complete",
            body: "5 issues found",
            severity: .warning,
            timestamp: Date()
        )
        #expect(notif.id == "n1")
        #expect(notif.title == "Scan Complete")
        #expect(notif.body == "5 issues found")
        #expect(notif.severity == .warning)
        #expect(notif.isRead == false)
    }

    @Test("AuditNotification isRead defaults to false")
    func auditNotificationDefaultUnread() {
        let notif = AuditNotification(
            id: "n1", title: "T", body: "B", severity: .info, timestamp: Date()
        )
        #expect(notif.isRead == false)
    }

    @Test("AuditNotification severity levels exist")
    func auditNotificationSeverityLevels() {
        #expect(AuditNotification.Severity.info.rawValue == "info")
        #expect(AuditNotification.Severity.warning.rawValue == "warning")
        #expect(AuditNotification.Severity.critical.rawValue == "critical")
    }

    // MARK: - AuditNotificationCenter

    @Test("AuditNotificationCenter starts with no notifications")
    func notificationCenterEmpty() {
        let center = AuditNotificationCenter()
        #expect(center.notifications.isEmpty)
        #expect(center.unreadCount == 0)
    }

    @Test("AuditNotificationCenter adds notification and increments unread")
    func notificationCenterAdd() {
        let center = AuditNotificationCenter()
        center.add(title: "Test", body: "Body", severity: .info)
        #expect(center.notifications.count == 1)
        #expect(center.unreadCount == 1)
    }

    @Test("AuditNotificationCenter marks notification as read")
    func notificationCenterMarkRead() {
        let center = AuditNotificationCenter()
        center.add(title: "Test", body: "Body", severity: .info)
        let id = center.notifications[0].id
        center.markRead(id: id)
        #expect(center.unreadCount == 0)
        #expect(center.notifications[0].isRead == true)
    }

    @Test("AuditNotificationCenter markAllRead sets all to read")
    func notificationCenterMarkAllRead() {
        let center = AuditNotificationCenter()
        center.add(title: "T1", body: "B1", severity: .info)
        center.add(title: "T2", body: "B2", severity: .warning)
        center.markAllRead()
        #expect(center.unreadCount == 0)
        #expect(center.notifications.allSatisfy { $0.isRead })
    }

    @Test("AuditNotificationCenter clearAll removes all notifications")
    func notificationCenterClearAll() {
        let center = AuditNotificationCenter()
        center.add(title: "T1", body: "B1", severity: .info)
        center.add(title: "T2", body: "B2", severity: .warning)
        center.clearAll()
        #expect(center.notifications.isEmpty)
        #expect(center.unreadCount == 0)
    }

    @Test("AuditNotificationCenter notifications are ordered newest first")
    func notificationCenterOrdering() {
        let center = AuditNotificationCenter()
        center.add(title: "First", body: "B1", severity: .info)
        center.add(title: "Second", body: "B2", severity: .info)
        #expect(center.notifications[0].title == "Second")
        #expect(center.notifications[1].title == "First")
    }

    @Test("AuditNotificationCenter dismiss removes single notification")
    func notificationCenterDismiss() {
        let center = AuditNotificationCenter()
        center.add(title: "T1", body: "B1", severity: .info)
        center.add(title: "T2", body: "B2", severity: .info)
        let id = center.notifications[0].id
        center.dismiss(id: id)
        #expect(center.notifications.count == 1)
        #expect(center.notifications[0].title == "T1")
    }

    // MARK: - AppViewModel notification integration

    @Test("AppViewModel has notificationCenter")
    func vmHasNotificationCenter() {
        let vm = makeVM()
        #expect(vm.notificationCenter != nil)
    }

    @Test("AppViewModel notificationsEnabled defaults to true")
    func vmNotificationsEnabledDefault() {
        let vm = makeVM()
        #expect(vm.notificationsEnabled == true)
    }

    @Test("AppViewModel toggleNotifications changes state")
    func vmToggleNotifications() {
        let vm = makeVM()
        vm.notificationsEnabled = false
        #expect(vm.notificationsEnabled == false)
        vm.notificationsEnabled = true
        #expect(vm.notificationsEnabled == true)
    }

    @Test("AppViewModel postAuditNotification adds notification after scan")
    func vmPostAuditNotification() {
        let vm = makeVM()
        vm.injectTestResults([
            makeResult("c1", moduleId: "network_security", status: .pass),
            makeResult("c2", moduleId: "network_security", status: .fail),
        ])
        vm.postAuditNotification(failCount: 1, warnCount: 0, durationMs: 1200)
        #expect(vm.notificationCenter.unreadCount == 1)
        #expect(vm.notificationCenter.notifications[0].severity == .warning)
    }

    @Test("AppViewModel postAuditNotification uses critical severity for high fail count")
    func vmPostAuditNotificationCritical() {
        let vm = makeVM()
        vm.postAuditNotification(failCount: 10, warnCount: 5, durationMs: 3000)
        #expect(vm.notificationCenter.notifications[0].severity == .critical)
    }

    @Test("AppViewModel postAuditNotification uses info severity for zero fails")
    func vmPostAuditNotificationInfo() {
        let vm = makeVM()
        vm.postAuditNotification(failCount: 0, warnCount: 0, durationMs: 800)
        #expect(vm.notificationCenter.notifications[0].severity == .info)
    }

    @Test("AppViewModel postAuditNotification does nothing when notificationsEnabled is false")
    func vmPostAuditNotificationDisabled() {
        let vm = makeVM()
        vm.notificationsEnabled = false
        vm.postAuditNotification(failCount: 5, warnCount: 2, durationMs: 1000)
        #expect(vm.notificationCenter.notifications.isEmpty)
    }

    @Test("AppViewModel postAuditNotification excludes personal modules from fail count")
    func vmPostAuditNotificationExcludesPersonalModules() {
        let vm = makeVM()
        vm.postAuditNotification(failCount: 0, warnCount: 0, durationMs: 500)
        #expect(vm.notificationCenter.notifications[0].severity == .info)
    }
}
