// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FitnessMachineService",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "FitnessMachineService",
            targets: ["FitnessMachineService"]
        ),
    ],
    targets: [
        .target(
            name: "FitnessMachineService"
        ),
        .testTarget(
            name: "FitnessMachineServiceTests",
            dependencies: ["FitnessMachineService"],
            path: "Tests/FitnessMachineServiceTests"
        ),
    ]
)
