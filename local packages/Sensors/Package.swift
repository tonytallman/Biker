// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Sensors",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "Sensors",
            targets: ["Sensors"]
        ),
    ],
    targets: [
        .target(
            name: "Sensors"
        ),
        .testTarget(
            name: "SensorsTests",
            dependencies: ["Sensors"],
            path: "Tests/SensorsTests"
        ),
    ]
)
