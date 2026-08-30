import Foundation
import Hummingbird
import HummingbirdTLS
import Logging
import NIOSSL
import PortsKit

/// Builds and runs the HTTP+JSON agent over `PortsKit`.
///
/// Phase 3a: loopback, bearer-token auth, read-only mode, kill rate-limiting,
/// audit log. Phase 3b: self-signed TLS (always on), single-use pairing tokens
/// (`POST /api/v1/pair`), Bonjour advertising, and an opt-in LAN bind.
public struct PortsAgent: Sendable {
    public let config: RemoteConfig
    private let service: PortsService
    private let tokenStore: any TokenStoring
    private let audit: any AuditLogging
    private let broker: PairingBroker
    private let logger: Logger

    public init(
        config: RemoteConfig,
        service: PortsService = PortsService(),
        tokenStore: (any TokenStoring)? = nil,
        audit: (any AuditLogging)? = nil,
        broker: PairingBroker = PairingBroker(),
        logger: Logger = Logger(label: "myports.agent")
    ) {
        self.config = config
        self.service = service
        self.tokenStore = tokenStore ?? FileTokenStore(fileURL: config.tokensFileURL)
        self.audit = audit ?? FileAuditLog(fileURL: config.auditLogURL)
        self.broker = broker
        self.logger = logger
    }

    /// Builds the router (exposed for tests via `HummingbirdTesting`).
    public func buildRouter() -> Router<AgentRequestContext> {
        let router = Router(context: AgentRequestContext.self)
        router.add(middleware: LogRequestsMiddleware(.info))

        if let webRoot = config.webRoot {
            router.add(
                middleware: FileMiddleware(webRoot.path, searchForIndexHtml: true))
        }

        let device = DeviceController(config: config)
        router.get("api/v1/device", use: device.device)

        let pair = PairController(broker: broker, tokenStore: tokenStore, audit: audit)
        router.post("api/v1/pair", use: pair.pair)

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

    /// Loads or generates the TLS identity for this machine.
    public func resolveIdentity() throws -> SelfSignedIdentity {
        try IdentityStore.loadOrCreate(
            certificateURL: config.dataDirectory.appendingPathComponent("cert.pem"),
            keyURL: config.dataDirectory.appendingPathComponent("key.pem"),
            hostname: ProcessInfo.processInfo.hostName,
            ipAddresses: LocalNetwork.ipv4Addresses()
        )
    }

    /// A fresh pairing payload: a single-use token plus the pinning fingerprint.
    public func makePairingPayload(fingerprint: String) async -> PairingPayload {
        PairingPayload(
            host: advertisedHost,
            port: config.port,
            fingerprint: fingerprint,
            pairingToken: await broker.issue()
        )
    }

    /// The address a remote client should connect to: the bind host if it is a
    /// concrete address, otherwise this machine's mDNS name.
    public var advertisedHost: String {
        if config.bindHost == "0.0.0.0" || config.bindHost == "::" || config.bindsLoopbackOnly {
            return ProcessInfo.processInfo.hostName
        }
        return config.bindHost
    }

    public func buildApplication(identity: SelfSignedIdentity) throws -> some ApplicationProtocol {
        let tls = try TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(identity.nioCertificate)],
            privateKey: .privateKey(identity.nioPrivateKey)
        )
        return Application(
            router: buildRouter(),
            server: try .tls(.http1(), tlsConfiguration: tls),
            configuration: .init(
                address: .hostname(config.bindHost, port: config.port),
                serverName: "MyPorts"
            ),
            logger: logger
        )
    }

    /// Runs until the process is signalled, over TLS, advertising via Bonjour.
    public func run() async throws {
        let identity = try resolveIdentity()
        let advertiser = BonjourAdvertiser(
            name: ProcessInfo.processInfo.hostName,
            port: config.port,
            fingerprint: identity.fingerprint,
            apiVersion: RemoteConfig.apiVersion
        )
        advertiser.start()
        defer { advertiser.stop() }
        try await buildApplication(identity: identity).runService()
    }
}
