//
//  PreviewSensorProvider.swift
//  Settings
//

import Combine
import Foundation

/// Stubs a `SensorProvider` for SwiftUI previews (known + discovered lists).
@MainActor
public struct PreviewSensorProvider: SensorProvider {
    public var knownSensors: AnyPublisher<[any Sensor], Never>
    public var discoveredSensors: AnyPublisher<[any Sensor], Never>
    public var bluetoothAvailability: AnyPublisher<BluetoothAvailability, Never>

    public init() {
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let k1: any Sensor = MockCSCSensorPreview(
            id: id1,
            name: "Bontrager DuoTrap",
            rssi: -55,
            connectionState: .connected
        )
        let k2: any Sensor = MockPlainSensor(
            id: id2,
            name: "Schwinn IC400",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        let d1: any Sensor = MockSensorWithRSSI(
            id: id1,
            name: "Bontrager DuoTrap",
            type: .cyclingSpeedAndCadence,
            rssi: -55
        )
        let d2: any Sensor = MockSensorWithRSSI(
            id: id2,
            name: "Schwinn IC400",
            type: .cyclingSpeedAndCadence,
            rssi: -72
        )
        knownSensors = Just([k1, k2]).eraseToAnyPublisher()
        discoveredSensors = Just([d1, d2]).eraseToAnyPublisher()
        bluetoothAvailability = Just(.poweredOn).eraseToAnyPublisher()
    }

    public func scan() {}

    public func stopScan() {}
}
