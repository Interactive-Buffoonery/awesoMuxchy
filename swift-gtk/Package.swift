// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AwesoMuxLinux",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "awesomux", targets: ["AwesoMuxApp"]),
        .library(name: "AwesoMuxCore", targets: ["AwesoMuxCore"]),
        .library(name: "AwesoMuxTerminal", targets: ["AwesoMuxTerminal"]),
        .executable(name: "awesomux-lifecycle-stress", targets: ["AwesoMuxLifecycleStress"]),
        .executable(name: "awesomux-terminal-integration", targets: ["AwesoMuxTerminalIntegration"]),
    ],
    dependencies: [
        .package(url: "https://github.com/rhx/SwiftGtk.git", revision: "ee963714f3e45c3201bf9cd45ae41cc360699304"),
    ],
    targets: [
        .target(name: "AwesoMuxCore"),
        .executableTarget(
            name: "AwesoMuxApp",
            dependencies: [
                "AwesoMuxCore",
                "AwesoMuxTerminal",
                .product(name: "Gtk", package: "SwiftGtk"),
            ]
        ),
        .target(
            name: "AwesoMuxTerminal",
            dependencies: [
                "CAwesoMuxGhostty",
                .product(name: "Gtk", package: "SwiftGtk"),
            ]
        ),
        .executableTarget(
            name: "AwesoMuxLifecycleStress",
            dependencies: [
                "AwesoMuxTerminal",
                .product(name: "Gtk", package: "SwiftGtk"),
            ]
        ),
        .executableTarget(
            name: "AwesoMuxTerminalIntegration",
            dependencies: [
                "AwesoMuxTerminal",
                .product(name: "Gtk", package: "SwiftGtk"),
            ]
        ),
        .systemLibrary(
            name: "CAwesoMuxGhostty",
            path: "Sources/CAwesoMuxGhostty",
            pkgConfig: "awesomux-ghostty"
        ),
        .testTarget(name: "AwesoMuxCoreTests", dependencies: ["AwesoMuxCore"]),
    ]
)
