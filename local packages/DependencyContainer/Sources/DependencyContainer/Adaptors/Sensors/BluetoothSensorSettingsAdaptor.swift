//
//  BluetoothSensorSettingsAdaptor.swift
//  DependencyContainer
//

import Combine
import CyclingSpeedAndCadenceService
import SettingsModel

@MainActor
final class BluetoothSensorSettingsAdaptor: SensorSettings {
    private let manager: BluetoothSensorManager

    var sensors: AnyPublisher<[String], Never> {
        manager.knownSensorNamesPublisher
    }

    init(manager: BluetoothSensorManager) {
        self.manager = manager
    }

    func scan() {
        manager.startScan()
    }
}
