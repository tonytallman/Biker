// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BikerCore",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BikerCore",
            targets: ["BikerCore"]),
    ],
    dependencies: [
        .package(path: "../SpeedFromLocationServices"),
        .package(path: "../Logging"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BikerCore",
            dependencies: ["SpeedFromLocationServices", "Logging"]
        ),
        .testTarget(
            name: "BikerCoreTests",
            dependencies: ["BikerCore"]
        ),
    ]
)
