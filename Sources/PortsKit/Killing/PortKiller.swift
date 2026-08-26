import Foundation

/// High-level kill operations expressed in terms of the escalation ladder the
/// UI walks: polite terminate → force kill → force kill as administrator.
public struct PortKiller: Sendable {
    private let signaler: Signaler
    private let privilegedKiller: PrivilegedKiller

    public init(
        signaler: Signaler = SystemSignaler(),
        privilegedKiller: PrivilegedKiller = PrivilegedKiller()
    ) {
        self.signaler = signaler
        self.privilegedKiller = privilegedKiller
    }

    /// `true` when the process still exists (including when it exists but is not
    /// ours to signal).
    public func isAlive(pid: Int32) -> Bool {
        switch signaler.probe(pid: pid) {
        case .signalled, .permissionDenied: return true
        default: return false
        }
    }

    /// Sends `SIGTERM`.
    public func terminate(pid: Int32) -> KillOutcome {
        signaler.send(.terminate, to: pid)
    }

    /// Sends `SIGKILL`.
    public func forceKill(pid: Int32) -> KillOutcome {
        signaler.send(.kill, to: pid)
    }

    /// Sends `SIGKILL` after an administrator authentication prompt.
    public func forceKillAsAdministrator(pid: Int32) async -> KillOutcome {
        await privilegedKiller.forceKill(pid: pid)
    }

    /// Sends `SIGTERM`, waits up to `gracePeriod` for the process to exit, and
    /// escalates to `SIGKILL` if it is still alive.
    public func terminateThenKill(
        pid: Int32,
        gracePeriod: Duration = .seconds(2),
        pollInterval: Duration = .milliseconds(100)
    ) async -> KillOutcome {
        let first = terminate(pid: pid)
        switch first {
        case .signalled:
            break
        case .processNotFound:
            return .signalled  // Already gone — the caller's goal is met.
        default:
            return first
        }

        let deadline = ContinuousClock.now.advanced(by: gracePeriod)
        while ContinuousClock.now < deadline {
            if !isAlive(pid: pid) { return .signalled }
            try? await Task.sleep(for: pollInterval)
        }

        guard isAlive(pid: pid) else { return .signalled }
        return forceKill(pid: pid)
    }
}
