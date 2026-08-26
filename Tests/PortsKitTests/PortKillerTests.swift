import Testing

@testable import PortsKit

@Suite("PortKiller")
struct PortKillerTests {
    @Test("terminateThenKill stops after SIGTERM when the process exits")
    func gracefulTerminate() async {
        let spy = SpySignaler()
        spy.sendOutcomes = [100: .signalled]
        spy.probeOutcomes = [100: .processNotFound]  // gone right after SIGTERM
        let killer = PortKiller(signaler: spy)

        let outcome = await killer.terminateThenKill(
            pid: 100, gracePeriod: .milliseconds(200), pollInterval: .milliseconds(10))

        #expect(outcome == .signalled)
        #expect(spy.calls.contains(.init(signal: .terminate, pid: 100)))
        #expect(!spy.calls.contains(.init(signal: .kill, pid: 100)))
    }

    @Test("terminateThenKill escalates to SIGKILL when the process ignores SIGTERM")
    func escalatesToKill() async {
        let spy = SpySignaler()
        spy.sendOutcomes = [200: .signalled]
        spy.probeOutcomes = [200: .signalled]  // stays alive through the grace period
        let killer = PortKiller(signaler: spy)

        let outcome = await killer.terminateThenKill(
            pid: 200, gracePeriod: .milliseconds(50), pollInterval: .milliseconds(10))

        #expect(outcome == .signalled)
        #expect(spy.calls.contains(.init(signal: .terminate, pid: 200)))
        #expect(spy.calls.contains(.init(signal: .kill, pid: 200)))
    }

    @Test("terminateThenKill treats an already-dead process as success")
    func alreadyDead() async {
        let spy = SpySignaler()
        spy.sendOutcomes = [300: .processNotFound]
        let killer = PortKiller(signaler: spy)

        #expect(await killer.terminateThenKill(pid: 300) == .signalled)
    }

    @Test("terminateThenKill surfaces permission denial without escalating")
    func permissionDenied() async {
        let spy = SpySignaler()
        spy.sendOutcomes = [400: .permissionDenied]
        let killer = PortKiller(signaler: spy)

        let outcome = await killer.terminateThenKill(pid: 400)
        #expect(outcome == .permissionDenied)
        #expect(!spy.calls.contains(.init(signal: .kill, pid: 400)))
    }

    @Test("isAlive treats a permission-denied probe as alive")
    func isAliveOnPermissionDenied() {
        let spy = SpySignaler()
        spy.probeOutcomes = [500: .permissionDenied]
        let killer = PortKiller(signaler: spy)
        #expect(killer.isAlive(pid: 500))
    }
}
