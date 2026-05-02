//
//  SensorViewModel.swift
//  Settings
//

import Combine
import Foundation
import Observation
import SettingsStrings

@MainActor
@Observable
package final class SensorViewModel {
    package let sensorID: UUID
    package let type: SensorType
    /// Row key for lists and navigation when one peripheral advertises multiple services (ADR-0011).
    package var rowID: SensorRowID { SensorRowID(sensorID: sensorID, type: type) }
    package var title: String
    package var connectionState: SensorConnectionState
    package var isEnabled: Bool

    /// Human-readable status for list rows; includes "Disabled" when the sensor is off (BLE state is separate).
    package var statusText: String {
        if !isEnabled {
            return String(
                localized: "Sensor.Status.Disabled",
                bundle: .settingsStrings,
                comment: "BLE sensor is disabled in settings (not used for auto-connect or metrics)"
            )
        }
        return connectionState.localizedStatusText
    }

    /// The current ``Sensor`` from the app’s sensor provider (same id until replaced).
    package var sensor: any Sensor
    private var cancellables = Set<AnyCancellable>()

    package init(sensor: any Sensor) {
        self.sensor = sensor
        self.sensorID = sensor.id
        self.type = sensor.type
        self.title = sensor.name
        self.connectionState = .disconnected
        self.isEnabled = true
        bind()
    }

    private func bind() {
        cancellables.removeAll()
        title = sensor.name
        sensor.connectionState
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
        sensor.isEnabled
            .sink { [weak self] on in
                self?.isEnabled = on
            }
            .store(in: &cancellables)
    }

    /// When the provider emits a new `any Sensor` for the same id, rebind streams.
    package func replaceSensorIfNeeded(_ newSensor: any Sensor) {
        guard newSensor.id == sensorID else { return }
        guard newSensor.type == type else { return }
        guard ObjectIdentifier(newSensor as AnyObject) != ObjectIdentifier(sensor as AnyObject) else { return }
        sensor = newSensor
        bind()
    }

    package func disconnect() {
        sensor.disconnect()
    }

    package func forget() {
        sensor.forget()
    }

    package func setEnabled(_ enabled: Bool) {
        sensor.setEnabled(enabled)
    }
}
