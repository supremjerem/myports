import Testing

@testable import PortsKit

@Suite("PortScanner")
struct PortScannerTests {
    private func makeScanner(
        listen: String,
        established: String,
        details: [Int32: ProcessDetails] = [:]
    ) -> PortScanner {
        PortScanner(
            runner: StubCommandRunner(listenOutput: listen, establishedOutput: established),
            inspector: StubProcessInspector(detailsByPID: details),
            nameResolver: FriendlyNameResolver(),
            lsofPath: "/usr/sbin/lsof"
        )
    }

    @Test("builds one listening port per pid/host/port, sorted by port")
    func buildsPorts() async throws {
        let scanner = makeScanner(
            listen: try Fixture.load("lsof-listen-devservers.txt"),
            established: try Fixture.load("lsof-established-devservers.txt")
        )

        let ports = try await scanner.scan()

        // node dual-stack (127.0.0.1 + [::1]) and postgres dual-stack -> the two
        // IPv6 rows survive because their host differs from the IPv4 row.
        #expect(ports.map(\.address.port) == [3000, 3000, 5432, 5432, 8000, 8080, 6379].sorted())
        #expect(ports.first?.address.port == 3000)
    }

    @Test("attaches established connections to the matching listening port")
    func attachesConnections() async throws {
        let scanner = makeScanner(
            listen: try Fixture.load("lsof-listen-devservers.txt"),
            established: try Fixture.load("lsof-established-devservers.txt")
        )

        let ports = try await scanner.scan()

        let node = try #require(
            ports.first { $0.process.command == "node" && $0.address.port == 3000 })
        #expect(node.establishedConnections.count == 2)
        #expect(node.establishedConnections.allSatisfy { $0.localAddress.port == 3000 })

        let redis = try #require(ports.first { $0.address.port == 6379 })
        #expect(redis.establishedConnections.isEmpty)
    }

    @Test("collapses the IPv4/IPv6 halves of a wildcard listener")
    func collapsesDualStackWildcard() async throws {
        let listen = """
            p777
            R1
            cControlCenter
            Ljrz
            f10
            tIPv4
            PTCP
            n*:7000
            TST=LISTEN
            f11
            tIPv6
            PTCP
            n*:7000
            TST=LISTEN
            """
        let scanner = makeScanner(listen: listen, established: "")

        let ports = try await scanner.scan()
        #expect(ports.count == 1)
        #expect(ports[0].address == SocketAddress(host: "*", port: 7000))
    }

    @Test("enriches the process from the inspector and name resolver")
    func enrichesProcess() async throws {
        let listen = """
            p42001
            R900
            cnode
            Ljrz
            f23
            tIPv4
            PTCP
            n127.0.0.1:5173
            TST=LISTEN
            """
        let details = [
            Int32(42001): ProcessDetails(
                executablePath: "/usr/local/bin/node",
                parentPID: 900,
                startDate: .init(timeIntervalSince1970: 1_700_000_000),
                arguments: ["node", "/repo/node_modules/.bin/vite", "--host"]
            )
        ]
        let scanner = makeScanner(listen: listen, established: "", details: details)

        let port = try #require(try await scanner.scan().first)
        #expect(port.process.friendlyName == "Vite dev server")
        #expect(port.process.category == .nodeRuntime)
        #expect(port.process.executablePath == "/usr/local/bin/node")
        #expect(port.process.arguments.contains("--host"))
    }

    @Test("treats lsof exit code 1 (no matches) as an empty result")
    func exitCodeOneIsEmpty() async throws {
        let scanner = PortScanner(
            runner: StubCommandRunner(listenOutput: "", establishedOutput: "", exitCode: 1),
            inspector: StubProcessInspector(),
            nameResolver: FriendlyNameResolver()
        )
        #expect(try await scanner.scan().isEmpty)
    }

    @Test("throws when lsof fails hard")
    func throwsOnHardFailure() async {
        let scanner = PortScanner(
            runner: StubCommandRunner(listenOutput: "", establishedOutput: "", exitCode: 127),
            inspector: StubProcessInspector(),
            nameResolver: FriendlyNameResolver()
        )
        await #expect(throws: PortScanError.self) {
            _ = try await scanner.scan()
        }
    }
}
