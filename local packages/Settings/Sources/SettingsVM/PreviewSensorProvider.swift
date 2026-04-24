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
    }

    public func scan() {}

    public func stopScan() {}
}

extension SensorAvailability {
    /// Preview-only: Bluetooth ready with stubbed known/discovered data.
    @MainActor
    public static var preview: AnyPublisher<SensorAvailability, Never> {
        let provider = PreviewSensorProvider()
        return Just(SensorAvailability.available(provider)).eraseToAnyPublisher()
    }

    /// All distinct `SensorAvailability` gating values for SwiftUI previews (ADR-0009).
    public enum PreviewCase: String, CaseIterable, Sendable {
        case notDetermined
        case denied
        case restricted
        case unsupported
        case resetting
        case poweredOff
        case available
    }

    /// A single-emission stream for a given gating value (``PreviewCase/available`` uses ``PreviewSensorProvider``).
    @MainActor
    public static func previewStream(_ scenario: PreviewCase) -> AnyPublisher<SensorAvailability, Never> {
        let provider = PreviewSensorProvider()
        switch scenario {
        case .notDetermined: return Just(.notDetermined).eraseToAnyPublisher()
        case .denied: return Just(.denied).eraseToAnyPublisher()
        case .restricted: return Just(.restricted).eraseToAnyPublisher()
        case .unsupported: return Just(.unsupported).eraseToAnyPublisher()
        case .resetting: return Just(.resetting).eraseToAnyPublisher()
        case .poweredOff: return Just(.poweredOff).eraseToAnyPublisher()
        case .available: return Just(.available(provider)).eraseToAnyPublisher()
        }
    }
}
