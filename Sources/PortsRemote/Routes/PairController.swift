import Foundation
import Hummingbird
import NIOCore

public struct PairRequest: Codable, Sendable {
    /// A human label for the new client ("Jerem's iPhone").
    public var label: String
}

public struct PairResponse: Codable, Sendable {
    public var apiVersion: Int
    public var token: String
    public var label: String
}

/// `POST /api/v1/pair` — exchanges a single-use pairing token (sent as
/// `Authorization: Bearer <pairingToken>`) for a long-lived bearer token.
///
/// This route is *not* behind `BearerAuthMiddleware`; it authenticates against
/// the ``PairingBroker`` instead.
struct PairController {
    let broker: PairingBroker
    let tokenStore: any TokenStoring
    let audit: any AuditLogging

    @Sendable
    func pair(_ request: Request, context: AgentRequestContext) async throws -> Response {
        guard
            let header = request.headers[.authorization],
            header.hasPrefix("Bearer "),
            case let pairingToken = String(header.dropFirst("Bearer ".count)),
            await broker.redeem(pairingToken)
        else {
            return JSONBody.error("invalid or expired pairing token", status: .unauthorized)
        }

        let body = (try? await request.decodeBody(as: PairRequest.self)) ?? PairRequest(label: "")
        let label = body.label.isEmpty ? "Paired \(Self.dateStamp())" : body.label
        let (secret, record) = try await tokenStore.create(label: label)

        await audit.record(
            AuditEntry(
                timestamp: Date(), action: "pair", tokenLabel: record.label,
                port: nil, pid: nil, signal: nil, outcome: "issued", detail: record.id))

        return JSONBody.json(
            PairResponse(apiVersion: RemoteConfig.apiVersion, token: secret, label: label))
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}
