// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "[name]",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "[name]",
            targets: ["[name]"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "[name]",
            dependencies: [],
        ),
        .testTarget(
            name: "[name]Tests",
            dependencies: ["[name]"]
        ),
    ]
)
