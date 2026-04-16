// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    defaultLocalization: "en",
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
            name: "SettingsStrings",
            targets: ["SettingsStrings"]
        ),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SettingsStrings",
            dependencies: [],
            resources: [.process("Localizable.xcstrings")]
        ),
        .target(
            name: "SettingsVM",
            dependencies: ["SettingsStrings"]
        ),
        .target(
            name: "SettingsUI",
            dependencies: ["SettingsVM", "DesignSystem", "SettingsStrings"]
        ),
        .testTarget(
            name: "SettingsVMTests",
            dependencies: ["SettingsVM"]
        ),
        .testTarget(
            name: "SettingsUITests",
            dependencies: ["SettingsUI", "SettingsVM"]
        ),
    ]
)
