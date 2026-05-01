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

        #expect(fake.scanForPeripheralsCallCount == 1)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: id, name: "S")

        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == id)
        #expect(fake.stopScanCallCount == 1)
        #expect(m.cscSensor(for: id)?._test_connectionSnapshot == .connecting)
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

        #expect(fake.scanForPeripheralsCallCount == 0)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: id, name: "S")

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
        #expect(fake.scanForPeripheralsCallCount == 1)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: id, name: "S")

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

    @Test func poweredOn_twoKnownSensors_onlyFirstDiscoveredConnects() {
        let idA = UUID()
        let idB = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[idA] = FakeCSCPeripheral(identifier: idA, name: "A")
        fake.peripheralsById[idB] = FakeCSCPeripheral(identifier: idB, name: "B")

        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(id: idA, name: "A", isEnabled: true, wheelDiameterMeters: 0.67),
            CSCKnownSensorRecord(id: idB, name: "B", isEnabled: true, wheelDiameterMeters: 0.67),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.scanForPeripheralsCallCount == 1)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: idB, name: "B")

        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == idB)
        #expect(m.cscSensor(for: idB)?._test_connectionSnapshot == .connecting)
        #expect(m.cscSensor(for: idA)?._test_connectionSnapshot == .disconnected)
    }

    @Test func poweredOn_afterFirstFails_autoReconnectsSecondCandidate() {
        let idA = UUID()
        let idB = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[idA] = FakeCSCPeripheral(identifier: idA, name: "A")
        fake.peripheralsById[idB] = FakeCSCPeripheral(identifier: idB, name: "B")

        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(id: idA, name: "A", isEnabled: true, wheelDiameterMeters: 0.67),
            CSCKnownSensorRecord(id: idB, name: "B", isEnabled: true, wheelDiameterMeters: 0.67),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)
        #expect(fake.scanForPeripheralsCallCount == 1)

        m._test_simulateDidDiscover(peripheralID: idA, name: "A")
        #expect(fake.connectCallCount == 1)

        m._test_simulateDidFailToConnect(peripheralID: idA)
        #expect(fake.scanForPeripheralsCallCount >= 2)

        m._test_simulateDidDiscover(peripheralID: idA, name: "A")
        #expect(fake.connectCallCount == 1)

        m._test_simulateDidDiscover(peripheralID: idB, name: "B")

        #expect(fake.connectCallCount == 2)
        #expect(fake.lastConnectPeripheral?.identifier == idB)
        #expect(m.cscSensor(for: idA)?._test_connectionSnapshot == .disconnected)
        #expect(m.cscSensor(for: idB)?._test_connectionSnapshot == .connecting)
    }

    @Test func poweredOn_whenOneAlreadyConnected_doesNotIssueAdditionalConnect() {
        let idA = UUID()
        let idB = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[idA] = FakeCSCPeripheral(identifier: idA, name: "A")
        fake.peripheralsById[idB] = FakeCSCPeripheral(identifier: idB, name: "B")

        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(id: idA, name: "A", isEnabled: true, wheelDiameterMeters: 0.67),
            CSCKnownSensorRecord(id: idB, name: "B", isEnabled: true, wheelDiameterMeters: 0.67),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        let connectedA = CyclingSpeedAndCadenceSensor(
            id: idA,
            name: "A",
            initialConnectionState: .connected,
            initialWheelDiameter: Measurement(value: 0.67, unit: UnitLength.meters),
            initialIsEnabled: true
        )
        m._test_registerSensor(connectedA)

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.scanForPeripheralsCallCount == 0)
        #expect(fake.connectCallCount == 0)
        #expect(m.cscSensor(for: idB)?._test_connectionSnapshot == .disconnected)
    }

    @Test func userScanSheetClose_doesNotStopBackgroundScan() {
        let id = UUID()
        let fake = FakeCSCCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeCSCPeripheral(identifier: id, name: "S")

        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(id: id, name: "S", isEnabled: true, wheelDiameterMeters: 0.67),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)
        #expect(fake.scanForPeripheralsCallCount == 1)

        m.startScan()
        #expect(fake.scanForPeripheralsCallCount == 2)

        m.stopScan()
        #expect(fake.stopScanCallCount == 0)
    }
}
