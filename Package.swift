// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CryptoMinbar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CryptoMinbar", targets: ["CryptoMinbar"])
    ],
    dependencies: [
        .package(url: "https://github.com/centrifugal/centrifuge-swift.git", from: "0.8.2")
    ],
    targets: [
        .executableTarget(
            name: "CryptoMinbar",
            dependencies: [
                .product(name: "SwiftCentrifuge", package: "centrifuge-swift")
            ],
            path: "Sources/CryptoMinbar"
        ),
        .testTarget(
            name: "CryptoMinbarTests",
            dependencies: ["CryptoMinbar"],
            path: "Tests/CryptoMinbarTests"
        )
    ]
)
