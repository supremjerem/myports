import Testing

@testable import PortsKit

@Suite("SocketAddress parsing")
struct SocketAddressTests {
    @Test("IPv4 host and port")
    func ipv4() {
        let address = SocketAddress.parse("127.0.0.1:3000")
        #expect(address == SocketAddress(host: "127.0.0.1", port: 3000))
    }

    @Test("wildcard host keeps the port")
    func wildcardHost() {
        #expect(SocketAddress.parse("*:8080") == SocketAddress(host: "*", port: 8080))
    }

    @Test("wildcard port becomes zero")
    func wildcardPort() {
        #expect(SocketAddress.parse("*:*") == SocketAddress(host: "*", port: 0))
    }

    @Test("bracketed IPv6")
    func ipv6() {
        #expect(SocketAddress.parse("[::1]:5432") == SocketAddress(host: "::1", port: 5432))
    }

    @Test("bracketed link-local IPv6 with scope and zero port")
    func ipv6LinkLocal() {
        let address = SocketAddress.parse("[fe80:f::10e0:a3d5:4967:11ea]:0")
        #expect(address == SocketAddress(host: "fe80:f::10e0:a3d5:4967:11ea", port: 0))
    }

    @Test("rejects malformed input", arguments: ["", "nonsense", "1.2.3.4", "[::1]", ":80"])
    func rejectsMalformed(_ token: String) {
        #expect(SocketAddress.parse(token) == nil)
    }

    @Test("loopback detection")
    func loopback() {
        #expect(SocketAddress(host: "127.0.0.1", port: 1).isLoopback)
        #expect(SocketAddress(host: "::1", port: 1).isLoopback)
        #expect(!SocketAddress(host: "*", port: 1).isLoopback)
        #expect(!SocketAddress(host: "192.168.1.10", port: 1).isLoopback)
    }

    @Test("wildcard host detection")
    func wildcard() {
        #expect(SocketAddress(host: "*", port: 1).isWildcardHost)
        #expect(SocketAddress(host: "0.0.0.0", port: 1).isWildcardHost)
        #expect(SocketAddress(host: "::", port: 1).isWildcardHost)
        #expect(!SocketAddress(host: "127.0.0.1", port: 1).isWildcardHost)
    }
}
