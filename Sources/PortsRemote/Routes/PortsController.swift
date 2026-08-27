import Foundation
import Hummingbird
import NIOCore
import PortsKit

/// `/api/v1/ports` routes: list, per-port connections, and kill.
struct PortsController {
    let service: PortsService
    let config: RemoteConfig
    let rateLimiter: RateLimiter
    let audit: any AuditLogging

    func addRoutes(to group: RouterGroup<AgentRequestContext>) {
        group.get("ports", use: list)
        group.get("ports/:port/connections", use: connections)
        group.post("ports/:port/kill", use: kill)
    }

    @Sendable
    private func list(_ request: Request, context: AgentRequestContext) async throws -> Response {
        let ports = try await service.snapshot()
        return JSONBody.json(PortsResponse(ports: ports))
    }

    @Sendable
    private func connections(_ request: Request, context: AgentRequestContext) async throws
        -> Response
    {
        let port = try portParameter(context)
        let match = try await service.snapshot().first { $0.address.port == port }
        let dtos = (match?.establishedConnections ?? []).map(ConnectionDTO.init)
        return JSONBody.json(
            ConnectionsResponse(apiVersion: RemoteConfig.apiVersion, connections: dtos))
    }

    @Sendable
    private func kill(_ request: Request, context: AgentRequestContext) async throws -> Response {
        if config.readOnly {
            return JSONBody.error("agent is read-only", status: .forbidden)
        }

        let token = context.authenticatedToken
        if let id = token?.id, await rateLimiter.allow(id) == false {
            return JSONBody.error("rate limit exceeded", status: .tooManyRequests)
        }

        let port = try portParameter(context)
        let body = try await request.decodeBody(as: KillRequest.self)

        guard let target = try await service.snapshot().first(where: { $0.address.port == port })
        else {
            return JSONBody.error("nothing is listening on port \(port)", status: .notFound)
        }

        let pid = target.process.pid
        let outcome: KillOutcome =
            body.signal == .kill
            ? service.killer.forceKill(pid: pid)
            : await service.killer.terminateThenKill(pid: pid)

        await audit.record(
            AuditEntry(
                timestamp: Date(),
                action: "kill",
                tokenLabel: token?.label,
                port: port,
                pid: pid,
                signal: body.signal.rawValue,
                outcome: outcome.auditString,
                detail: target.process.friendlyName
            ))

        let status: HTTPResponse.Status =
            switch outcome {
            case .signalled, .processNotFound: .ok
            case .permissionDenied: .forbidden
            default: .internalServerError
            }
        return JSONBody.json(
            KillResponse(
                apiVersion: RemoteConfig.apiVersion, outcome: outcome.auditString, pid: pid),
            status: status)
    }

    private func portParameter(_ context: AgentRequestContext) throws -> Int {
        guard let raw = context.parameters.get("port"), let port = Int(raw),
            (1...65535).contains(port)
        else {
            throw HTTPError(.badRequest, message: "invalid port")
        }
        return port
    }
}

extension KillOutcome {
    var auditString: String {
        switch self {
        case .signalled: return "signalled"
        case .processNotFound: return "processNotFound"
        case .permissionDenied: return "permissionDenied"
        case .cancelledByUser: return "cancelledByUser"
        case .failed(let code): return "failed(\(code))"
        }
    }
}

extension Request {
    /// Decodes a JSON body without relying on Hummingbird's context-based decoder.
    func decodeBody<T: Decodable>(as type: T.Type) async throws -> T {
        let buffer = try await body.collect(upTo: 64 * 1024)
        let data = Data(buffer: buffer)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPError(.badRequest, message: "invalid JSON body")
        }
    }
}
