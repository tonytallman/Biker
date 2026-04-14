//
//  MockSensorSettings.swift
//  SettingsVMTests
//
//  Created by Tony Tallman on 4/12/26.
//

import Combine
import Foundation

import SettingsModel

@MainActor
final class MockSensorSettings: SensorSettings {
    private let sensorsSubject = CurrentValueSubject<[String], Never>([])
    private let discoveredSensorsSubject = CurrentValueSubject<[DiscoveredSensorInfo], Never>([])

    var sensors: AnyPublisher<[String], Never> {
        sensorsSubject.eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never> {
        discoveredSensorsSubject.eraseToAnyPublisher()
    }

    private(set) var scanCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0
    private(set) var lastConnectedSensorID: UUID?

    func scan() {
        scanCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }

    func connect(sensorID: UUID) {
        connectCallCount += 1
        lastConnectedSensorID = sensorID
    }

    func setSensorTitles(_ titles: [String]) {
        sensorsSubject.send(titles)
    }

    func setDiscoveredSensors(_ sensors: [DiscoveredSensorInfo]) {
        discoveredSensorsSubject.send(sensors)
    }
}
