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
    @Test("Discovered rows preserve SensorProvider order (ordering is owned by CompositeSensorProvider)")
    func testDiscoveredPreservesProviderOrder() {
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
        #expect(scanVM.discoveredSensors.map(\.name) == ["Zebra", "alpha"])
    }

    @Test("discovered rows expose sensor type for scan-list icons (#37)")
    func testDiscoveredRowsExposeSensorType() {
        let mock = MockSensorProvider()
        let idCSC = UUID()
        let idFTMS = UUID()
        let idHR = UUID()
        let csc: any Sensor = MockSensorWithRSSI(
            id: idCSC,
            name: "Outdoor",
            type: .cyclingSpeedAndCadence,
            rssi: -50
        )
        let ftms: any Sensor = MockSensorWithRSSI(
            id: idFTMS,
            name: "Indoor",
            type: .fitnessMachine,
            rssi: -55
        )
        let hr: any Sensor = MockSensorWithRSSI(
            id: idHR,
            name: "Pulse",
            type: .heartRate,
            rssi: -60
        )
        mock.setDiscoveredSensors([csc, ftms, hr])

        let scanVM = ScanViewModel(sensorProvider: mock)
        #expect(scanVM.discoveredSensors.count == 3)

        let byId = Dictionary(uniqueKeysWithValues: scanVM.discoveredSensors.map { ($0.id.sensorID, $0.type) })
        #expect(byId[idCSC] == .cyclingSpeedAndCadence)
        #expect(byId[idFTMS] == .fitnessMachine)
        #expect(byId[idHR] == .heartRate)
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

        scanVM.connect(rowID: SensorRowID(sensorID: id, type: .cyclingSpeedAndCadence))
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
        let withRow = scanVM.discoveredSensors.first { $0.id.sensorID == id1 }
        let plainRow = scanVM.discoveredSensors.first { $0.id.sensorID == id2 }
        #expect(withRow?.rssi == -40)
        #expect(plainRow?.rssi == nil)
    }

    @Test("same peripheral UUID with CSC and FTMS yields two rows; connect targets one adapter (ADR-0011)")
    func testSamePeripheralTwoProtocolsScanRows() {
        let mock = MockSensorProvider()
        let shared = UUID()
        let csc: any Sensor = MockSensorWithRSSI(
            id: shared,
            name: "IC Bike",
            type: .cyclingSpeedAndCadence,
            rssi: -50
        )
        let ftms: any Sensor = MockSensorWithRSSI(
            id: shared,
            name: "IC Bike",
            type: .fitnessMachine,
            rssi: -51
        )
        mock.setDiscoveredSensors([csc, ftms])

        let scanVM = ScanViewModel(sensorProvider: mock)
        #expect(scanVM.discoveredSensors.count == 2)
        #expect(Set(scanVM.discoveredSensors.map(\.id)).count == 2)
        #expect(Set(scanVM.discoveredSensors.map(\.type)) == Set([.cyclingSpeedAndCadence, .fitnessMachine]))

        scanVM.connect(rowID: SensorRowID(sensorID: shared, type: .fitnessMachine))
        #expect(ftms.connectCallCount == 1)
        #expect(csc.connectCallCount == 0)
    }
}
