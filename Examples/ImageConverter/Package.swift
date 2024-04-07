// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageConverter",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "ImageConverter",
            targets: ["ImageConverter"]),
    ],
    dependencies: [
            .package(name: "AsyncChannels", path: "../../")
        ],
    targets: [
        .target(
            name: "ImageConverter",
            dependencies: [
               .product(name: "AsyncChannels", package: "AsyncChannels")
           ]),
    ]
)
