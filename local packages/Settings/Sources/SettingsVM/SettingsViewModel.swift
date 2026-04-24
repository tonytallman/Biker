//
//  SettingsViewModel.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation
import Observation

/// Base class for settings view models.
@MainActor
@Observable
open class SettingsViewModel {

    private let metricsSettings: SettingsViewModel.MetricsSettings
    private let systemSettings: SettingsViewModel.SystemSettings
    private var cancellables: Set<AnyCancellable> = []

    /// Sensors list, scan, and sensor details (BLE / ``SensorProvider``).
    package let sensorsSection: SensorsSectionViewModel

    package var currentSpeedUnits: UnitSpeed = .milesPerHour
    package var currentDistanceUnits: UnitLength = .miles
    package var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    package var locationBackgroundStatusText: String = ""
    package var bluetoothBackgroundStatusText: String = ""

    package let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    package let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]

    package var keepScreenOn: Bool = true

    public init(
        metricsSettings: SettingsViewModel.MetricsSettings,
        systemSettings: SettingsViewModel.SystemSettings,
        sensorAvailability: AnyPublisher<SensorAvailability, Never>
    ) {
        self.metricsSettings = metricsSettings
        self.systemSettings = systemSettings
        self.sensorsSection = SensorsSectionViewModel(sensorAvailability: sensorAvailability)

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

extension SettingsViewModel {
    public protocol MetricsSettings {
        var speedUnits: any Subject<UnitSpeed, Never> { get }
        var distanceUnits: any Subject<UnitLength, Never> { get }
        var autoPauseThreshold: any Subject<Measurement<UnitSpeed>, Never> { get }
    }

    @MainActor
    public protocol SystemSettings {
        var keepScreenOn: any Subject<Bool, Never> { get }
        var willEnterForeground: AnyPublisher<Void, Never> { get }
        var locationBackgroundStatus: String { get }
        var bluetoothBackgroundStatus: String { get }
        func openPermissions()
        func setIdleTimerDisabled(_ disabled: Bool)
    }
}
