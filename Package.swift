// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YandexMusicIsland",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "YandexMusicIsland",
            path: "Sources/YandexMusicIsland",
            linkerSettings: [
                .unsafeFlags(["-framework", "AppKit"]),
                .unsafeFlags(["-framework", "QuartzCore"])
            ]
        )
    ]
)
