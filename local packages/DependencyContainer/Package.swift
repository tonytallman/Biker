// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DependencyContainer",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DependencyContainer",
            targets: ["DependencyContainer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.0.0"),
        .package(path: "../CoreLogic"),
        .package(path: "../CyclingSpeedAndCadenceService"),
        .package(path: "../Dashboard"),
        .package(path: "../FitnessMachineService"),
        .package(path: "../HeartRateService"),
        .package(path: "../MainView"),
        .package(path: "../MetricsFromCoreLocation"),
        .package(path: "../Settings"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DependencyContainer",
            dependencies: [
                "CoreLogic",
                "CyclingSpeedAndCadenceService",
                "FitnessMachineService",
                "HeartRateService",
                "MetricsFromCoreLocation",
                .product(name: "MainVM", package: "MainView"),
                .product(name: "SettingsVM", package: "Settings"),
                .product(name: "DashboardVM", package: "Dashboard"),
            ],
        ),
        .testTarget(
            name: "DependencyContainerTests",
            dependencies: [
                "DependencyContainer",
                "CoreLogic",
                "CyclingSpeedAndCadenceService",
                "FitnessMachineService",
                "HeartRateService",
                .product(name: "SettingsVM", package: "Settings"),
            ]
        ),
        .testTarget(
            name: "DependencyContainerIntegrationTests",
            dependencies: [
                "DependencyContainer",
                "CoreLogic",
                "CyclingSpeedAndCadenceService",
                "FitnessMachineService",
                "HeartRateService",
                .product(name: "SettingsVM", package: "Settings"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
            ]
        ),
    ]
)
