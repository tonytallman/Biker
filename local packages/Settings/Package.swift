// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SettingsUI",
            targets: ["SettingsUI"]
        ),
        .library(
            name: "SettingsVM",
            targets: ["SettingsVM"]
        ),
        .library(
            name: "SettingsModel",
            targets: ["SettingsModel"]
        ),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SettingsModel",
            dependencies: []
        ),
        .target(
            name: "SettingsVM",
            dependencies: ["SettingsModel"]
        ),
        .target(
            name: "SettingsUI",
            dependencies: ["SettingsVM", "SettingsModel", "DesignSystem"]
        ),
        .testTarget(
            name: "SettingsModelTests",
            dependencies: ["SettingsModel"]
        ),
        .testTarget(
            name: "SettingsVMTests",
            dependencies: ["SettingsVM", "SettingsModel"]
        ),
        .testTarget(
            name: "SettingsUITests",
            dependencies: ["SettingsUI", "SettingsVM"]
        ),
    ]
)
