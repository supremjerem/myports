import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import PortsRemote

@Suite("Agent API")
struct AgentAPITests {
    private static var quietLogger: Logger {
        var logger = Logger(label: "myports.agent.test")
        logger.logLevel = .error
        return logger
    }

    private func makeAgent(
        dir: borrowing TempDataDir,
        readOnly: Bool = false,
        rateLimit: Int = 10,
        signaler: RecordingSignaler = RecordingSignaler(),
        broker: PairingBroker = PairingBroker()
    ) -> PortsAgent {
        PortsAgent(
            config: dir.config(readOnly: readOnly, killRateLimitPerMinute: rateLimit),
            service: .stubbed(signaler: signaler),
            broker: broker,
            logger: Self.quietLogger
        )
    }

    private func addToken(dir: borrowing TempDataDir) async throws -> String {
        let store = FileTokenStore(fileURL: dir.config().tokensFileURL)
        return try await store.create(label: "test").secret
    }

    @Test("GET /device needs no auth")
    func deviceIsPublic() async throws {
        let dir = TempDataDir()
        let agent = makeAgent(dir: dir)
        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(uri: "/api/v1/device", method: .get) { response in
                #expect(response.status == .ok)
                let body = try JSONDecoder().decode(
                    DeviceResponse.self, from: Data(buffer: response.body))
                #expect(body.apiVersion == 1)
                #expect(body.readOnly == false)
            }
        }
    }

    @Test("GET /ports is 401 without a token, 200 with one")
    func portsRequiresAuth() async throws {
        let dir = TempDataDir()
        let agent = makeAgent(dir: dir)
        let token = try await addToken(dir: dir)

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(uri: "/api/v1/ports", method: .get) { response in
                #expect(response.status == .unauthorized)
            }
            try await client.execute(
                uri: "/api/v1/ports", method: .get,
                headers: [.authorization: "Bearer \(token)"]
            ) { response in
                #expect(response.status == .ok)
                let body = try JSONDecoder().decode(
                    PortsResponse.self, from: Data(buffer: response.body))
                #expect(body.ports.map(\.port).sorted() == [3000, 5432])
                let node = try #require(body.ports.first { $0.port == 3000 })
                #expect(node.friendlyName == "Node.js")
                #expect(node.connectionCount == 1)
            }
        }
    }

    @Test("a garbage token is rejected")
    func garbageTokenRejected() async throws {
        let dir = TempDataDir()
        let agent = makeAgent(dir: dir)
        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(
                uri: "/api/v1/ports", method: .get,
                headers: [.authorization: "Bearer not-a-real-token"]
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("POST kill signals the process and writes an audit entry")
    func killSignalsAndAudits() async throws {
        let dir = TempDataDir()
        let signaler = RecordingSignaler()
        signaler.outcome = .signalled
        let agent = makeAgent(dir: dir, signaler: signaler)
        let token = try await addToken(dir: dir)

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(
                uri: "/api/v1/ports/3000/kill", method: .post,
                headers: [.authorization: "Bearer \(token)", .contentType: "application/json"],
                body: ByteBuffer(string: #"{"signal":"KILL"}"#)
            ) { response in
                #expect(response.status == .ok)
                let body = try JSONDecoder().decode(
                    KillResponse.self, from: Data(buffer: response.body))
                #expect(body.outcome == "signalled")
                #expect(body.pid == 42001)
            }
        }

        #expect(signaler.sent.contains { $0.0 == .kill && $0.1 == 42001 })

        let audit = FileAuditLog(fileURL: dir.config().auditLogURL)
        let entries = await audit.recentEntries(limit: 10)
        let killEntry = try #require(entries.first { $0.action == "kill" })
        #expect(killEntry.port == 3000)
        #expect(killEntry.outcome == "signalled")
        #expect(killEntry.tokenLabel == "test")
    }

    @Test("read-only mode rejects kill with 403")
    func readOnlyRejectsKill() async throws {
        let dir = TempDataDir()
        let agent = makeAgent(dir: dir, readOnly: true)
        let token = try await addToken(dir: dir)

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(
                uri: "/api/v1/ports/3000/kill", method: .post,
                headers: [.authorization: "Bearer \(token)", .contentType: "application/json"],
                body: ByteBuffer(string: #"{"signal":"TERM"}"#)
            ) { response in
                #expect(response.status == .forbidden)
            }
        }
    }

    @Test("kill is rate-limited per token")
    func killRateLimited() async throws {
        let dir = TempDataDir()
        let agent = makeAgent(dir: dir, rateLimit: 2)
        let token = try await addToken(dir: dir)

        try await Application(router: agent.buildRouter()).test(.router) { client in
            func fire() async throws -> HTTPResponse.Status {
                var status: HTTPResponse.Status = .ok
                try await client.execute(
                    uri: "/api/v1/ports/3000/kill", method: .post,
                    headers: [.authorization: "Bearer \(token)", .contentType: "application/json"],
                    body: ByteBuffer(string: #"{"signal":"TERM"}"#)
                ) { status = $0.status }
                return status
            }
            var status = try await fire()
            #expect(status == .ok)
            status = try await fire()
            #expect(status == .ok)
            status = try await fire()
            #expect(status == .tooManyRequests)
        }
    }

    @Test("kill on an unused port is 404")
    func killUnknownPort() async throws {
        let dir = TempDataDir()
        let agent = makeAgent(dir: dir)
        let token = try await addToken(dir: dir)

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(
                uri: "/api/v1/ports/9999/kill", method: .post,
                headers: [.authorization: "Bearer \(token)", .contentType: "application/json"],
                body: ByteBuffer(string: #"{"signal":"TERM"}"#)
            ) { response in
                #expect(response.status == .notFound)
            }
        }
    }
}
