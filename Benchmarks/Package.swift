// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "Benchmarks",
            targets: ["Benchmarks"]),
    ],
    dependencies: [
        // Add a dependency on a package located in a directory relative to this file.
        .package(name: "AsyncChannels", path: "../")
    ],
    targets: [
        .target(
            name: "Benchmarks",
            dependencies: [
                .product(name: "AsyncChannels", package: "AsyncChannels")
            ],
            swiftSettings: [
                .unsafeFlags(["-O"], .when(configuration: .release))
            ]),
    ]
)
