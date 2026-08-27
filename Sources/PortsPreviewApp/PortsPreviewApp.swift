import PortsUI
import SwiftUI

/// A plain windowed host for `PortsRootView` with static sample data.
///
/// Run `swift run PortsPreviewApp` to iterate on the UI or to capture a
/// screenshot without going through the menu-bar item. Not shipped.
@main
struct PortsPreviewApp: App {
    @State private var model = PortsViewModel(previewPorts: PortsPreviewData.ports)

    var body: some Scene {
        Window("MyPorts — Preview", id: "preview") {
            PortsRootView(
                model: model,
                onOpenSettings: {},
                onQuit: {}
            )
            .frame(width: 380, height: 560)
        }
        .defaultSize(width: 380, height: 560)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
