// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostTile",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.7.0"),
        .package(
            url: "https://github.com/hewigovens/LSAppCategory",
            revision: "fe8edb78aaa41206e1a98b9bfbd0b0f26ed625c9"
        ),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.0"),
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
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            exclude: ["app.icon"]
        ),
        .testTarget(
            name: "GhostTileCoreTests",
            dependencies: ["GhostTileCore"],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "GhostTileAppTests",
            dependencies: ["GhostTileApp"]
        ),
    ]
)
