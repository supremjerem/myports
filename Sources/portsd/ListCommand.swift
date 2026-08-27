import ArgumentParser
import PortsKit

extension Portsd {
    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List listening TCP ports."
        )

        @Flag(name: .shortAndLong, help: "Emit JSON instead of a table.")
        var json = false

        @Flag(help: "Only show ports bound to a loopback address.")
        var loopbackOnly = false

        @Option(name: .shortAndLong, help: "Only show this port number.")
        var port: Int?

        func run() async throws {
            let service = PortsService()
            var ports = try await service.snapshot()

            if loopbackOnly {
                ports = ports.filter { $0.address.isLoopback }
            }
            if let port {
                ports = ports.filter { $0.address.port == port }
            }

            if json {
                print(try PortsFormatter.json(ports))
            } else {
                print(PortsFormatter.table(ports))
            }
        }
    }
}
