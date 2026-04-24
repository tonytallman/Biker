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
    private let sensorAvailabilityPublisher: AnyPublisher<SensorAvailability, Never>
    private var cancellables: Set<AnyCancellable> = []
    private var providerCancellables: Set<AnyCancellable> = []
    private var knownSensorViewModels: [UUID: SensorViewModel] = [:]
    private var lastWiredProvider: AnyObject?
    private var priorEmissionWasAvailable = false

    package var currentSpeedUnits: UnitSpeed = .milesPerHour
    package var currentDistanceUnits: UnitLength = .miles
    package var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    package var locationBackgroundStatusText: String = ""
    package var bluetoothBackgroundStatusText: String = ""
    package var knownSensors: [SensorViewModel] = []
    /// Current gating of sensor lists and the ``SensorProvider`` (ADR-0009).
    package var currentSensorAvailability: SensorAvailability = .notDetermined
    /// Set when `SensorAvailability` transitions from ``SensorAvailability/available(_:)`` to a non-ready case while the scan sheet may be open (SEN-SCAN-3).
    package var shouldDismissScanSheet: Bool = false

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
        self.sensorAvailabilityPublisher = sensorAvailability

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

        sensorAvailabilityPublisher
            .removeDuplicates()
            .sink { [weak self] value in
                self?.applySensorAvailability(value)
            }
            .store(in: &cancellables)
    }

    package var sensorsSectionState: SensorsSectionState {
        currentSensorAvailability.sensorsSectionState
    }

    private func applySensorAvailability(_ value: SensorAvailability) {
        let nowAvailable: Bool
        if case .available = value { nowAvailable = true } else { nowAvailable = false }
        if priorEmissionWasAvailable, !nowAvailable {
            shouldDismissScanSheet = true
        }
        priorEmissionWasAvailable = nowAvailable
        currentSensorAvailability = value

        if case .available(let p) = value, (p as AnyObject) === lastWiredProvider {
            return
        }

        providerCancellables.removeAll(keepingCapacity: true)
        knownSensorViewModels.removeAll(keepingCapacity: true)
        knownSensors = []
        lastWiredProvider = nil

        if case .available(let p) = value {
            lastWiredProvider = p as AnyObject
            p.knownSensors
                .sink { [weak self] sensors in
                    self?.reconcileKnownSensors(sensors)
                }
                .store(in: &providerCancellables)
        }
    }

    private func reconcileKnownSensors(_ sensors: [any Sensor]) {
        var seen = Set<UUID>()
        var ordered: [SensorViewModel] = []
        for sensor in sensors {
            let id = sensor.id
            seen.insert(id)
            if let existing = knownSensorViewModels[id] {
                existing.replaceSensorIfNeeded(sensor)
                ordered.append(existing)
            } else {
                let vm = SensorViewModel(sensor: sensor)
                knownSensorViewModels[id] = vm
                ordered.append(vm)
            }
        }
        for id in knownSensorViewModels.keys where !seen.contains(id) {
            knownSensorViewModels.removeValue(forKey: id)
        }
        knownSensors = ordered
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
        if case .available(let p) = currentSensorAvailability {
            p.scan()
        }
    }

    package func makeScanViewModel() -> ScanViewModel? {
        if case .available(let p) = currentSensorAvailability {
            return ScanViewModel(sensorProvider: p)
        }
        return nil
    }

    /// Call after the scan sheet has performed `dismiss()` in response to `shouldDismissScanSheet`.
    package func acknowledgeScanSheetDismissal() {
        shouldDismissScanSheet = false
    }

    package func disconnectSensor(id: UUID) {
        knownSensorViewModels[id]?.disconnect()
    }

    package func forgetSensor(id: UUID) {
        knownSensorViewModels[id]?.forget()
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
