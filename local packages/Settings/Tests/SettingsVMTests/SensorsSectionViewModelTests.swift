//
//  SensorsSectionViewModelTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsVM

@MainActor
@Suite("Sensors section (SensorsSectionViewModel + SensorProvider)")
struct SensorsSectionViewModelTests {
    private func makeSectionVM(mockAvailability: MockSensorAvailability) -> SensorsSectionViewModel {
        SensorsSectionViewModel(sensorAvailability: mockAvailability.publisher)
    }

    // MARK: - ADR-0009 / SensorAvailability

    @Test(arguments: [
        BluetoothAvailability.notDetermined,
        .denied,
        .restricted,
    ])
    func permissionBlocked_casesMapToPermissionSectionState(_ radio: BluetoothAvailability) {
        let mock = MockSensorAvailability(initialBluetooth: radio)
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.sensorsSectionState == .permissionBlocked)
    }

    @Test(arguments: [
        BluetoothAvailability.unsupported,
        .resetting,
        .poweredOff,
    ])
    func bluetoothUnavailable_casesMapToUnavailableSectionState(_ radio: BluetoothAvailability) {
        let mock = MockSensorAvailability(initialBluetooth: radio)
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.sensorsSectionState == .bluetoothUnavailable)
    }

    @Test func poweredOn_mapsToNormal() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.sensorsSectionState == .normal)
    }

    @Test func scanForSensors_noOpWhenNotPoweredOn() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOff)
        let section = makeSectionVM(mockAvailability: mock)
        section.scanForSensors()
        #expect(mock.provider.scanCallCount == 0)
    }

    @Test func scanForSensors_callsProviderWhenPoweredOn() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let section = makeSectionVM(mockAvailability: mock)
        section.scanForSensors()
        #expect(mock.provider.scanCallCount == 1)
    }

    @Test func shouldDismissScanSheetWhenLosingAvailable() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.shouldDismissScanSheet == false)

        mock.setBluetoothRadio(.denied)
        #expect(section.shouldDismissScanSheet == true)
        section.acknowledgeScanSheetDismissal()
        #expect(section.shouldDismissScanSheet == false)
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
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.knownSensors.count == 1)

        mock.setBluetoothRadio(.poweredOff)
        #expect(section.knownSensors.isEmpty)
    }

    // MARK: - Known list (SensorProvider)

    @Test("known sensors are mapped from provider")
    func testKnownSensorsFromProvider() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let sensor: any Sensor = MockPlainSensor(
            id: id,
            name: "Test CSC",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        mock.provider.setKnownSensors([sensor])

        let section = makeSectionVM(mockAvailability: mock)

        #expect(section.knownSensors.count == 1)
        #expect(section.knownSensors.first?.title == "Test CSC")
        #expect(section.knownSensors.first?.sensorID == id)
    }

    @Test("per-row connection state updates when mock sensor publishes")
    func testConnectionStateReactive() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let plain = MockPlainSensor(
            id: id,
            name: "Reactive",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        mock.provider.setKnownSensors([plain])

        let section = makeSectionVM(mockAvailability: mock)

        #expect(section.knownSensors.first?.connectionState == .disconnected)

        plain.connectionStateValue = .connecting
        #expect(section.knownSensors.first?.connectionState == .connecting)

        plain.connectionStateValue = .connected
        #expect(section.knownSensors.first?.connectionState == .connected)
    }

    @Test("disconnectSensor and forgetSensor forward to the mock sensor")
    func testDisconnectAndForgetForward() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let plain = MockPlainSensor(
            id: id,
            name: "Actionable",
            type: .cyclingSpeedAndCadence
        )
        mock.provider.setKnownSensors([plain])

        let section = makeSectionVM(mockAvailability: mock)

        section.disconnectSensor(id: id)
        #expect(plain.disconnectCallCount == 1)

        section.forgetSensor(id: id)
        #expect(plain.forgetCallCount == 1)
    }

    @Test("by default, known list is empty")
    func testKnownSensorsEmptyByDefault() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.knownSensors.isEmpty)
    }

    @Test("scan for sensors does not change known list")
    func testScanForSensorsDoesNotChangeKnownList() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let sensor: any Sensor = MockPlainSensor(
            id: id,
            name: "Speed Sensor",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        mock.provider.setKnownSensors([sensor])
        let section = makeSectionVM(mockAvailability: mock)
        #expect(section.knownSensors.map(\.title) == ["Speed Sensor"])

        section.scanForSensors()

        #expect(section.knownSensors.map(\.title) == ["Speed Sensor"])
        #expect(mock.provider.scanCallCount == 1)
    }

    // MARK: - makeSensorDetailsViewModel (factory from known list)

    @Test("makeSensorDetailsViewModel returns a VM for a known id and nil for unknown")
    func testMakeSensorDetailsViewModel() {
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let sensor: any Sensor = MockPlainSensor(
            id: id,
            name: "Listed",
            type: .cyclingSpeedAndCadence
        )
        mock.provider.setKnownSensors([sensor])

        let section = makeSectionVM(mockAvailability: mock)

        #expect(section.knownSensors.count == 1)
        var dismissCalls = 0
        let details = section.makeSensorDetailsViewModel(for: id) {
            dismissCalls += 1
        }
        #expect(details != nil)
        details?.forget()
        #expect(dismissCalls == 1)
        #expect(details?.name == "Listed")
        #expect(
            section.makeSensorDetailsViewModel(
                for: UUID(uuidString: "00000000-0000-0000-0000-00000000DEAD")!,
                dismiss: {}
            ) == nil
        )
    }
}
