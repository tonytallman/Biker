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

    /// Wire real per-family managers and the composite (integration tests, injected fakes).
    init(
        appStorage: AppStorage,
        csc: CyclingSpeedAndCadenceSensorManager,
        ftms: FitnessMachineSensorManager,
        hr: HeartRateSensorManager
    ) {
        let namespacedAppStorage = appStorage.withNamespacedKeys("Settings")
        let settingsStorage = namespacedAppStorage.asSettingsStorage()
        systemSettings = DefaultSystemSettings(storage: settingsStorage)
        metricsSettings = DefaultMetricsSettings(storage: settingsStorage)
        bluetoothSensorManager = csc
        fitnessMachineSensorManager = ftms
        heartRateSensorManager = hr
        let cscSensorProvider = CSCSensorProvider(manager: csc)
        let ftmsSensorProvider = FTMSSensorProvider(manager: ftms)
        let hrSensorProvider = HRSensorProvider(manager: hr)
        let systemAvailability = BluetoothAvailabilityAdapter.combined(
            csc: csc.bluetoothAvailability,
            ftms: ftms.bluetoothAvailability,
            hr: hr.bluetoothAvailability
        )
        compositeSensorProvider = CompositeSensorProvider(
            sensorProviders: [cscSensorProvider, ftmsSensorProvider, hrSensorProvider],
            systemAvailability: systemAvailability,
        )
    }

    init(appStorage: AppStorage) {
        let namespacedAppStorage = appStorage.withNamespacedKeys("Settings")
        let settingsStorage = namespacedAppStorage.asSettingsStorage()
        systemSettings = DefaultSystemSettings(storage: settingsStorage)
        metricsSettings = DefaultMetricsSettings(storage: settingsStorage)
        let cscStorage = namespacedAppStorage.asCyclingSpeedAndCadenceServiceStorage()
        let bluetoothSensorManager = CyclingSpeedAndCadenceSensorManager(storage: cscStorage)
        bluetoothSensorManager.reconnectDisconnectedKnownSensorsIfPoweredOn()
        self.bluetoothSensorManager = bluetoothSensorManager

        let ftmsStorage = namespacedAppStorage.asFitnessMachineServiceStorage()
        let fitnessMachineSensorManager = FitnessMachineSensorManager(storage: ftmsStorage)
        fitnessMachineSensorManager.reconnectDisconnectedKnownSensorsIfPoweredOn()
        self.fitnessMachineSensorManager = fitnessMachineSensorManager

        let hrsStorage = namespacedAppStorage.asHeartRateServiceStorage()
        let heartRateSensorManager = HeartRateSensorManager(persistence: hrsStorage)
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

    /// Full composite (integration tests, `@testable import`).
    var integrationComposite: CompositeSensorProvider { compositeSensorProvider }

    func getSettingsViewModel() -> SettingsViewModel {
        SettingsVM.SettingsViewModel(
            metricsSettings: metricsSettings,
            systemSettings: systemSettings,
            sensorAvailability: compositeSensorProvider.availability
        )
    }
}
