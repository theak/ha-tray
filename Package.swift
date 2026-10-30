// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HATray",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(name: "HATrayCore"),
        .executableTarget(
            name: "HATray",
            dependencies: ["HATrayCore", "KeyboardShortcuts"]
        ),
        .testTarget(name: "HATrayCoreTests", dependencies: ["HATrayCore"]),
    ],
    swiftLanguageModes: [.v5]
)
