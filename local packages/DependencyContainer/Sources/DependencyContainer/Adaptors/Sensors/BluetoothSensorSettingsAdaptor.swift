//
//  BluetoothSensorSettingsAdaptor.swift
//  DependencyContainer
//

import Combine
import CyclingSpeedAndCadenceService
import Foundation
import SettingsModel

@MainActor
final class BluetoothSensorSettingsAdaptor: SensorSettings {
    private let manager: BluetoothSensorManager

    var sensors: AnyPublisher<[String], Never> {
        manager.knownSensorNamesPublisher
    }

    var discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never> {
        manager.discoveredSensors
            .map { list in
                list.map {
                    DiscoveredSensorInfo(id: $0.id, name: $0.name, rssi: $0.rssi)
                }
            }
            .eraseToAnyPublisher()
    }

    init(manager: BluetoothSensorManager) {
        self.manager = manager
    }

    func scan() {
        manager.startScan()
    }

    func stopScan() {
        manager.stopScan()
    }

    func connect(sensorID: UUID) {
        manager.connect(to: sensorID)
    }
}
