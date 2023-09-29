// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "ZipPinch",
    platforms: [.macOS(.v12), .iOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "ZipPinch", targets: ["ZipPinch"]),
    ],
    targets: [
        .target(name: "ZipPinch"),
        .testTarget(name: "ZipPinchTests", dependencies: ["ZipPinch"]),
    ]
)
