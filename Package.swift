// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenRuler",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ScreenRuler", path: "Sources/ScreenRuler")
    ]
)
