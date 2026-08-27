import PortsKit
import SwiftUI

extension ProcessCategory {
    /// An SF Symbol name representing this category.
    public var symbolName: String {
        switch self {
        case .nodeRuntime: return "hexagon"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .ruby: return "diamond"
        case .java: return "cup.and.saucer"
        case .dotnet: return "square.grid.2x2"
        case .golang: return "g.circle"
        case .database: return "cylinder.split.1x2"
        case .webServer: return "globe"
        case .containerRuntime: return "shippingbox"
        case .shell: return "terminal"
        case .systemService: return "gearshape.2"
        case .unknown: return "app.dashed"
        }
    }

    /// A tint colour for the category's icon.
    public var tint: Color {
        switch self {
        case .nodeRuntime: return .green
        case .python: return .blue
        case .ruby: return .red
        case .java: return .orange
        case .dotnet: return .purple
        case .golang: return .teal
        case .database: return .indigo
        case .webServer: return .cyan
        case .containerRuntime: return .blue
        case .shell: return .secondary
        case .systemService: return .gray
        case .unknown: return .secondary
        }
    }
}
