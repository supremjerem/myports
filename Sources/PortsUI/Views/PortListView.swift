import PortsKit
import SwiftUI

/// The scrolling list of listening ports, with empty and error states.
struct PortListView: View {
    @Bindable var model: PortsViewModel

    var body: some View {
        Group {
            if let error = model.lastErrorMessage {
                message(error, systemImage: "exclamationmark.triangle", tint: .orange)
            } else if !model.hasLoadedOnce {
                message("Scanning ports…", systemImage: "magnifyingglass", tint: .secondary)
            } else if model.visiblePorts.isEmpty {
                message(emptyText, systemImage: "cable.connector", tint: .secondary)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.visiblePorts) { port in
                            PortRowView(port: port, model: model)
                            if port.id != model.visiblePorts.last?.id {
                                Divider().padding(.leading, 38)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyText: String {
        model.searchText.isEmpty && !model.showLoopbackOnly
            ? "No listening TCP ports."
            : "No ports match the current filter."
    }

    private func message(_ text: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(tint)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
