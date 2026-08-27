import Foundation
import Hummingbird
import NIOCore
import PortsKit

/// `GET /api/v1/events` — a Server-Sent Events stream that pushes a fresh
/// `ports` snapshot on every scan.
struct EventsController {
    let service: PortsService
    let config: RemoteConfig

    @Sendable
    func events(_ request: Request, context: AgentRequestContext) async throws -> Response {
        let service = self.service
        let interval = config.eventInterval

        let stream = AsyncStream<ByteBuffer>(bufferingPolicy: .bufferingNewest(2)) { continuation in
            let task = Task {
                let monitor = service.makeMonitor(interval: interval)
                await monitor.start()
                continuation.yield(Self.comment("stream opened"))
                for await snapshot in monitor.snapshots {
                    if Task.isCancelled { break }
                    continuation.yield(Self.frame(snapshot))
                }
                await monitor.shutdown()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        return Response(
            status: .ok,
            headers: [
                .contentType: "text/event-stream",
                .cacheControl: "no-cache",
                .connection: "keep-alive",
            ],
            body: .init(asyncSequence: stream)
        )
    }

    private static func frame(_ ports: [ListeningPort]) -> ByteBuffer {
        var buffer = ByteBuffer()
        buffer.writeString("event: ports\ndata: ")
        if let data = try? JSONBody.encoder.encode(PortsResponse(ports: ports)) {
            buffer.writeBytes(data)
        } else {
            buffer.writeString("{}")
        }
        buffer.writeString("\n\n")
        return buffer
    }

    private static func comment(_ text: String) -> ByteBuffer {
        ByteBuffer(string: ": \(text)\n\n")
    }
}
