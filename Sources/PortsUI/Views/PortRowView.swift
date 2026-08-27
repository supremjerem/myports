import PortsKit
import SwiftUI

/// One listening port: summary line, expandable detail, and the kill control
/// with its SIGTERM → SIGKILL → administrator escalation.
struct PortRowView: View {
    let port: ListeningPort
    @Bindable var model: PortsViewModel

    @State private var isExpanded = false
    @State private var isHovering = false

    private var phase: KillPhase { model.phase(for: port) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            summary
            if !phase.isIdleOrConfirming {
                killStatus
            }
            if isExpanded {
                ProcessDetailView(port: port)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isHovering ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onHover { isHovering = $0 }
        .confirmationDialog(
            "Kill \(port.process.friendlyName) on port \(port.address.port)?",
            isPresented: confirmingBinding,
            titleVisibility: .visible
        ) {
            Button("Kill (SIGTERM, then SIGKILL)", role: .destructive) {
                Task { await model.confirmKill(port) }
            }
            Button("Cancel", role: .cancel) { model.cancelConfirmation(for: port) }
        } message: {
            Text("PID \(String(port.process.pid)) · \(port.process.command)")
        }
    }

    // MARK: Summary line

    private var summary: some View {
        HStack(spacing: 10) {
            Image(systemName: port.process.category.symbolName)
                .foregroundStyle(port.process.category.tint)
                .frame(width: 20)

            Button {
                withAnimation(.snappy(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(String(port.address.port))
                        .font(.body.weight(.semibold).monospacedDigit())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(port.process.friendlyName)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text("PID \(String(port.process.pid))")
                            Text(addressLabel)
                            if !port.establishedConnections.isEmpty {
                                Label(
                                    String(port.establishedConnections.count),
                                    systemImage: "arrow.left.arrow.right")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            killButton
                .opacity(isHovering || phase != .idle ? 1 : 0.5)
        }
    }

    private var addressLabel: String {
        let host = port.address.isWildcardHost ? "all interfaces" : port.address.host
        return port.address.isLoopback ? "loopback" : host
    }

    // MARK: Kill control

    @ViewBuilder
    private var killButton: some View {
        switch phase {
        case .working:
            ProgressView().controlSize(.small)
        case .needsAdministrator:
            Button("Kill as Admin") { Task { await model.killAsAdministrator(port) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
        default:
            Button(role: .destructive) {
                model.beginConfirmation(for: port)
            } label: {
                Image(systemName: "xmark.octagon.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHovering ? Color.red : Color.secondary)
            .help("Kill the process on this port")
        }
    }

    @ViewBuilder
    private var killStatus: some View {
        switch phase {
        case .succeeded:
            statusLabel("Killed.", systemImage: "checkmark.circle.fill", tint: .green)
        case .cancelled:
            statusLabel("Cancelled.", systemImage: "xmark.circle", tint: .secondary)
        case .needsAdministrator:
            statusLabel(
                "This process isn't yours — try again as an administrator.",
                systemImage: "lock.shield", tint: .orange)
        case .failed(let message):
            statusLabel(message, systemImage: "exclamationmark.triangle.fill", tint: .red)
        default:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text)
            Spacer(minLength: 0)
            if phase.isTerminal {
                Button("Dismiss") { model.dismissKillResult(for: port) }
                    .buttonStyle(.link)
            }
        }
        .font(.caption)
        .padding(.leading, 30)
    }

    private var confirmingBinding: Binding<Bool> {
        Binding(
            get: { model.phase(for: port) == .confirming },
            set: { showing in
                if !showing, model.phase(for: port) == .confirming {
                    model.cancelConfirmation(for: port)
                }
            }
        )
    }
}

extension KillPhase {
    fileprivate var isIdleOrConfirming: Bool {
        self == .idle || self == .confirming
    }
}
