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
            name: "[name]UI",
            targets: ["[name]UI"]
        ),
        .library(
            name: "[name]VM",
            targets: ["[name]VM"]
        ),
        .library(
            name: "[name]Model",
            targets: ["[name]Model"]
        ),
        .library(
            name: "[name]Strings",
            targets: ["[name]Strings"]
        ),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "[name]Strings",
            dependencies: [],
            resources: [.process("Localizable.xcstrings")]
        ),
        .target(
            name: "[name]Model",
            dependencies: []
        ),
        .target(
            name: "[name]VM",
            dependencies: ["[name]Model", "[name]Strings"]
        ),
        .target(
            name: "[name]UI",
            dependencies: ["[name]VM", "DesignSystem", "[name]Strings"]
        ),
        .testTarget(
            name: "[name]ModelTests",
            dependencies: ["[name]Model"]
        ),
        .testTarget(
            name: "[name]VMTests",
            dependencies: ["[name]VM", "[name]Model"]
        ),
        .testTarget(
            name: "[name]UITests",
            dependencies: ["[name]UI", "[name]VM"]
        ),
    ]
)
