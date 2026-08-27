import PortsKit
import SwiftUI

/// The whole menu-bar popover: header, toolbar, port list, footer.
///
/// App-specific actions (open Settings, quit) are injected so this view stays
/// usable from previews and, later, the iOS app.
public struct PortsRootView: View {
    @Bindable private var model: PortsViewModel
    private let onOpenSettings: (() -> Void)?
    private let onQuit: (() -> Void)?

    public init(
        model: PortsViewModel,
        onOpenSettings: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil
    ) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            PortsToolbar(model: model)
                .padding(10)
            Divider()
            PortListView(model: model)
                .frame(minHeight: 220)
            Divider()
            footer
        }
        .frame(width: 380)
        .frame(maxHeight: 560)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .foregroundStyle(.tint)
            Text("MyPorts").font(.headline)
            Spacer()
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var summaryText: String {
        let ports = model.ports.count
        let conns = model.totalConnectionCount
        return "\(ports) port\(ports == 1 ? "" : "s") · \(conns) conn\(conns == 1 ? "" : "s")"
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let onOpenSettings {
                Button {
                    onOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            Spacer()
            if let onQuit {
                Button {
                    onQuit()
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
        }
        .buttonStyle(.plain)
        .labelStyle(.titleAndIcon)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
