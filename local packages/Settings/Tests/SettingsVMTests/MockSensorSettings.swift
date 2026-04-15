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
    private let sensorsSubject = CurrentValueSubject<[ConnectedSensorInfo], Never>([])
    private let discoveredSensorsSubject = CurrentValueSubject<[DiscoveredSensorInfo], Never>([])

    var sensors: AnyPublisher<[ConnectedSensorInfo], Never> {
        sensorsSubject.eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never> {
        discoveredSensorsSubject.eraseToAnyPublisher()
    }

    private(set) var scanCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var forgetCallCount = 0
    private(set) var lastConnectedSensorID: UUID?
    private(set) var lastDisconnectedSensorID: UUID?
    private(set) var lastForgottenSensorID: UUID?

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

    func disconnect(sensorID: UUID) {
        disconnectCallCount += 1
        lastDisconnectedSensorID = sensorID
    }

    func forget(sensorID: UUID) {
        forgetCallCount += 1
        lastForgottenSensorID = sensorID
    }

    func setSensors(_ sensors: [ConnectedSensorInfo]) {
        sensorsSubject.send(sensors)
    }

    func setDiscoveredSensors(_ sensors: [DiscoveredSensorInfo]) {
        discoveredSensorsSubject.send(sensors)
    }
}
