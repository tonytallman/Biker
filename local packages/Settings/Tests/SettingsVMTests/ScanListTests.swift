//
//  ScanListTests.swift
//  SettingsVMTests
//

import Foundation
import Testing

import SettingsVM

@MainActor
@Suite("Scan list (SensorProvider)")
struct ScanListTests {
    @Test("Discovered rows sort by name case-insensitive ascending")
    func testDiscoveredSortOrder() {
        let mock = MockSensorProvider()
        let id1 = UUID()
        let id2 = UUID()
        let z: any Sensor = MockSensorWithRSSI(
            id: id1,
            name: "Zebra",
            type: .cyclingSpeedAndCadence,
            rssi: -50
        )
        let a: any Sensor = MockSensorWithRSSI(
            id: id2,
            name: "alpha",
            type: .cyclingSpeedAndCadence,
            rssi: -60
        )
        mock.setDiscoveredSensors([z, a])

        let scanVM = ScanViewModel(sensorProvider: mock)
        #expect(scanVM.discoveredSensors.map(\.name) == ["alpha", "Zebra"])
    }

    @Test("connect invokes sensor connect and stops scanning")
    func testConnectForwardsAndStopsScan() {
        let mock = MockSensorProvider()
        let id = UUID()
        let sensor = MockSensorWithRSSI(
            id: id,
            name: "Connectable",
            type: .cyclingSpeedAndCadence,
            rssi: -55
        )
        mock.setDiscoveredSensors([sensor])

        let scanVM = ScanViewModel(sensorProvider: mock)
        #expect(scanVM.isScanning == false)

        scanVM.startScan()
        #expect(scanVM.isScanning == true)
        #expect(mock.scanCallCount == 1)

        scanVM.connect(sensorID: id)
        #expect(sensor.connectCallCount == 1)
        #expect(scanVM.isScanning == false)
        #expect(mock.stopScanCallCount == 1)
    }

    @Test("RSSI is present only when sensor conforms to SignalStrengthReporting")
    func testRSSIPresence() {
        let mock = MockSensorProvider()
        let id1 = UUID()
        let id2 = UUID()
        let withRSSI: any Sensor = MockSensorWithRSSI(
            id: id1,
            name: "With",
            type: .cyclingSpeedAndCadence,
            rssi: -40
        )
        let plain: any Sensor = MockPlainSensor(
            id: id2,
            name: "Plain",
            type: .cyclingSpeedAndCadence
        )
        mock.setDiscoveredSensors([withRSSI, plain])

        let scanVM = ScanViewModel(sensorProvider: mock)
        let withRow = scanVM.discoveredSensors.first { $0.id == id1 }
        let plainRow = scanVM.discoveredSensors.first { $0.id == id2 }
        #expect(withRow?.rssi == -40)
        #expect(plainRow?.rssi == nil)
    }
}
