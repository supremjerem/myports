import Foundation

/// The delta between two port snapshots, keyed by ``ListeningPort/id``.
public struct PortsDiff: Sendable, Equatable {
    public let added: [ListeningPort]
    public let removed: [ListeningPort]
    /// Ports present in both snapshots whose value changed (for example a new
    /// established connection or a different owning process).
    public let changed: [ListeningPort]

    public var isEmpty: Bool {
        added.isEmpty && removed.isEmpty && changed.isEmpty
    }

    public static func between(
        old: [ListeningPort], new: [ListeningPort]
    ) -> PortsDiff {
        let oldByID = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })

        let added = new.filter { oldByID[$0.id] == nil }
        let removed = old.filter { newByID[$0.id] == nil }
        let changed = new.filter { candidate in
            guard let previous = oldByID[candidate.id] else { return false }
            return previous != candidate
        }
        return PortsDiff(added: added, removed: removed, changed: changed)
    }
}
