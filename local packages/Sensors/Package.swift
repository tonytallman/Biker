// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Sensors",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Sensors",
            targets: ["Sensors"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/meech-ward/AsyncCoreBluetooth.git", branch: "main"),
        .package(url: "https://github.com/meech-ward/IOS-CoreBluetooth-Mock.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Sensors",
            dependencies: ["AsyncCoreBluetooth"]
        ),
        .testTarget(
            name: "SensorsTests",
            dependencies: [
                "Sensors",
                .product(name: "AsyncCoreBluetooth", package: "AsyncCoreBluetooth"),
                .product(name: "CoreBluetoothMock", package: "IOS-CoreBluetooth-Mock"),
            ],
            path: "Tests/SensorsTests"
        ),
    ]
)
