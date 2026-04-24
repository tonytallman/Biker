//
//  SensorsSectionViewModel.swift
//  SettingsVM
//

import Combine
import Foundation
import Observation

/// Owns known-sensor list state, ``SensorAvailability`` gating, scan, and sensor actions (ADR-0009).
@MainActor
@Observable
package final class SensorsSectionViewModel {
    private let sensorAvailabilityPublisher: AnyPublisher<SensorAvailability, Never>
    private var cancellables: Set<AnyCancellable> = []
    private var providerCancellables: Set<AnyCancellable> = []
    private var knownSensorViewModels: [UUID: SensorViewModel] = [:]
    private var lastWiredProvider: AnyObject?
    private var priorEmissionWasAvailable = false

    package private(set) var knownSensors: [SensorViewModel] = []
    /// Current gating of sensor lists and the ``SensorProvider`` (ADR-0009).
    package private(set) var currentSensorAvailability: SensorAvailability = .notDetermined
    /// Set when `SensorAvailability` transitions from ``SensorAvailability/available(_:)`` to a non-ready case while the scan sheet may be open (SEN-SCAN-3).
    package private(set) var shouldDismissScanSheet: Bool = false

    package var sensorsSectionState: SensorsSectionState {
        currentSensorAvailability.sensorsSectionState
    }

    package init(sensorAvailability: AnyPublisher<SensorAvailability, Never>) {
        self.sensorAvailabilityPublisher = sensorAvailability

        sensorAvailabilityPublisher
            .removeDuplicates()
            .sink { [weak self] value in
                self?.applySensorAvailability(value)
            }
            .store(in: &cancellables)
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

    /// Builds a details view model for a known sensor; returns nil if the id is not in the list.
    package func makeSensorDetailsViewModel(for id: UUID, dismiss: @escaping () -> Void) -> SensorDetailsViewModel? {
        guard let row = knownSensorViewModels[id] else { return nil }
        return SensorDetailsViewModel(sensor: row.sensor, dismiss: dismiss)
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
