import PortsKit
import SwiftUI

#if canImport(AppKit)
    import AppKit
#endif

/// The expanded detail for a port row: process metadata plus quick actions.
struct ProcessDetailView: View {
    let port: ListeningPort

    private var process: PortProcess { port.process }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("Command", process.command)
            if let path = process.executablePath {
                detailRow("Path", path, monospaced: true)
            }
            if !process.arguments.isEmpty {
                detailRow("Arguments", process.arguments.joined(separator: " "), monospaced: true)
            }
            detailRow("User", process.user)
            if let parent = process.parentPID {
                detailRow("Parent PID", String(parent))
            }
            if let started = process.startDate {
                detailRow("Started", started.formatted(.relative(presentation: .named)))
            }

            Divider()

            Text("Connections (\(port.establishedConnections.count))")
                .font(.callout.weight(.semibold))
            ConnectionListView(connections: port.establishedConnections)

            HStack(spacing: 10) {
                Button("Copy PID") { copyToPasteboard(String(process.pid)) }
                if let path = process.executablePath {
                    Button("Reveal in Finder") { revealInFinder(path) }
                }
            }
            .buttonStyle(.link)
            .font(.callout)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View
    {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func copyToPasteboard(_ string: String) {
        #if canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private func revealInFinder(_ path: String) {
        #if canImport(AppKit)
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        #endif
    }
}
