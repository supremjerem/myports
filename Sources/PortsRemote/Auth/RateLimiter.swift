import Foundation

/// A fixed-window rate limiter keyed by an arbitrary string (here, a token id).
/// In-memory: state resets when the agent restarts, which is acceptable for a
/// single-process dev tool.
public actor RateLimiter {
    private let limit: Int
    private let window: TimeInterval
    private var hits: [String: [Date]] = [:]

    public init(limit: Int, window: TimeInterval = 60) {
        self.limit = max(1, limit)
        self.window = window
    }

    /// Records an attempt for `key`. Returns `true` if it is within the limit.
    public func allow(_ key: String, now: Date = Date()) -> Bool {
        let cutoff = now.addingTimeInterval(-window)
        var recent = (hits[key] ?? []).filter { $0 > cutoff }
        guard recent.count < limit else {
            hits[key] = recent
            return false
        }
        recent.append(now)
        hits[key] = recent
        return true
    }
}
