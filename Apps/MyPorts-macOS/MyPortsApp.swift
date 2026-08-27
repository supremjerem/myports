import AppKit
import PortsKit
import PortsUI
import SwiftUI

@main
struct MyPortsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @AppStorage(SettingsKey.refreshSeconds) private var refreshSeconds = 2.0
    @AppStorage(SettingsKey.loopbackOnly) private var loopbackOnly = false

    @State private var model = PortsViewModel()

    var body: some Scene {
        MenuBarExtra("MyPorts", systemImage: "network") {
            PortsRootView(
                model: model,
                onOpenSettings: openSettings,
                onQuit: { NSApp.terminate(nil) }
            )
            .task(id: refreshSeconds) {
                model.setPollInterval(.seconds(max(1, refreshSeconds)))
            }
            .task(id: loopbackOnly) {
                model.showLoopbackOnly = loopbackOnly
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

/// Keeps the app out of the Dock and the ⌘-Tab switcher; it lives in the menu
/// bar only. `LSUIElement` in Info.plist does the same, but setting the policy
/// here as well makes `swift run`-style launches behave too.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
