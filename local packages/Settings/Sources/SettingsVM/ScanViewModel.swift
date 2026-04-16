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
    package var discoveredSensors: [DiscoveredSensorInfo] = []
    package var isScanning: Bool = false

    private let sensorSettings: SettingsViewModel.SensorSettings
    private var cancellables: Set<AnyCancellable> = []

    package init(sensorSettings: SettingsViewModel.SensorSettings) {
        self.sensorSettings = sensorSettings

        sensorSettings.discoveredSensors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sensors in
                self?.discoveredSensors = sensors
            }
            .store(in: &cancellables)
    }

    package func startScan() {
        isScanning = true
        sensorSettings.scan()
    }

    package func stopScan() {
        isScanning = false
        sensorSettings.stopScan()
    }

    package func connect(sensorID: UUID) {
        sensorSettings.connect(sensorID: sensorID)
        stopScan()
    }
}
