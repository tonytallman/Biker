//
//  ScanViewModel.swift
//  SettingsVM
//

import Combine
import Foundation
import Observation

@MainActor
@Observable
package final class ScanViewModel {
    package var discoveredSensors: [DiscoveredSensorRowViewModel] = []
    package var isScanning: Bool = false

    private let sensorProvider: any SensorProvider
    private var cancellables: Set<AnyCancellable> = []

    package init(sensorProvider: any SensorProvider) {
        self.sensorProvider = sensorProvider

        // Avoid `receive(on:)` so `@MainActor` + `CurrentValueSubject` from tests and the provider
        // can update rows synchronously; `SensorProvider` is main-actor-only.
        sensorProvider.discoveredSensors
            .sink { [weak self] sensors in
                self?.rebuildRows(from: sensors)
            }
            .store(in: &cancellables)
    }

    /// Preserves `SensorProvider` order — global scan ordering (SEN-SCAN-7/8) is applied in `CompositeSensorProvider`.
    private func rebuildRows(from sensors: [any Sensor]) {
        discoveredSensors = sensors.map { DiscoveredSensorRowViewModel(sensor: $0) }
    }

    package func startScan() {
        isScanning = true
        sensorProvider.scan()
    }

    package func stopScan() {
        isScanning = false
        sensorProvider.stopScan()
    }

    package func connect(sensorID: UUID) {
        if let row = discoveredSensors.first(where: { $0.id == sensorID }) {
            row.connect()
        }
        stopScan()
    }
}
