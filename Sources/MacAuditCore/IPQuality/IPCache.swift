import Foundation
import os

public final class IPCache: @unchecked Sendable {
    private var _cachedIPv4: String?
    private var _cachedIPv6: String?
    private var _cachedGeoIPResults: [AuditResult]?
    private var _lastFetchTime: Date?
    private var _geoFetchTime: Date?

    public static let shared = IPCache()
    public static let defaultTTL: TimeInterval = 300

    private let lock = OSAllocatedUnfairLock()

    public init() {}

    private func isValidUnlocked(ttl: TimeInterval) -> Bool {
        guard let _lastFetchTime else { return false }
        return Date().timeIntervalSince(_lastFetchTime) < ttl
    }

    private func expireIfNeededUnlocked() {
        if !isValidUnlocked(ttl: IPCache.defaultTTL) {
            _cachedIPv4 = nil
            _cachedIPv6 = nil
            _lastFetchTime = nil
        }
        if let geoTime = _geoFetchTime,
           Date().timeIntervalSince(geoTime) >= IPCache.defaultTTL {
            _cachedGeoIPResults = nil
            _geoFetchTime = nil
        }
    }

    public func store(ipv4: String? = nil, ipv6: String? = nil) {
        lock.withLock {
            if let ipv4 { _cachedIPv4 = ipv4 }
            if let ipv6 { _cachedIPv6 = ipv6 }
            _lastFetchTime = Date()
        }
    }

    public func store(geoIPResults: [AuditResult]) {
        lock.withLock {
            _cachedGeoIPResults = geoIPResults
            _geoFetchTime = Date()
        }
    }

    public func isValid(ttl: TimeInterval = IPCache.defaultTTL) -> Bool {
        lock.withLock { isValidUnlocked(ttl: ttl) }
    }

    public func invalidate() {
        lock.withLock {
            _cachedIPv4 = nil
            _cachedIPv6 = nil
            _cachedGeoIPResults = nil
            _lastFetchTime = nil
            _geoFetchTime = nil
        }
    }

    public func getIPv4() -> String? {
        lock.withLock {
            expireIfNeededUnlocked()
            return _cachedIPv4
        }
    }

    public func getIPv6() -> String? {
        lock.withLock {
            expireIfNeededUnlocked()
            return _cachedIPv6
        }
    }

    public var cachedIPv4: String? { getIPv4() }
    public var cachedIPv6: String? { getIPv6() }
    public var lastFetchTime: Date? {
        lock.withLock { _lastFetchTime }
    }
}
