import Darwin
import Foundation

/// The POSIX signal to deliver to a process.
public enum KillSignal: Sendable, Equatable {
    /// `SIGTERM` — a polite request to shut down.
    case terminate
    /// `SIGKILL` — unconditional, cannot be trapped.
    case kill

    var rawValue: Int32 {
        switch self {
        case .terminate: return SIGTERM
        case .kill: return SIGKILL
        }
    }
}

/// The outcome of trying to signal a process.
public enum KillOutcome: Sendable, Equatable {
    /// The signal was delivered.
    case signalled
    /// No process with that pid exists (`ESRCH`) — treat as "already gone".
    case processNotFound
    /// The caller lacks permission (`EPERM`) — a privileged retry may succeed.
    case permissionDenied
    /// The user dismissed the macOS authorization prompt.
    case cancelledByUser
    /// Any other failure, carrying the raw `errno`.
    case failed(errno: Int32)
}

/// Sends signals to processes. Injected so tests can observe calls without
/// actually killing anything.
public protocol Signaler: Sendable {
    /// Delivers `signal` to `pid`.
    func send(_ signal: KillSignal, to pid: Int32) -> KillOutcome
    /// Sends signal `0`, which performs the permission/existence check without
    /// delivering anything.
    func probe(pid: Int32) -> KillOutcome
}

/// Calls `Darwin.kill(2)` directly — no subprocess.
public struct SystemSignaler: Signaler {
    public init() {}

    public func send(_ signal: KillSignal, to pid: Int32) -> KillOutcome {
        deliver(signal.rawValue, to: pid)
    }

    public func probe(pid: Int32) -> KillOutcome {
        deliver(0, to: pid)
    }

    private func deliver(_ signal: Int32, to pid: Int32) -> KillOutcome {
        guard pid > 0 else { return .failed(errno: EINVAL) }
        if kill(pid, signal) == 0 { return .signalled }
        switch errno {
        case ESRCH: return .processNotFound
        case EPERM: return .permissionDenied
        default: return .failed(errno: errno)
        }
    }
}
