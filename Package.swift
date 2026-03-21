// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostTile",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/hewigovens/LSAppCategory", branch: "main"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.3.0"),
    ],
    targets: [
        .target(name: "GhostTileCore"),
        .executableTarget(
            name: "ghosttile",
            dependencies: [
                "GhostTileCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "GhostTileApp",
            dependencies: [
                "GhostTileCore",
                "LSAppCategory",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            exclude: ["app.icon"]
        ),
        .testTarget(
            name: "GhostTileCoreTests",
            dependencies: ["GhostTileCore"],
            exclude: ["Resources"]
        ),
    ]
)
