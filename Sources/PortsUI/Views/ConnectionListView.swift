import PortsKit
import SwiftUI

/// The established connections against one listening port.
struct ConnectionListView: View {
    let connections: [Connection]

    var body: some View {
        if connections.isEmpty {
            Text("No established connections.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(connections.enumerated()), id: \.offset) { _, connection in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(endpoint(connection.remoteAddress))
                            .font(.system(.callout, design: .monospaced))
                        Spacer()
                        Text(connection.state.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func endpoint(_ address: SocketAddress?) -> String {
        guard let address else { return "unknown" }
        return "\(address.host):\(address.port)"
    }
}
