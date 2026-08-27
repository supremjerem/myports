import Darwin
import Foundation
import Testing

@testable import PortsKit

@Suite("ProcessInspector")
struct ProcessInspectorTests {
    let inspector = ProcessInspector()

    @Test("resolves details for the current process")
    func inspectSelf() throws {
        let details = inspector.inspect(pid: getpid())

        let path = try #require(details.executablePath)
        #expect(FileManager.default.fileExists(atPath: path))

        let ppid = try #require(details.parentPID)
        #expect(ppid > 0)

        let start = try #require(details.startDate)
        #expect(start <= Date())
        #expect(start > Date(timeIntervalSinceNow: -60 * 60 * 24))

        #expect(!details.arguments.isEmpty)
    }

    @Test("returns empty details for a pid that cannot exist")
    func inspectMissing() {
        #expect(inspector.inspect(pid: 99_999) == .empty)
    }
}
