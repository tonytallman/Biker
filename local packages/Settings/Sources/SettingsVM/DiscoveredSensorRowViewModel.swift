//
//  DiscoveredSensorRowViewModel.swift
//  SettingsVM
//

import Combine
import Foundation
import Observation

@MainActor
@Observable
package final class DiscoveredSensorRowViewModel: Identifiable {
    package let id: UUID
    package let type: SensorType
    package var name: String
    /// Present only when the underlying sensor conforms to `SignalStrengthReporting`.
    package var rssi: Int?

    private let sensor: any Sensor
    private var cancellables = Set<AnyCancellable>()

    package init(sensor: any Sensor) {
        self.sensor = sensor
        self.id = sensor.id
        self.type = sensor.type
        self.name = sensor.name

        if let strength = sensor as? any SignalStrengthReporting {
            strength.rssi
                .sink { [weak self] value in
                    self?.rssi = value
                }
                .store(in: &cancellables)
        } else {
            rssi = nil
        }
    }

    /// Connects to this discovered peripheral (CSC/adapter forwards to the manager).
    package func connect() {
        sensor.connect()
    }
}
