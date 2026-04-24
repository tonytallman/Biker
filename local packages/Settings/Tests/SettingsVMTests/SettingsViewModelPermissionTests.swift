//
//  SettingsViewModelPermissionTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsVM

@MainActor
@Suite("Sensors SensorAvailability (ADR-0009)")
struct SettingsViewModelPermissionTests {
    private func makeVM(mockAvailability: MockSensorAvailability) -> SettingsViewModel {
        SettingsViewModel(
            metricsSettings: DefaultMetricsSettings(storage: InMemorySettingsStorage()),
            systemSettings: DefaultSystemSettings(storage: InMemorySettingsStorage()),
            sensorAvailability: mockAvailability.publisher
        )
    }

    @Test(arguments: [
        BluetoothAvailability.notDetermined,
        .denied,
        .restricted,
    ])
    func permissionBlocked_casesMapToPermissionSectionState(_ radio: BluetoothAvailability) {
        let mock = MockSensorAvailability(initialBluetooth: radio)
        let vm = makeVM(mockAvailability: mock)
        #expect(vm.sensorsSectionState == .permissionBlocked)
    }

    @Test(arguments: [
        BluetoothAvailability.unsupported,
        .resetting,
        .poweredOff,
    ])
    func bluetoothUnavailable_casesMapToUnavailableSectionState(_ radio: BluetoothAvailability) {
        let mock = MockSensorAvailability(initialBluetooth: radio)
        let vm = makeVM(mockAvailability: mock)
        #expect(vm.sensorsSectionState == .bluetoothUnavailable)
    }

    @Test func poweredOn_mapsToNormal() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let vm = makeVM(mockAvailability: mock)
        #expect(vm.sensorsSectionState == .normal)
    }

    @Test func scanForSensors_noOpWhenNotPoweredOn() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOff)
        let vm = makeVM(mockAvailability: mock)
        vm.scanForSensors()
        #expect(mock.provider.scanCallCount == 0)
    }

    @Test func scanForSensors_callsProviderWhenPoweredOn() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let vm = makeVM(mockAvailability: mock)
        vm.scanForSensors()
        #expect(mock.provider.scanCallCount == 1)
    }

    @Test func settingsViewModel_dismissesScanWhenLosingPoweredOn() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let vm = makeVM(mockAvailability: mock)
        #expect(vm.shouldDismissScanSheet == false)

        mock.setBluetoothRadio(.denied)
        #expect(vm.shouldDismissScanSheet == true)
        vm.acknowledgeScanSheetDismissal()
        #expect(vm.shouldDismissScanSheet == false)
    }

    @Test func knownSensorsClearedWhenLeavingAvailable() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let sensor: any Sensor = MockPlainSensor(
            id: id,
            name: "Gone",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        mock.provider.setKnownSensors([sensor])
        let vm = makeVM(mockAvailability: mock)
        #expect(vm.knownSensors.count == 1)

        mock.setBluetoothRadio(.poweredOff)
        #expect(vm.knownSensors.isEmpty)
    }
}
