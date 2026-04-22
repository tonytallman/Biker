//
//  SensorViewModel.swift
//  Settings
//

import Combine
import Foundation
import Observation

@MainActor
@Observable
package final class SensorViewModel {
    package let sensorID: UUID
    package var title: String
    package var connectionState: SensorConnectionState
    package var isEnabled: Bool

    private var sensor: any Sensor
    private var cancellables = Set<AnyCancellable>()

    package init(sensor: any Sensor) {
        self.sensor = sensor
        self.sensorID = sensor.id
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
