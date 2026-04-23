//
//  CyclingSpeedAndCadenceSensorManagerAvailabilityTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

@MainActor
private final class InMemoryCSCPersistence: CSCKnownSensorPersistence {
    var records: [CSCKnownSensorRecord] = []

    init(records: [CSCKnownSensorRecord] = []) {
        self.records = records
    }

    func loadRecords() -> [CSCKnownSensorRecord] { records }
    func saveRecords(_ records: [CSCKnownSensorRecord]) {
        self.records = records
    }
}

@MainActor
struct CyclingSpeedAndCadenceSensorManagerAvailabilityTests {
    @Test func poweredOffToPoweredOn_reconnectsEnabledDisconnectedKnownSensor() {
        let id = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeCSCPeripheral(identifier: id, name: "S")

        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(
                id: id,
                name: "S",
                isEnabled: true,
                wheelDiameterMeters: 0.67
            ),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == id)
    }

    @Test func poweredOn_doesNotReconnectWhenSensorDisabled() {
        let id = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeCSCPeripheral(identifier: id, name: "S")

        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(
                id: id,
                name: "S",
                isEnabled: false,
                wheelDiameterMeters: 0.67
            ),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.connectCallCount == 0)
    }

    @Test func poweredOnToDenied_stopsScanAndDisconnectsAllKnownSensors() {
        let id = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOn,
            authorization: .allowedAlways
        )
        let p = InMemoryCSCPersistence()
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "A",
            initialConnectionState: .connected
        )
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        m._test_registerSensor(s)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        m.startScan()
        #expect(fake.scanForPeripheralsCallCount == 1)

        fake.simulate(authorization: .denied, state: .poweredOn)

        #expect(fake.stopScanCallCount >= 1)
        #expect(s.connectedSensorSnapshot.connectionState == .disconnected)
    }

    @Test func poweredOnToPoweredOff_disconnectsAll_reconnectsWhenBackToPoweredOn() {
        let id = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOn,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeCSCPeripheral(identifier: id, name: "S")
        let p = InMemoryCSCPersistence()
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: "A",
            initialConnectionState: .connected
        )
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        m._test_registerSensor(s)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOff)
        #expect(s.connectedSensorSnapshot.connectionState == .disconnected)
        #expect(fake.connectCallCount == 0)

        fake.resetCallCounts()
        fake.simulate(authorization: .allowedAlways, state: .poweredOn)
        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == id)
    }

    @Test func notDetermined_startScanIsNoOp() {
        let fake = FakeCSCCentral(
            state: .unknown,
            authorization: .notDetermined
        )
        let m = CyclingSpeedAndCadenceSensorManager(
            persistence: InMemoryCSCPersistence(),
            central: fake
        )
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        m.startScan()
        #expect(fake.scanForPeripheralsCallCount == 0)
    }
}
