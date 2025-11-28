// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KlipPal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "KlipPal",
            targets: ["KlipPal"]
        )
    ],
    dependencies: [],
    targets: [
        // Main app target
        .executableTarget(
            name: "KlipPal",
            dependencies: [],
            path: "Sources/KlipPal"
        ),

        // Test target
        .testTarget(
            name: "KlipPalTests",
            dependencies: ["KlipPal"],
            path: "Tests/KlipPalTests"
        )
    ]
)
