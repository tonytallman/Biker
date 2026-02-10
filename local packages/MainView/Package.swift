// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MainView",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MainUI",
            targets: ["MainUI"]
        ),
        .library(
            name: "MainVM",
            targets: ["MainVM"]
        ),
    ],
    dependencies: [
        .package(path: "../Dashboard"),
        .package(path: "../Settings"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MainVM",
            dependencies: [
                .product(name: "DashboardVM", package: "Dashboard"),
                .product(name: "SettingsVM", package: "Settings"),
            ]
        ),
        .target(
            name: "MainUI",
            dependencies: [
                "MainVM",
                .product(name: "DashboardUI", package: "Dashboard"),
                .product(name: "SettingsUI", package: "Settings"),
            ]
        ),
        .testTarget(
            name: "MainVMTests",
            dependencies: ["MainVM"]
        ),
        .testTarget(
            name: "MainUITests",
            dependencies: ["MainUI", "MainVM"]
        ),
    ]
)

