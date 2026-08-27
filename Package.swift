// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyPorts",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PortsKit", targets: ["PortsKit"]),
        .library(name: "PortsUI", targets: ["PortsUI"]),
        .executable(name: "portsd", targets: ["portsd"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "PortsKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "PortsUI",
            dependencies: ["PortsKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "portsd",
            dependencies: [
                "PortsKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "PortsPreviewApp",
            dependencies: ["PortsUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PortsKitTests",
            dependencies: ["PortsKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
