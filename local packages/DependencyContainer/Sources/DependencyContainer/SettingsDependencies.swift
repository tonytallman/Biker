//
//  SettingsDependencies.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 2/13/26.
//

import CyclingSpeedAndCadenceService
import FitnessMachineService
import HeartRateService
import SettingsVM

@MainActor
final class SettingsDependencies {
    private let systemSettings: SettingsViewModel.SystemSettings
    private let compositeSensorProvider: CompositeSensorProvider
    let bluetoothSensorManager: CyclingSpeedAndCadenceSensorManager
    let fitnessMachineSensorManager: FitnessMachineSensorManager
    let heartRateSensorManager: HeartRateSensorManager
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

        let fitnessMachineSensorManager = FitnessMachineSensorManager(persistence: namespacedAppStorage)
        fitnessMachineSensorManager.reconnectDisconnectedKnownSensorsIfPoweredOn()
        self.fitnessMachineSensorManager = fitnessMachineSensorManager

        let heartRateSensorManager = HeartRateSensorManager(persistence: namespacedAppStorage)
        heartRateSensorManager.reconnectDisconnectedKnownSensorsIfPoweredOn()
        self.heartRateSensorManager = heartRateSensorManager

        let cscSensorProvider = CSCSensorProvider(manager: bluetoothSensorManager)
        let ftmsSensorProvider = FTMSSensorProvider(manager: fitnessMachineSensorManager)
        let hrSensorProvider = HRSensorProvider(manager: heartRateSensorManager)
        let systemAvailability = BluetoothAvailabilityAdapter.combined(
            csc: bluetoothSensorManager.bluetoothAvailability,
            ftms: fitnessMachineSensorManager.bluetoothAvailability,
            hr: heartRateSensorManager.bluetoothAvailability
        )
        compositeSensorProvider = CompositeSensorProvider(
            sensorProviders: [cscSensorProvider, ftmsSensorProvider, hrSensorProvider],
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
