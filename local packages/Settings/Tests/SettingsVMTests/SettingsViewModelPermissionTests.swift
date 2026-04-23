//
//  SettingsViewModelPermissionTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsVM

@MainActor
@Suite("Sensors Bluetooth availability (Phase 04)")
struct SettingsViewModelPermissionTests {
    private func makeVM(mock: MockSensorProvider) -> SettingsViewModel {
        SettingsViewModel(
            metricsSettings: DefaultMetricsSettings(storage: InMemorySettingsStorage()),
            systemSettings: DefaultSystemSettings(storage: InMemorySettingsStorage()),
            sensorProvider: mock
        )
    }

    @Test(arguments: [
        BluetoothAvailability.notDetermined,
        .denied,
        .restricted,
    ])
    func permissionBlocked_casesMapToPermissionSectionState(_ availability: BluetoothAvailability) {
        let mock = MockSensorProvider()
        mock.setBluetoothAvailability(availability)
        let vm = makeVM(mock: mock)
        #expect(vm.sensorsSectionState == .permissionBlocked)
        #expect(vm.bluetoothAvailability == availability)
    }

    @Test(arguments: [
        BluetoothAvailability.unsupported,
        .resetting,
        .poweredOff,
    ])
    func bluetoothUnavailable_casesMapToUnavailableSectionState(_ availability: BluetoothAvailability) {
        let mock = MockSensorProvider()
        mock.setBluetoothAvailability(availability)
        let vm = makeVM(mock: mock)
        #expect(vm.sensorsSectionState == .bluetoothUnavailable)
    }

    @Test func poweredOn_mapsToNormal() {
        let mock = MockSensorProvider()
        mock.setBluetoothAvailability(.poweredOn)
        let vm = makeVM(mock: mock)
        #expect(vm.sensorsSectionState == .normal)
    }

    @Test func scanForSensors_noOpWhenNotPoweredOn() {
        let mock = MockSensorProvider()
        mock.setBluetoothAvailability(.poweredOff)
        let vm = makeVM(mock: mock)
        vm.scanForSensors()
        #expect(mock.scanCallCount == 0)
    }

    @Test func scanForSensors_callsProviderWhenPoweredOn() {
        let mock = MockSensorProvider()
        mock.setBluetoothAvailability(.poweredOn)
        let vm = makeVM(mock: mock)
        vm.scanForSensors()
        #expect(mock.scanCallCount == 1)
    }

    @Test func scanViewModel_dismissesWhenLosingPoweredOn() {
        let mock = MockSensorProvider()
        mock.setBluetoothAvailability(.poweredOn)
        let scanVM = ScanViewModel(sensorProvider: mock)
        #expect(scanVM.shouldDismissScanSheet == false)

        mock.setBluetoothAvailability(.denied)
        #expect(scanVM.shouldDismissScanSheet == true)
        scanVM.acknowledgeScanSheetDismissal()
        #expect(scanVM.shouldDismissScanSheet == false)
    }
}
