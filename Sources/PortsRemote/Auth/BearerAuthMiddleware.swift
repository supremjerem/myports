import Foundation
import Hummingbird
import NIOCore

/// Rejects any request without a valid `Authorization: Bearer <token>` header,
/// and stashes the matched ``TokenRecord`` on the context.
public struct BearerAuthMiddleware: RouterMiddleware {
    public typealias Context = AgentRequestContext

    let tokenStore: any TokenStoring

    public init(tokenStore: any TokenStoring) {
        self.tokenStore = tokenStore
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard
            let header = request.headers[.authorization],
            header.hasPrefix("Bearer "),
            case let secret = String(header.dropFirst("Bearer ".count)),
            !secret.isEmpty,
            let record = await tokenStore.verify(secret: secret)
        else {
            return JSONBody.error("unauthorized", status: .unauthorized)
        }
        var context = context
        context.authenticatedToken = record
        return try await next(request, context)
    }
}

/// Small helpers for building JSON responses without depending on Hummingbird's
/// Codable response glue.
enum JSONBody {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func json<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) -> Response {
        let data = (try? encoder.encode(value)) ?? Data(#"{"error":"encoding failed"}"#.utf8)
        return Response(
            status: status,
            headers: [.contentType: "application/json; charset=utf-8"],
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }

    static func error(_ message: String, status: HTTPResponse.Status) -> Response {
        json(APIError(message), status: status)
    }
}
