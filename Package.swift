// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CryptoMinbar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CryptoMinbar", targets: ["CryptoMinbar"])
    ],
    targets: [
        .executableTarget(
            name: "CryptoMinbar",
            path: "Sources/CryptoMinbar"
        ),
        .testTarget(
            name: "CryptoMinbarTests",
            dependencies: ["CryptoMinbar"],
            path: "Tests/CryptoMinbarTests"
        )
    ]
)
