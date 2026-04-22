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
    private let bluetoothAvailabilitySubject = CurrentValueSubject<BluetoothAvailability, Never>(.poweredOn)

    var knownSensors: AnyPublisher<[any Sensor], Never> {
        knownSensorsSubject.eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[any Sensor], Never> {
        discoveredSensorsSubject.eraseToAnyPublisher()
    }

    var bluetoothAvailability: AnyPublisher<BluetoothAvailability, Never> {
        bluetoothAvailabilitySubject.eraseToAnyPublisher()
    }

    private(set) var scanCallCount = 0
    private(set) var stopScanCallCount = 0

    func setKnownSensors(_ sensors: [any Sensor]) {
        knownSensorsSubject.send(sensors)
    }

    func setDiscoveredSensors(_ sensors: [any Sensor]) {
        discoveredSensorsSubject.send(sensors)
    }

    func setBluetoothAvailability(_ value: BluetoothAvailability) {
        bluetoothAvailabilitySubject.send(value)
    }

    func scan() {
        scanCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }
}
