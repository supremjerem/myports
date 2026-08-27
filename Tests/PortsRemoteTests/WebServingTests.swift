import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import Testing

@testable import PortsRemote

@Suite("Web serving & query-param auth")
struct WebServingTests {
    private func quietLogger() -> Logger {
        var logger = Logger(label: "test")
        logger.logLevel = .error
        return logger
    }

    @Test("serves index.html at / when a web root is configured")
    func servesIndex() async throws {
        let dir = TempDataDir()
        let webRoot = dir.url.appendingPathComponent("web", isDirectory: true)
        try FileManager.default.createDirectory(at: webRoot, withIntermediateDirectories: true)
        try "<!doctype html><title>MyPorts</title><body>hi</body>".write(
            to: webRoot.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        var config = dir.config()
        config.webRoot = webRoot
        let agent = PortsAgent(config: config, service: .stubbed(), logger: quietLogger())

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body).contains("MyPorts"))
            }
            // API routes still resolve past the file middleware.
            try await client.execute(uri: "/api/v1/device", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("no web root means / is not found, API still works")
    func noWebRoot() async throws {
        let dir = TempDataDir()
        let agent = PortsAgent(config: dir.config(), service: .stubbed(), logger: quietLogger())
        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .notFound)
            }
            try await client.execute(uri: "/api/v1/device", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("accepts a ?token= query parameter (for EventSource)")
    func queryParamToken() async throws {
        let dir = TempDataDir()
        let agent = PortsAgent(config: dir.config(), service: .stubbed(), logger: quietLogger())
        let store = FileTokenStore(fileURL: dir.config().tokensFileURL)
        let token = try await store.create(label: "sse").secret

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(uri: "/api/v1/ports?token=\(token)", method: .get) {
                response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/api/v1/ports?token=wrong", method: .get) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
