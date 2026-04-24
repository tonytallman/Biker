// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HeartRateService",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "HeartRateService",
            targets: ["HeartRateService"]
        ),
    ],
    targets: [
        .target(
            name: "HeartRateService"
        ),
        .testTarget(
            name: "HeartRateServiceTests",
            dependencies: ["HeartRateService"],
            path: "Tests/HeartRateServiceTests"
        ),
    ]
)
