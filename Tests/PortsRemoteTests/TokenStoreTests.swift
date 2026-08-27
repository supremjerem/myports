import Foundation
import Testing

@testable import PortsRemote

@Suite("FileTokenStore")
struct TokenStoreTests {
    private func makeStore() -> (FileTokenStore, URL) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tok-\(UUID().uuidString).json")
        return (FileTokenStore(fileURL: url), url)
    }

    @Test("create returns a secret that verifies, and is stored only as a hash")
    func createAndVerify() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let (secret, record) = try await store.create(label: "my phone")
        #expect(record.label == "my phone")

        let verified = await store.verify(secret: secret)
        #expect(verified?.id == record.id)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(!onDisk.contains(secret))
        #expect(onDisk.contains(record.sha256Hex))
    }

    @Test("a wrong secret does not verify")
    func wrongSecret() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try await store.create(label: "a")
        #expect(await store.verify(secret: "wrong") == nil)
    }

    @Test("revoke removes the token")
    func revoke() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let (secret, record) = try await store.create(label: "a")
        try await store.revoke(id: record.id)

        #expect(await store.verify(secret: secret) == nil)
        #expect(try await store.allRecords().isEmpty)
    }

    @Test("revoking an unknown id throws")
    func revokeUnknown() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: TokenStoreError.self) {
            try await store.revoke(id: "nope")
        }
    }

    @Test("verify updates lastUsedAt")
    func lastUsed() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let (secret, _) = try await store.create(label: "a")
        #expect(try await store.allRecords().first?.lastUsedAt == nil)
        _ = await store.verify(secret: secret)
        #expect(try await store.allRecords().first?.lastUsedAt != nil)
    }
}

@Suite("RateLimiter")
struct RateLimiterTests {
    @Test("allows up to the limit within the window, then blocks")
    func windowing() async {
        let limiter = RateLimiter(limit: 3, window: 60)
        let now = Date()
        #expect(await limiter.allow("k", now: now))
        #expect(await limiter.allow("k", now: now))
        #expect(await limiter.allow("k", now: now))
        #expect(await limiter.allow("k", now: now) == false)
    }

    @Test("separate keys have separate budgets")
    func perKey() async {
        let limiter = RateLimiter(limit: 1, window: 60)
        #expect(await limiter.allow("a"))
        #expect(await limiter.allow("b"))
        #expect(await limiter.allow("a") == false)
    }

    @Test("a hit outside the window no longer counts")
    func expiry() async {
        let limiter = RateLimiter(limit: 1, window: 60)
        let start = Date()
        #expect(await limiter.allow("k", now: start))
        #expect(await limiter.allow("k", now: start.addingTimeInterval(30)) == false)
        #expect(await limiter.allow("k", now: start.addingTimeInterval(61)))
    }
}
