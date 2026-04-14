//
//  SettingsDependencies.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 2/13/26.
//

import CyclingSpeedAndCadenceService
import SettingsModel
import SettingsVM

@MainActor
final class SettingsDependencies {
    private let systemSettings: SystemSettings
    private let sensorSettings: SensorSettings
    private let bluetoothSensorManager: BluetoothSensorManager
    let metricsSettings: DefaultMetricsSettings

    init(appStorage: AppStorage) {
        let settingsStorage = appStorage
            .withNamespacedKeys("Settings")
            .asSettingsStorage()
        systemSettings = DefaultSystemSettings(storage: settingsStorage)
        metricsSettings = DefaultMetricsSettings(storage: settingsStorage)
        let bluetoothSensorManager = BluetoothSensorManager()
        self.bluetoothSensorManager = bluetoothSensorManager
        sensorSettings = BluetoothSensorSettingsAdaptor(manager: bluetoothSensorManager)
    }
    
    func getSettingsViewModel() -> SettingsViewModel {
        SettingsVM.SettingsViewModel(
            metricsSettings: metricsSettings,
            systemSettings: systemSettings,
            sensorSettings: sensorSettings,
        )
    }
}
