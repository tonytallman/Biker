//
//  MockSensorProvider.swift
//  SettingsVMTests
//

import Combine
import Foundation

import SettingsVM

@MainActor
final class MockSensorProvider: SensorProvider {
    private let knownSensorsSubject = CurrentValueSubject<[any Sensor], Never>([])
    private let discoveredSensorsSubject = CurrentValueSubject<[any Sensor], Never>([])

    var knownSensors: AnyPublisher<[any Sensor], Never> {
        knownSensorsSubject.eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[any Sensor], Never> {
        discoveredSensorsSubject.eraseToAnyPublisher()
    }

    private(set) var scanCallCount = 0
    private(set) var stopScanCallCount = 0

    func setKnownSensors(_ sensors: [any Sensor]) {
        knownSensorsSubject.send(sensors)
    }

    func setDiscoveredSensors(_ sensors: [any Sensor]) {
        discoveredSensorsSubject.send(sensors)
    }

    func scan() {
        scanCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }
}

// MARK: - Sensor availability helper (ADR-0009)

@MainActor
final class MockSensorAvailability {
    private let subject: CurrentValueSubject<SensorAvailability, Never>

    let provider: MockSensorProvider

    var publisher: AnyPublisher<SensorAvailability, Never> {
        subject.eraseToAnyPublisher()
    }

    init(initialBluetooth: BluetoothAvailability = .poweredOn) {
        let mock = MockSensorProvider()
        self.provider = mock
        self.subject = CurrentValueSubject(
            Self.mapBluetooth(initialBluetooth, provider: mock)
        )
    }

    func setBluetoothRadio(_ value: BluetoothAvailability) {
        subject.send(Self.mapBluetooth(value, provider: provider))
    }

    private static func mapBluetooth(_ value: BluetoothAvailability, provider: MockSensorProvider) -> SensorAvailability {
        BluetoothAvailabilityMapping.sensorAvailability(for: value, provider: provider)
    }
}
