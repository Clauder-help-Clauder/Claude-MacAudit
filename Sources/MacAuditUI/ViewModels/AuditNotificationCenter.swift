// AuditNotificationCenter.swift — 审计通知系统，管理检测结果的实时通知推送和未读状态
import Foundation

public struct AuditNotification: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let severity: Severity
    public let timestamp: Date
    public var isRead: Bool

    public enum Severity: String, Sendable {
        case info
        case warning
        case critical
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        severity: Severity,
        timestamp: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.severity = severity
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

@MainActor
@Observable
public final class AuditNotificationCenter {
    public var notifications: [AuditNotification] = [] {
        didSet {
            _unreadCount = notifications.filter { !$0.isRead }.count
        }
    }
    public static let maxNotifications = 50

    private var _unreadCount: Int = 0
    public var unreadCount: Int { _unreadCount }

    public init() {}

    public func add(title: String, body: String, severity: AuditNotification.Severity) {
        let notif = AuditNotification(
            title: title,
            body: body,
            severity: severity
        )
        notifications.insert(notif, at: 0)
        if notifications.count > Self.maxNotifications {
            notifications.removeLast(notifications.count - Self.maxNotifications)
        }
    }

    public func markRead(id: String) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
            _unreadCount = notifications.filter { !$0.isRead }.count
        }
    }

    public func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        _unreadCount = 0
    }

    public func dismiss(id: String) {
        notifications.removeAll { $0.id == id }
    }

    public func clearAll() {
        notifications.removeAll()
    }
}
