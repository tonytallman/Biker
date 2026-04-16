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
    private let sensorSettings: SettingsViewModel.SensorSettings
    private var cancellables: Set<AnyCancellable> = []

    package var currentSpeedUnits: UnitSpeed = .milesPerHour
    package var currentDistanceUnits: UnitLength = .miles
    package var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    package var locationBackgroundStatusText: String = ""
    package var bluetoothBackgroundStatusText: String = ""
    package var knownSensors: [SensorViewModel] = []

    package let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    package let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]

    package var keepScreenOn: Bool = true

    public init(
        metricsSettings: SettingsViewModel.MetricsSettings,
        systemSettings: SettingsViewModel.SystemSettings,
        sensorSettings: SettingsViewModel.SensorSettings,
    ) {
        self.metricsSettings = metricsSettings
        self.systemSettings = systemSettings
        self.sensorSettings = sensorSettings

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

        sensorSettings.sensors
            .sink { [weak self] sensors in
                guard let self else { return }
                self.knownSensors = sensors.map {
                    SensorViewModel(sensorID: $0.id, title: $0.name, connectionState: $0.connectionState)
                }
            }
            .store(in: &cancellables)
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

    package func scanForSensors() {
        sensorSettings.scan()
    }

    package func makeScanViewModel() -> ScanViewModel {
        ScanViewModel(sensorSettings: sensorSettings)
    }

    package func disconnectSensor(id: UUID) {
        sensorSettings.disconnect(sensorID: id)
    }

    package func forgetSensor(id: UUID) {
        sensorSettings.forget(sensorID: id)
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

    @MainActor
    public protocol SensorSettings {
        var sensors: AnyPublisher<[ConnectedSensorInfo], Never> { get }
        var discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never> { get }
        func scan()
        func stopScan()
        func connect(sensorID: UUID)
        func disconnect(sensorID: UUID)
        func forget(sensorID: UUID)
    }
}
