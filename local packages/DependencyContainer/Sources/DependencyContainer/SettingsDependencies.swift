//
//  SettingsDependencies.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 2/13/26.
//

import CyclingSpeedAndCadenceService
import SettingsVM

@MainActor
final class SettingsDependencies {
    private let systemSettings: SettingsViewModel.SystemSettings
    private let compositeSensorProvider: CompositeSensorProvider
    let bluetoothSensorManager: CyclingSpeedAndCadenceSensorManager
    let metricsSettings: DefaultMetricsSettings

    init(appStorage: AppStorage) {
        let namespacedAppStorage = appStorage.withNamespacedKeys("Settings")
        let settingsStorage = namespacedAppStorage.asSettingsStorage()
        systemSettings = DefaultSystemSettings(storage: settingsStorage)
        metricsSettings = DefaultMetricsSettings(storage: settingsStorage)
        let cscKnownSensorPersistence = CSCKnownSensorPersistenceAdapter(appStorage: namespacedAppStorage)
        let bluetoothSensorManager = CyclingSpeedAndCadenceSensorManager(
            persistence: cscKnownSensorPersistence
        )
        bluetoothSensorManager.reconnectDisconnectedKnownSensorsIfPoweredOn()
        self.bluetoothSensorManager = bluetoothSensorManager
        let cscSensorProvider = CSCSensorProvider(manager: bluetoothSensorManager)
        let systemAvailability = BluetoothAvailabilityAdapter.publisher(
            source: bluetoothSensorManager.bluetoothAvailability
        )
        compositeSensorProvider = CompositeSensorProvider(
            sensorProviders: [cscSensorProvider],
            systemAvailability: systemAvailability,
        )
    }

    func getSettingsViewModel() -> SettingsViewModel {
        SettingsVM.SettingsViewModel(
            metricsSettings: metricsSettings,
            systemSettings: systemSettings,
            sensorAvailability: compositeSensorProvider.availability
        )
    }
}
