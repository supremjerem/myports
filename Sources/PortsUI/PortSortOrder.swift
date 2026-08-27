import Foundation
import PortsKit

/// How the port list is ordered in the UI.
public enum PortSortOrder: String, CaseIterable, Sendable, Identifiable {
    case port
    case name
    case pid
    case connections

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .port: return "Port"
        case .name: return "Name"
        case .pid: return "PID"
        case .connections: return "Connections"
        }
    }

    func sort(_ ports: [ListeningPort]) -> [ListeningPort] {
        switch self {
        case .port:
            return ports.sorted {
                ($0.address.port, $0.process.friendlyName) < (
                    $1.address.port, $1.process.friendlyName
                )
            }
        case .name:
            return ports.sorted {
                ($0.process.friendlyName.localizedCaseInsensitiveCompare($1.process.friendlyName)
                    == .orderedAscending)
            }
        case .pid:
            return ports.sorted {
                ($0.process.pid, $0.address.port) < ($1.process.pid, $1.address.port)
            }
        case .connections:
            return ports.sorted {
                ($0.establishedConnections.count, $0.address.port)
                    > ($1.establishedConnections.count, $1.address.port)
            }
        }
    }
}
