// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MiniC",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MiniC", targets: ["MiniC"])
    ],
    targets: [
        .executableTarget(
            name: "MiniC",
            path: "Sources/MiniC"
        ),
        .testTarget(
            name: "MiniCTests",
            dependencies: ["MiniC"],
            path: "Tests/MiniCTests"
        )
    ]
)
