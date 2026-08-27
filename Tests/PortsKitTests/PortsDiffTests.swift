import Testing

@testable import PortsKit

@Suite("PortsDiff")
struct PortsDiffTests {
    private func port(_ number: Int, pid: Int32, connections: Int = 0) -> ListeningPort {
        ListeningPort(
            address: SocketAddress(host: "127.0.0.1", port: number),
            transport: .tcp,
            process: PortProcess(
                pid: pid, parentPID: 1, command: "node", executablePath: nil,
                arguments: [], user: "jrz", startDate: nil, friendlyName: "Node.js",
                category: .nodeRuntime),
            establishedConnections: (0..<connections).map { index in
                Connection(
                    localAddress: SocketAddress(host: "127.0.0.1", port: number),
                    remoteAddress: SocketAddress(host: "127.0.0.1", port: 50000 + index),
                    state: .established, transport: .tcp)
            }
        )
    }

    @Test("no change yields an empty diff")
    func noChange() {
        let snapshot = [port(3000, pid: 1), port(5432, pid: 2)]
        #expect(PortsDiff.between(old: snapshot, new: snapshot).isEmpty)
    }

    @Test("detects added and removed ports")
    func addedAndRemoved() {
        let old = [port(3000, pid: 1)]
        let new = [port(5432, pid: 2)]
        let diff = PortsDiff.between(old: old, new: new)

        #expect(diff.added.map(\.port) == [5432])
        #expect(diff.removed.map(\.port) == [3000])
        #expect(diff.changed.isEmpty)
    }

    @Test("detects a changed connection count on a stable port")
    func changedConnections() {
        let old = [port(3000, pid: 1, connections: 0)]
        let new = [port(3000, pid: 1, connections: 2)]
        let diff = PortsDiff.between(old: old, new: new)

        #expect(diff.added.isEmpty)
        #expect(diff.removed.isEmpty)
        #expect(diff.changed.map(\.port) == [3000])
    }
}
