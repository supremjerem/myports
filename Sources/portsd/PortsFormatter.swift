import Foundation
import PortsKit

/// Renders `ListeningPort` values for the terminal.
enum PortsFormatter {
    static func table(_ ports: [ListeningPort]) -> String {
        guard !ports.isEmpty else { return "No listening TCP ports found." }

        let header = ["PORT", "PID", "USER", "NAME", "ADDRESS", "CONNS"]
        let rows = ports.map { port in
            [
                String(port.address.port),
                String(port.process.pid),
                port.process.user,
                port.process.friendlyName,
                displayAddress(port.address),
                String(port.establishedConnections.count),
            ]
        }

        let widths = header.indices.map { column in
            ([header] + rows).map { $0[column].count }.max() ?? 0
        }

        func format(_ cells: [String]) -> String {
            cells.indices
                .map { cells[$0].padding(toLength: widths[$0], withPad: " ", startingAt: 0) }
                .joined(separator: "  ")
                .trimmingTrailingSpaces()
        }

        return ([format(header)] + rows.map(format)).joined(separator: "\n")
    }

    static func json(_ ports: [ListeningPort]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(ports), as: UTF8.self)
    }

    private static func displayAddress(_ address: SocketAddress) -> String {
        let host = address.isWildcardHost ? "*" : address.host
        return "\(host):\(address.port)"
    }
}

extension String {
    fileprivate func trimmingTrailingSpaces() -> String {
        var result = self
        while result.last == " " { result.removeLast() }
        return result
    }
}
