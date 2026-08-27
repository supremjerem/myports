import Foundation

/// Runtime configuration for the agent, resolved from explicit values, then
/// environment variables, then safe defaults (12-factor).
public struct RemoteConfig: Sendable {
    /// Interface to bind. `127.0.0.1` means this machine only.
    public var bindHost: String
    /// TCP port to listen on.
    public var port: Int
    /// When `true`, paired clients may read but every kill returns HTTP 403.
    public var readOnly: Bool
    /// Directory holding `tokens.json` and `audit.log`.
    public var dataDirectory: URL
    /// How often the SSE stream re-scans and pushes a snapshot.
    public var eventInterval: Duration
    /// Maximum kills accepted per token per rolling minute.
    public var killRateLimitPerMinute: Int
    /// Directory of built web assets to serve at `/`. `nil` disables the web UI.
    public var webRoot: URL?

    public static let apiVersion = 1

    public init(
        bindHost: String = "127.0.0.1",
        port: Int = 7333,
        readOnly: Bool = false,
        dataDirectory: URL = RemoteConfig.defaultDataDirectory,
        eventInterval: Duration = .seconds(2),
        killRateLimitPerMinute: Int = 10,
        webRoot: URL? = nil
    ) {
        self.bindHost = bindHost
        self.port = port
        self.readOnly = readOnly
        self.dataDirectory = dataDirectory
        self.eventInterval = eventInterval
        self.killRateLimitPerMinute = killRateLimitPerMinute
        self.webRoot = webRoot
    }

    /// `~/Library/Application Support/MyPorts`, or `$MYPORTS_DATA_DIR`.
    public static var defaultDataDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["MYPORTS_DATA_DIR"], !override.isEmpty
        {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("MyPorts", isDirectory: true)
    }

    /// Reads `MYPORTS_BIND`, `MYPORTS_PORT`, `MYPORTS_READONLY`, `MYPORTS_DATA_DIR`
    /// and overlays them on top of `self`.
    public func applyingEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RemoteConfig {
        var config = self
        if let bind = environment["MYPORTS_BIND"], !bind.isEmpty { config.bindHost = bind }
        if let portString = environment["MYPORTS_PORT"], let port = Int(portString) {
            config.port = port
        }
        if let readOnly = environment["MYPORTS_READONLY"] {
            config.readOnly = ["1", "true", "yes"].contains(readOnly.lowercased())
        }
        if let dir = environment["MYPORTS_DATA_DIR"], !dir.isEmpty {
            config.dataDirectory = URL(fileURLWithPath: dir, isDirectory: true)
        }
        if let web = environment["MYPORTS_WEB_ROOT"], !web.isEmpty {
            config.webRoot = URL(fileURLWithPath: web, isDirectory: true)
        }
        return config
    }

    /// `true` when `bindHost` is a loopback address.
    public var bindsLoopbackOnly: Bool {
        bindHost == "127.0.0.1" || bindHost == "::1" || bindHost == "localhost"
    }

    public var tokensFileURL: URL { dataDirectory.appendingPathComponent("tokens.json") }
    public var auditLogURL: URL { dataDirectory.appendingPathComponent("audit.log") }
}
