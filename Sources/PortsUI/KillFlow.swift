import Foundation
import PortsKit

/// The state of an in-progress or finished kill for one port row.
public enum KillPhase: Equatable, Sendable {
    /// Nothing has happened yet.
    case idle
    /// A confirmation prompt is showing.
    case confirming
    /// A signal is being delivered.
    case working
    /// The process is gone.
    case succeeded
    /// The process is not ours; offer an administrator retry.
    case needsAdministrator
    /// The administrator prompt was dismissed.
    case cancelled
    /// It failed for another reason.
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .succeeded, .cancelled, .failed: return true
        default: return false
        }
    }
}

extension KillOutcome {
    /// Maps a raw kill outcome to the next UI phase.
    func toPhase() -> KillPhase {
        switch self {
        case .signalled, .processNotFound: return .succeeded
        case .permissionDenied: return .needsAdministrator
        case .cancelledByUser: return .cancelled
        case .failed(let code): return .failed("Failed (errno \(code)).")
        }
    }
}
