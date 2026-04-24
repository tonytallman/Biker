//
//  FakeSensorProvider.swift
//  DependencyContainerTests
//

import Combine
import Foundation
import SettingsVM
@testable import DependencyContainer

@MainActor
final class FakeSensorProvider: SensorProvider {
    private let knownSubject = CurrentValueSubject<[any Sensor], Never>([])
    private let discoveredSubject = CurrentValueSubject<[any Sensor], Never>([])

    var knownSensors: AnyPublisher<[any Sensor], Never> { knownSubject.eraseToAnyPublisher() }
    var discoveredSensors: AnyPublisher<[any Sensor], Never> { discoveredSubject.eraseToAnyPublisher() }

    private(set) var scanCallCount = 0
    private(set) var stopScanCallCount = 0

    func setKnown(_ sensors: [any Sensor]) {
        knownSubject.send(sensors)
    }

    func setDiscovered(_ sensors: [any Sensor]) {
        discoveredSubject.send(sensors)
    }

    func scan() {
        scanCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }
}
