// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Dashboard",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DashboardUI",
            targets: ["DashboardUI"]
        ),
        .library(
            name: "DashboardVM",
            targets: ["DashboardVM"]
        ),
        .library(
            name: "DashboardModel",
            targets: ["DashboardModel"]
        ),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DashboardModel",
            dependencies: []
        ),
        .target(
            name: "DashboardVM",
            dependencies: ["DashboardModel"]
        ),
        .target(
            name: "DashboardUI",
            dependencies: ["DashboardVM", "DashboardModel", "DesignSystem"]
        ),
        .testTarget(
            name: "DashboardModelTests",
            dependencies: ["DashboardModel"]
        ),
        .testTarget(
            name: "DashboardVMTests",
            dependencies: ["DashboardVM", "DashboardModel"]
        ),
        .testTarget(
            name: "DashboardUITests",
            dependencies: ["DashboardUI", "DashboardVM"]
        ),
    ]
)
