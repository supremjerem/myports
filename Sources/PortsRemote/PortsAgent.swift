import Foundation
import Hummingbird
import Logging
import PortsKit

/// Builds and runs the HTTP+JSON agent over `PortsKit`.
///
/// Phase 3a: loopback only, bearer-token auth, optional read-only mode, kill
/// rate-limiting and an audit log. TLS, Bonjour and QR pairing arrive in 3b.
public struct PortsAgent: Sendable {
    public let config: RemoteConfig
    private let service: PortsService
    private let tokenStore: any TokenStoring
    private let audit: any AuditLogging
    private let logger: Logger

    public init(
        config: RemoteConfig,
        service: PortsService = PortsService(),
        tokenStore: (any TokenStoring)? = nil,
        audit: (any AuditLogging)? = nil,
        logger: Logger = Logger(label: "myports.agent")
    ) {
        self.config = config
        self.service = service
        self.tokenStore = tokenStore ?? FileTokenStore(fileURL: config.tokensFileURL)
        self.audit = audit ?? FileAuditLog(fileURL: config.auditLogURL)
        self.logger = logger
    }

    /// Builds the router (exposed for tests via `HummingbirdTesting`).
    public func buildRouter() -> Router<AgentRequestContext> {
        let router = Router(context: AgentRequestContext.self)
        router.add(middleware: LogRequestsMiddleware(.info))

        let device = DeviceController(config: config)
        router.get("api/v1/device", use: device.device)

        let authed = router.group("api/v1")
        authed.add(middleware: BearerAuthMiddleware(tokenStore: tokenStore))

        let ports = PortsController(
            service: service,
            config: config,
            rateLimiter: RateLimiter(limit: config.killRateLimitPerMinute),
            audit: audit
        )
        ports.addRoutes(to: authed)

        let events = EventsController(service: service, config: config)
        authed.get("events", use: events.events)

        return router
    }

    public func buildApplication() -> some ApplicationProtocol {
        Application(
            router: buildRouter(),
            configuration: .init(
                address: .hostname(config.bindHost, port: config.port),
                serverName: "MyPorts"
            ),
            logger: logger
        )
    }

    /// Runs until the process is signalled. Refuses a non-loopback bind until
    /// TLS + pairing land (Phase 3b).
    public func run() async throws {
        guard config.bindsLoopbackOnly else {
            throw AgentStartupError.lanExposureNotYetSupported
        }
        try await buildApplication().runService()
    }
}

public enum AgentStartupError: Error, CustomStringConvertible {
    case lanExposureNotYetSupported

    public var description: String {
        switch self {
        case .lanExposureNotYetSupported:
            return
                "Binding to a non-loopback address needs TLS and device pairing, "
                + "which are not implemented yet. Use --bind 127.0.0.1 for now."
        }
    }
}
