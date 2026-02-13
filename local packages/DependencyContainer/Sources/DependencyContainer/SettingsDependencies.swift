//
//  SettingsDependencies.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 2/13/26.
//

import SettingsModel
import SettingsVM

@MainActor
final class SettingsDependencies {
    private let systemSettings: SystemSettings
    let metricsSettings: DefaultMetricsSettings

    init(appStorage: AppStorage) {
        let settingsStorage = appStorage
            .withNamespacedKeys("Settings")
            .asSettingsStorage()
        systemSettings = DefaultSystemSettings(storage: settingsStorage)
        metricsSettings = DefaultMetricsSettings(storage: settingsStorage)
    }
    
    func getSettingsViewModel() -> SettingsViewModel {
        SettingsVM.SettingsViewModel(metricsSettings: metricsSettings, systemSettings: systemSettings)
    }
}
