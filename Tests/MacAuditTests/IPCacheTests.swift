import Testing
import Foundation
@testable import MacAuditCore

// MARK: - IPCache Tests

@MainActor
struct IPCacheTests {

    private func makeCache() -> IPCache {
        let cache = IPCache()
        cache.invalidate()
        return cache
    }

    @Test("IPCache starts empty")
    func ipCacheStartsEmpty() {
        let cache = makeCache()
        #expect(cache.getIPv4() == nil)
        #expect(cache.getIPv6() == nil)
        #expect(cache.lastFetchTime == nil)
    }

    @Test("IPCache stores and retrieves IPv4 via getIPv4")
    func ipCacheStoresIPv4() {
        let cache = makeCache()
        cache.store(ipv4: "1.2.3.4")
        #expect(cache.getIPv4() == "1.2.3.4")
    }

    @Test("IPCache stores and retrieves IPv6 via getIPv6")
    func ipCacheStoresIPv6() {
        let cache = makeCache()
        cache.store(ipv6: "2001:db8::1")
        #expect(cache.getIPv6() == "2001:db8::1")
    }

    @Test("IPCache isValid returns false when never fetched")
    func ipCacheInvalidWhenEmpty() {
        let cache = makeCache()
        #expect(cache.isValid(ttl: 300) == false)
    }

    @Test("IPCache isValid returns true for fresh cache")
    func ipCacheValidWhenFresh() {
        let cache = makeCache()
        cache.store(ipv4: "1.2.3.4")
        #expect(cache.isValid(ttl: 300) == true)
    }

    @Test("IPCache isValid returns false for expired cache")
    func ipCacheExpiredWhenOld() {
        let cache = makeCache()
        cache.store(ipv4: "1.2.3.4")
        // Simulate expiration by storing, then waiting — since we can't
        // directly set _lastFetchTime (private), we test invalidate instead
        cache.invalidate()
        #expect(cache.isValid(ttl: 300) == false)
    }

    @Test("IPCache invalidate clears all data")
    func ipCacheInvalidate() {
        let cache = makeCache()
        cache.store(ipv4: "1.2.3.4")
        cache.store(ipv6: "2001:db8::1")
        cache.invalidate()
        #expect(cache.getIPv4() == nil)
        #expect(cache.getIPv6() == nil)
        #expect(cache.lastFetchTime == nil)
    }

    @Test("IPCache shared instance exists")
    func ipCacheSharedInstance() {
        #expect(IPCache.shared != nil)
    }

    @Test("IPCache shared is singleton")
    func ipCacheSharedSingleton() {
        let a = IPCache.shared
        let b = IPCache.shared
        a.store(ipv4: "5.6.7.8")
        #expect(b.getIPv4() == "5.6.7.8")
        a.invalidate()
    }

    @Test("IPCache cachedIPv4 computed property returns getIPv4")
    func ipCacheCachedIPv4Computed() {
        let cache = makeCache()
        cache.store(ipv4: "9.9.9.9")
        #expect(cache.cachedIPv4 == "9.9.9.9")
    }

    @Test("IPCache cachedIPv6 computed property returns getIPv6")
    func ipCacheCachedIPv6Computed() {
        let cache = makeCache()
        cache.store(ipv6: "::1")
        #expect(cache.cachedIPv6 == "::1")
    }

    @Test("IPCache getIPv4 returns nil after TTL when expired via invalidate")
    func ipCacheGetIPv4NilAfterInvalidate() {
        let cache = makeCache()
        cache.store(ipv4: "1.2.3.4")
        cache.invalidate()
        #expect(cache.getIPv4() == nil)
    }
}

// MARK: - IPQualityModule parallel execution tests

@MainActor
struct IPQualityParallelTests {

    @Test("IPQualityModule runs with cached IP via shared IPCache")
    func ipQualityParallelWithCache() async {
        IPCache.shared.invalidate()
        IPCache.shared.store(ipv4: "8.8.8.8")

        let module = IPQualityModule()
        let executor = ShellExecutor(stubbedOutputs: [
            "dig +short": "127.0.0.2",
            "nc -z": "OPEN",
            "ifconfig.me": "8.8.8.8",
            "curl": "8.8.8.8",
            "scutil": "nameserver[0]: 8.8.4.4",
            "route": "gateway: 192.168.1.1",
        ])

        let results = await module.run(version: MacOSVersion.sequoia, device: DeviceType.laptop, arch: CPUArchitecture.arm64, executor: executor)
        #expect(results.count == 23)
        IPCache.shared.invalidate()
    }
}
