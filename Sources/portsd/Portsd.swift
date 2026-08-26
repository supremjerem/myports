import ArgumentParser
import PortsKit

@main
struct Portsd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "portsd",
        abstract: "Inspect listening TCP ports and the processes behind them.",
        version: "0.1.0",
        subcommands: [List.self, Kill.self],
        defaultSubcommand: List.self
    )
}
