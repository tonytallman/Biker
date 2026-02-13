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
    
    public var currentSpeedUnits: UnitSpeed = .milesPerHour
    public var currentDistanceUnits: UnitLength = .miles
    public var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    public var locationBackgroundStatusText: String = ""
    public var bluetoothBackgroundStatusText: String = ""
    
    public let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    public let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]

    public var keepScreenOn: Bool = true

    public convenience init(metricsSettings: MetricsSettings, storage: SettingsStorage) {
        self.init(
            metricsSettings: metricsSettings,
            systemSettings: DefaultSystemSettings(storage: storage),
        )
    }
    
    package init(
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
    
    public func setSpeedUnits(_ units: UnitSpeed) {
        metricsSettings.speedUnits.send(units)
    }
    
    public func setDistanceUnits(_ units: UnitLength) {
        metricsSettings.distanceUnits.send(units)
    }
    
    public func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>) {
        metricsSettings.autoPauseThreshold.send(threshold)
    }
    
    public func setKeepScreenOn(_ keepOn: Bool) {
        systemSettings.keepScreenOn.send(keepOn)
    }
    
    public func openBluetoothPermissions() {
        systemSettings.openPermissions()
    }
    
    public func openLocationPermissions() {
        systemSettings.openPermissions()
    }
    
    public func refreshBackgroundStatuses() {
        locationBackgroundStatusText = systemSettings.locationBackgroundStatus
        bluetoothBackgroundStatusText = systemSettings.bluetoothBackgroundStatus
    }
}
