import Foundation

/// Issues short-lived, single-use pairing tokens. A client scans a QR carrying
/// one, then exchanges it (`POST /api/v1/pair`) for a long-lived bearer token.
///
/// In-memory: pending pairings do not survive an agent restart, which is fine —
/// the user just shows a fresh QR.
public actor PairingBroker {
    private struct Pending {
        let token: String
        let expiresAt: Date
    }

    private var pending: [String: Pending] = [:]
    private let ttl: TimeInterval

    public init(ttl: TimeInterval = 600) {
        self.ttl = ttl
    }

    /// Creates a pairing token valid for `ttl` seconds.
    public func issue(now: Date = Date()) -> String {
        prune(now: now)
        let token = FileTokenStore.makeSecret()
        pending[token] = Pending(token: token, expiresAt: now.addingTimeInterval(ttl))
        return token
    }

    /// Consumes a pairing token. Returns `true` exactly once per valid token.
    public func redeem(_ token: String, now: Date = Date()) -> Bool {
        prune(now: now)
        guard let entry = pending.removeValue(forKey: token), entry.expiresAt > now else {
            return false
        }
        return true
    }

    public func pendingCount(now: Date = Date()) -> Int {
        prune(now: now)
        return pending.count
    }

    private func prune(now: Date) {
        pending = pending.filter { $0.value.expiresAt > now }
    }
}
