import Testing

@testable import PortsKit

@Suite("LsofParser")
struct LsofParserTests {
    @Test("parses dev-server listeners from a fixture")
    func devServerListeners() throws {
        let sockets = LsofParser.parse(try Fixture.load("lsof-listen-devservers.txt"))

        // node binds IPv4 + IPv6, so 5 processes produce 7 sockets.
        #expect(sockets.count == 7)
        #expect(sockets.allSatisfy { $0.state == .listen })
        #expect(sockets.allSatisfy { $0.transport == .tcp })

        let node = try #require(sockets.first { $0.command == "node" })
        #expect(node.pid == 42001)
        #expect(node.parentPID == 900)
        #expect(node.login == "jrz")
        #expect(node.localAddress == SocketAddress(host: "127.0.0.1", port: 3000))
        #expect(node.remoteAddress == nil)

        let ports = Set(sockets.map(\.localAddress.port))
        #expect(ports == [3000, 5432, 8000, 8080, 6379])
    }

    @Test("parses established connections with a remote endpoint")
    func establishedConnections() throws {
        let sockets = LsofParser.parse(try Fixture.load("lsof-established-devservers.txt"))

        #expect(sockets.count == 3)
        #expect(sockets.allSatisfy { $0.state == .established })

        let first = try #require(sockets.first)
        #expect(first.localAddress == SocketAddress(host: "127.0.0.1", port: 3000))
        #expect(first.remoteAddress == SocketAddress(host: "127.0.0.1", port: 51544))
    }

    @Test("handles real captured output without crashing and finds only sockets")
    func realFixture() throws {
        let listen = LsofParser.parse(try Fixture.load("lsof-listen-real.txt"))
        #expect(!listen.isEmpty)
        #expect(listen.allSatisfy { $0.localAddress.port >= 0 })
        #expect(listen.allSatisfy { $0.pid > 0 })

        let established = LsofParser.parse(try Fixture.load("lsof-established-real.txt"))
        #expect(established.allSatisfy { $0.remoteAddress != nil })
    }

    @Test("ignores unknown field tags")
    func ignoresUnknownTags() {
        let output = """
            p1234
            g5678
            cmyapp
            uZZZ
            Ltester
            f9
            tIPv4
            PTCP
            n0.0.0.0:9999
            TST=LISTEN
            TQR=0
            """
        let sockets = LsofParser.parse(output)
        #expect(sockets.count == 1)
        #expect(sockets[0].command == "myapp")
        #expect(sockets[0].localAddress == SocketAddress(host: "0.0.0.0", port: 9999))
        #expect(sockets[0].state == .listen)
    }

    @Test("empty input yields no sockets")
    func emptyInput() {
        #expect(LsofParser.parse("").isEmpty)
    }
}
