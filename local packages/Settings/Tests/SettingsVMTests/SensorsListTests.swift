//
//  SensorsListTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsVM

@MainActor
@Suite("Sensors list (SensorProvider)")
struct SensorsListTests {
    @Test("SettingsViewModel maps known sensors from provider")
    func testKnownSensorsFromProvider() {
        let storage = InMemorySettingsStorage()
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let sensor: any Sensor = MockPlainSensor(
            id: id,
            name: "Test CSC",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        mock.provider.setKnownSensors([sensor])

        let viewModel = SettingsViewModel(
            metricsSettings: DefaultMetricsSettings(storage: storage),
            systemSettings: DefaultSystemSettings(storage: storage),
            sensorAvailability: mock.publisher
        )

        #expect(viewModel.knownSensors.count == 1)
        #expect(viewModel.knownSensors.first?.title == "Test CSC")
        #expect(viewModel.knownSensors.first?.sensorID == id)
    }

    @Test("Per-row connection state updates when mock sensor publishes")
    func testConnectionStateReactive() {
        let storage = InMemorySettingsStorage()
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let plain = MockPlainSensor(
            id: id,
            name: "Reactive",
            type: .cyclingSpeedAndCadence,
            connectionState: .disconnected
        )
        mock.provider.setKnownSensors([plain])

        let viewModel = SettingsViewModel(
            metricsSettings: DefaultMetricsSettings(storage: storage),
            systemSettings: DefaultSystemSettings(storage: storage),
            sensorAvailability: mock.publisher
        )

        #expect(viewModel.knownSensors.first?.connectionState == .disconnected)

        plain.connectionStateValue = .connecting
        #expect(viewModel.knownSensors.first?.connectionState == .connecting)

        plain.connectionStateValue = .connected
        #expect(viewModel.knownSensors.first?.connectionState == .connected)
    }

    @Test("disconnectSensor and forgetSensor forward to the mock sensor")
    func testDisconnectAndForgetForward() {
        let storage = InMemorySettingsStorage()
        let mock = MockSensorAvailability(initialBluetooth: .poweredOn)
        let id = UUID()
        let plain = MockPlainSensor(
            id: id,
            name: "Actionable",
            type: .cyclingSpeedAndCadence
        )
        mock.provider.setKnownSensors([plain])

        let viewModel = SettingsViewModel(
            metricsSettings: DefaultMetricsSettings(storage: storage),
            systemSettings: DefaultSystemSettings(storage: storage),
            sensorAvailability: mock.publisher
        )

        viewModel.disconnectSensor(id: id)
        #expect(plain.disconnectCallCount == 1)

        viewModel.forgetSensor(id: id)
        #expect(plain.forgetCallCount == 1)
    }
}
