//
//  SensorSettings.swift
//  Settings
//
//  Created by Tony Tallman on 4/12/26.
//

import Combine
import Foundation

@MainActor
public protocol SensorSettings {
    var sensors: AnyPublisher<[String], Never> { get }
    var discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never> { get }
    func scan()
    func stopScan()
    func connect(sensorID: UUID)
}

@MainActor
public struct PreviewSensorSettings: SensorSettings {
    public let sensors: AnyPublisher<[String], Never>
    public let discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never>

    public init() {
        sensors = Just(Self.previewSensorTitles).eraseToAnyPublisher()
        discoveredSensors = Just(Self.previewDiscoveredSensors).eraseToAnyPublisher()
    }

    public func scan() {}

    public func stopScan() {}

    public func connect(sensorID: UUID) {}

    private static let previewSensorTitles = [
        "Bontrager DuoTrap",
        "Schwinn IC400",
    ]

    private static let previewDiscoveredSensors: [DiscoveredSensorInfo] = [
        DiscoveredSensorInfo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Bontrager DuoTrap",
            rssi: -55
        ),
        DiscoveredSensorInfo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Schwinn IC400",
            rssi: -72
        ),
    ]
}
