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
        .library(name: "PortsRemote", targets: ["PortsRemote"]),
        .executable(name: "portsd", targets: ["portsd"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-certificates", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.25.0"),
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
        .target(
            name: "PortsRemote",
            dependencies: [
                "PortsKit",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTLS", package: "hummingbird"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "portsd",
            dependencies: [
                "PortsKit",
                "PortsRemote",
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
        .testTarget(
            name: "PortsRemoteTests",
            dependencies: [
                "PortsRemote",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
