import Hummingbird

/// Request context carrying the authenticated token (set by
/// ``BearerAuthMiddleware``) so downstream handlers can rate-limit and audit.
public struct AgentRequestContext: RequestContext {
    public var coreContext: CoreRequestContextStorage
    public var authenticatedToken: TokenRecord?

    public init(source: Source) {
        self.coreContext = .init(source: source)
        self.authenticatedToken = nil
    }
}
