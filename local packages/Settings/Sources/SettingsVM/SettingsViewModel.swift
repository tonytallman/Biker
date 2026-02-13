//
//  SettingsViewModel.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import CoreBluetooth
import CoreLocation
import Foundation
import Observation

import SettingsModel

/// Base class for settings view models.
@MainActor
@Observable
open class SettingsViewModel {

    private let metricsSettings: MetricsSettings
    private let systemSettings: SystemSettings
    private var cancellables: Set<AnyCancellable> = []
    
    package var currentSpeedUnits: UnitSpeed = .milesPerHour
    package var currentDistanceUnits: UnitLength = .miles
    package var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    package var locationBackgroundStatusText: String = ""
    package var bluetoothBackgroundStatusText: String = ""
    
    package let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    package let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]

    package var keepScreenOn: Bool = true
    
    public init(
        metricsSettings: MetricsSettings,
        systemSettings: SystemSettings,
    ) {
        self.metricsSettings = metricsSettings
        self.systemSettings = systemSettings
        
        // Subscribe to settings changes
        metricsSettings.speedUnits
            .sink { [weak self] units in
                guard let self else { return }
                self.currentSpeedUnits = units
            }
            .store(in: &cancellables)
        
        metricsSettings.distanceUnits
            .sink { [weak self] units in
                guard let self else { return }
                self.currentDistanceUnits = units
            }
            .store(in: &cancellables)
        
        metricsSettings.autoPauseThreshold
            .sink { [weak self] threshold in
                guard let self else { return }
                self.currentAutoPauseThreshold = threshold
            }
            .store(in: &cancellables)
        
        systemSettings.keepScreenOn
            .sink { [weak self] keepOn in
                guard let self else { return }
                self.keepScreenOn = keepOn
                self.systemSettings.setIdleTimerDisabled(keepOn)
            }
            .store(in: &cancellables)
        
        // Subscribe to foreground notification to refresh statuses when returning from Settings
        systemSettings.willEnterForeground
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshBackgroundStatuses()
            }
            .store(in: &cancellables)
        
        // Initial refresh of background statuses
        refreshBackgroundStatuses()
    }
    
    package func setSpeedUnits(_ units: UnitSpeed) {
        metricsSettings.speedUnits.send(units)
    }
    
    package func setDistanceUnits(_ units: UnitLength) {
        metricsSettings.distanceUnits.send(units)
    }
    
    package func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>) {
        metricsSettings.autoPauseThreshold.send(threshold)
    }
    
    package func setKeepScreenOn(_ keepOn: Bool) {
        systemSettings.keepScreenOn.send(keepOn)
    }
    
    package func openBluetoothPermissions() {
        systemSettings.openPermissions()
    }
    
    package func openLocationPermissions() {
        systemSettings.openPermissions()
    }
    
    package func refreshBackgroundStatuses() {
        locationBackgroundStatusText = systemSettings.locationBackgroundStatus
        bluetoothBackgroundStatusText = systemSettings.bluetoothBackgroundStatus
    }
}
