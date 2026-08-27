import Darwin
import Foundation
import Testing

@testable import PortsKit

@Suite("SystemSignaler", .serialized)
struct SystemSignalerTests {
    let signaler = SystemSignaler()

    @Test("probing our own process succeeds")
    func probeSelf() {
        #expect(signaler.probe(pid: getpid()) == .signalled)
    }

    @Test("probing a pid that cannot exist reports processNotFound")
    func probeMissing() {
        // PID_MAX on Darwin is 99998; this is guaranteed free.
        #expect(signaler.probe(pid: 99_999) == .processNotFound)
    }

    @Test("probing launchd (pid 1) is denied for a non-root test runner")
    func probeDenied() throws {
        try #require(getuid() != 0, "test must run unprivileged")
        #expect(signaler.probe(pid: 1) == .permissionDenied)
    }

    @Test("rejects a non-positive pid instead of broadcasting")
    func rejectsNonPositivePID() {
        #expect(signaler.send(.terminate, to: 0) == .failed(errno: EINVAL))
        #expect(signaler.send(.kill, to: -1) == .failed(errno: EINVAL))
    }

    @Test("SIGTERM actually stops a child process")
    func terminatesChild() async throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        let pid = child.processIdentifier

        #expect(signaler.probe(pid: pid) == .signalled)
        #expect(signaler.send(.terminate, to: pid) == .signalled)

        // Give the kernel a moment to reap it.
        for _ in 0..<50 where child.isRunning {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!child.isRunning)
        #expect(signaler.send(.terminate, to: pid) == .processNotFound)
    }
}
