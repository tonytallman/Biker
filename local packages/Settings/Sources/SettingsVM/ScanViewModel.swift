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
    /// True when `BluetoothAvailability` allows scanning (`.poweredOn`).
    package var isBluetoothScanAllowed: Bool = true
    /// Set when availability transitions from `.poweredOn` to another value while the sheet may be open (SEN-SCAN-3).
    package var shouldDismissScanSheet: Bool = false

    private let sensorProvider: any SensorProvider
    private var cancellables: Set<AnyCancellable> = []
    private var lastBluetoothAvailability: BluetoothAvailability?

    package init(sensorProvider: any SensorProvider) {
        self.sensorProvider = sensorProvider

        // Avoid `receive(on:)` so `@MainActor` + `CurrentValueSubject` from tests and the provider
        // can update rows synchronously; `SensorProvider` is main-actor-only.
        sensorProvider.discoveredSensors
            .sink { [weak self] sensors in
                self?.rebuildRows(from: sensors)
            }
            .store(in: &cancellables)

        sensorProvider.bluetoothAvailability
            .removeDuplicates()
            .sink { [weak self] availability in
                self?.applyBluetoothAvailability(availability)
            }
            .store(in: &cancellables)
    }

    private func applyBluetoothAvailability(_ availability: BluetoothAvailability) {
        let wasPoweredOn = lastBluetoothAvailability == .poweredOn
        let isPoweredOn = availability == .poweredOn
        lastBluetoothAvailability = availability

        isBluetoothScanAllowed = isPoweredOn
        if !isPoweredOn {
            stopScan()
        }
        if wasPoweredOn && !isPoweredOn {
            shouldDismissScanSheet = true
        }
    }

    private func rebuildRows(from sensors: [any Sensor]) {
        let sorted = sensors.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        discoveredSensors = sorted.map { DiscoveredSensorRowViewModel(sensor: $0) }
    }

    package func startScan() {
        guard isBluetoothScanAllowed else { return }
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

    /// Call after the scan sheet has performed `dismiss()` in response to `shouldDismissScanSheet`.
    package func acknowledgeScanSheetDismissal() {
        shouldDismissScanSheet = false
    }
}
