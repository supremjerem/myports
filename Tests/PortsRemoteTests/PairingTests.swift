import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import Testing

@testable import PortsRemote

@Suite("PairingBroker")
struct PairingBrokerTests {
    @Test("a token redeems exactly once")
    func singleUse() async {
        let broker = PairingBroker(ttl: 600)
        let token = await broker.issue()
        #expect(await broker.redeem(token))
        #expect(await broker.redeem(token) == false)
    }

    @Test("an expired token does not redeem")
    func expiry() async {
        let broker = PairingBroker(ttl: 600)
        let now = Date()
        let token = await broker.issue(now: now)
        #expect(await broker.redeem(token, now: now.addingTimeInterval(601)) == false)
    }

    @Test("an unknown token does not redeem")
    func unknown() async {
        let broker = PairingBroker()
        #expect(await broker.redeem("nope") == false)
    }
}

@Suite("PairingPayload")
struct PairingPayloadTests {
    @Test("round-trips through its myports:// URL")
    func roundTrip() {
        let payload = PairingPayload(
            host: "nexus.local", port: 7333, fingerprint: String(repeating: "ab", count: 32),
            pairingToken: "abc-123_XYZ")
        let parsed = PairingPayload.parse(payload.urlString())
        #expect(parsed == payload)
    }

    @Test("rejects a non-myports URL")
    func rejectsOther() {
        #expect(PairingPayload.parse("https://example.com/pair?d=zzz") == nil)
    }
}

@Suite("SelfSignedIdentity")
struct IdentityTests {
    @Test("generates a pinnable identity and persists it")
    func generateAndPersist() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("id-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let certURL = dir.appendingPathComponent("cert.pem")
        let keyURL = dir.appendingPathComponent("key.pem")

        let first = try IdentityStore.loadOrCreate(
            certificateURL: certURL, keyURL: keyURL, hostname: "testhost", ipAddresses: ["10.0.0.5"]
        )
        #expect(first.fingerprint.count == 64)
        #expect(first.fingerprint.allSatisfy { $0.isHexDigit })
        #expect(first.certificatePEM.contains("BEGIN CERTIFICATE"))
        _ = try first.nioCertificate
        _ = try first.nioPrivateKey

        // Loading again returns the same persisted identity.
        let second = try IdentityStore.loadOrCreate(
            certificateURL: certURL, keyURL: keyURL, hostname: "testhost")
        #expect(second.fingerprint == first.fingerprint)
    }
}

@Suite("POST /api/v1/pair")
struct PairRouteTests {
    @Test("a valid pairing token yields a working bearer token, once")
    func pairFlow() async throws {
        let dir = TempDataDir()
        let broker = PairingBroker()
        var logger = Logger(label: "test")
        logger.logLevel = .error
        let agent = PortsAgent(
            config: dir.config(), service: .stubbed(), broker: broker, logger: logger)

        let pairingToken = await broker.issue()

        try await Application(router: agent.buildRouter()).test(.router) { client in
            var bearer = ""
            try await client.execute(
                uri: "/api/v1/pair", method: .post,
                headers: [
                    .authorization: "Bearer \(pairingToken)", .contentType: "application/json",
                ],
                body: ByteBuffer(string: #"{"label":"my phone"}"#)
            ) { response in
                #expect(response.status == .ok)
                let body = try JSONDecoder().decode(
                    PairResponse.self, from: Data(buffer: response.body))
                #expect(body.label == "my phone")
                bearer = body.token
            }

            // The issued bearer authorises a real endpoint.
            try await client.execute(
                uri: "/api/v1/ports", method: .get,
                headers: [.authorization: "Bearer \(bearer)"]
            ) { response in
                #expect(response.status == .ok)
            }

            // The pairing token cannot be reused.
            try await client.execute(
                uri: "/api/v1/pair", method: .post,
                headers: [.authorization: "Bearer \(pairingToken)"],
                body: ByteBuffer(string: #"{"label":"again"}"#)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("a bogus pairing token is rejected")
    func bogusToken() async throws {
        let dir = TempDataDir()
        var logger = Logger(label: "test")
        logger.logLevel = .error
        let agent = PortsAgent(config: dir.config(), service: .stubbed(), logger: logger)

        try await Application(router: agent.buildRouter()).test(.router) { client in
            try await client.execute(
                uri: "/api/v1/pair", method: .post,
                headers: [.authorization: "Bearer not-real"],
                body: ByteBuffer(string: #"{"label":"x"}"#)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
