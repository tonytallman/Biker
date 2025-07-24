// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreLogic",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CoreLogic",
            targets: ["CoreLogic"]
        ),
    ],
    dependencies: [
        .package(path: "../SpeedFromLocationServices"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CoreLogic",
            dependencies: ["SpeedFromLocationServices"]
        ),
        .testTarget(
            name: "CoreLogicTests",
            dependencies: ["CoreLogic"]
        ),
    ]
)
