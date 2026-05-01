//
//  SensorDetailsViewModelTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsStrings
import SettingsVM

@MainActor
@Suite("Sensor details (SensorDetailsViewModel)")
struct SensorDetailsViewModelTests {
    @Test("Wheel diameter is nil for sensors without WheelDiameterAdjustable")
    func testWheelDiameterNilForPlainSensor() {
        let sensor = MockPlainSensor(
            id: UUID(),
            name: "HR HRM",
            type: .heartRate
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        #expect(vm.wheelDiameter == nil)
    }

    @Test("Wheel diameter is present and round-trips for WheelDiameterAdjustable")
    func testWheelDiameterPresentAndRoundTrips() {
        let id = UUID()
        let expected = Measurement(value: 700, unit: UnitLength.millimeters)
        let sensor = MockSensorWithWheel(
            id: id,
            name: "CSC",
            type: .cyclingSpeedAndCadence,
            wheelDiameter: expected
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        #expect(vm.wheelDiameter == expected)

        let newDiameter = Measurement(value: 0.75, unit: UnitLength.meters)
        vm.setWheelDiameter(newDiameter)
        #expect(sensor.setWheelDiameterCallCount == 1)
        #expect(sensor.lastSetWheelDiameter == newDiameter)
        #expect(vm.wheelDiameter == newDiameter)
    }

    @Test("Connection state and enabled flag track sensor publishers")
    func testConnectionStateAndEnabledReactive() {
        let id = UUID()
        let sensor = MockPlainSensor(
            id: id,
            name: "Reactive",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected,
            isEnabled: true
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        #expect(vm.connectionState == .disconnected)
        #expect(vm.isEnabled == true)

        sensor.connectionStateValue = .connecting
        #expect(vm.connectionState == .connecting)

        sensor.isEnabledValue = false
        #expect(vm.isEnabled == false)
    }

    @Test("Toggle, connect, and disconnect forward to the sensor")
    func testActionsForward() {
        let id = UUID()
        let sensor = MockPlainSensor(
            id: id,
            name: "Actions",
            type: .cyclingSpeedAndCadence
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        vm.connect()
        #expect(sensor.connectCallCount == 1)
        vm.disconnect()
        #expect(sensor.disconnectCallCount == 1)
        sensor.isEnabledValue = true
        vm.toggleEnabled()
        #expect(sensor.setEnabledCallCount == 1)
        #expect(sensor.lastSetEnabledValue == false)
    }

    @Test("Forget calls sensor, sets shouldDismiss, and runs dismiss callback")
    func testForget() {
        let id = UUID()
        let sensor = MockPlainSensor(
            id: id,
            name: "Gone",
            type: .cyclingSpeedAndCadence
        )
        var dismissCount = 0
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: { dismissCount += 1 })
        #expect(vm.shouldDismiss == false)
        vm.forget()
        #expect(sensor.forgetCallCount == 1)
        #expect(vm.shouldDismiss == true)
        #expect(dismissCount == 1)
    }

    @Test("acknowledgeDismissal clears shouldDismiss")
    func testAcknowledgeDismissal() {
        let sensor = MockPlainSensor(
            id: UUID(),
            name: "Gone",
            type: .cyclingSpeedAndCadence
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        vm.forget()
        #expect(vm.shouldDismiss == true)
        vm.acknowledgeDismissal()
        #expect(vm.shouldDismiss == false)
    }

    @Test("statusText is Disabled when sensor is off regardless of BLE state")
    func testStatusTextDisabled() {
        let sensor = MockPlainSensor(
            id: UUID(),
            name: "HR",
            type: .heartRate,
            connectionState: .connected,
            isEnabled: false
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        let expectedDisabled = String(
            localized: "Sensor.Status.Disabled",
            bundle: .settingsStrings,
            comment: "BLE sensor is disabled in settings (not used for auto-connect or metrics)"
        )
        #expect(vm.statusText == expectedDisabled)
    }

    @Test("statusText mirrors connection state when enabled")
    func testStatusTextWhenEnabled() {
        let sensor = MockPlainSensor(
            id: UUID(),
            name: "HR",
            type: .heartRate,
            connectionState: .connecting,
            isEnabled: true
        )
        let vm = SensorDetailsViewModel(sensor: sensor, dismiss: {})
        #expect(vm.statusText == SensorConnectionState.connecting.localizedStatusText)
    }

    @Test("SensorViewModel statusText matches details when disabled")
    func testSensorViewModelStatusTextDisabled() {
        let sensor = MockPlainSensor(
            id: UUID(),
            name: "Row",
            type: .heartRate,
            connectionState: .connected,
            isEnabled: false
        )
        let row = SensorViewModel(sensor: sensor)
        let expectedDisabled = String(
            localized: "Sensor.Status.Disabled",
            bundle: .settingsStrings,
            comment: "BLE sensor is disabled in settings (not used for auto-connect or metrics)"
        )
        #expect(row.statusText == expectedDisabled)
    }
}
