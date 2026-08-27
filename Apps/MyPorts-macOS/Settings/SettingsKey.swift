import Foundation

/// `@AppStorage` keys, kept in one place so the App scene and the Settings view
/// cannot drift apart.
enum SettingsKey {
    static let refreshSeconds = "refreshSeconds"
    static let loopbackOnly = "loopbackOnly"
    static let launchAtLogin = "launchAtLogin"
}
