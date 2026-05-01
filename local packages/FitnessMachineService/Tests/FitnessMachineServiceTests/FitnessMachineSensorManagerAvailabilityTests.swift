//
//  FitnessMachineSensorManagerAvailabilityTests.swift
//  FitnessMachineServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation
import Testing

@testable import FitnessMachineService

private let ftmsKnownSensorsStorageKey = "FTMS.knownSensors.v1"

private final class InMemoryFTMSPersistence: Storage {
    private var storage: [String: Any] = [:]

    init(records: [FTMSKnownSensorRecord] = []) {
        if !records.isEmpty, let data = try? JSONEncoder().encode(records) {
            storage[ftmsKnownSensorsStorageKey] = data
        }
    }

    func get(forKey key: String) -> Any? { storage[key] }

    func set(value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}

@MainActor
struct FitnessMachineSensorManagerAvailabilityTests {
    @Test func poweredOffToPoweredOn_reconnectsEnabledDisconnectedKnownSensor() {
        let id = UUID()
        let fake = FakeFTMSCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeFTMSPeripheral(identifier: id, name: "S")

        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(
                id: id,
                name: "S",
                isEnabled: true
            ),
        ])
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.scanForPeripheralsCallCount == 1)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: id, name: "S")

        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == id)
        #expect(fake.stopScanCallCount == 1)
        #expect(m.ftmsSensor(for: id)?.connectedSensorSnapshot.connectionState == .connecting)
    }

    @Test func poweredOn_doesNotReconnectWhenSensorDisabled() {
        let id = UUID()
        let fake = FakeFTMSCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeFTMSPeripheral(identifier: id, name: "S")

        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(
                id: id,
                name: "S",
                isEnabled: false
            ),
        ])
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.scanForPeripheralsCallCount == 0)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: id, name: "S")

        #expect(fake.connectCallCount == 0)
    }

    @Test func poweredOn_twoKnownSensors_onlyFirstDiscoveredConnects() {
        let idA = UUID()
        let idB = UUID()
        let fake = FakeFTMSCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[idA] = FakeFTMSPeripheral(identifier: idA, name: "A")
        fake.peripheralsById[idB] = FakeFTMSPeripheral(identifier: idB, name: "B")

        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(id: idA, name: "A", isEnabled: true),
            FTMSKnownSensorRecord(id: idB, name: "B", isEnabled: true),
        ])
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.scanForPeripheralsCallCount == 1)
        #expect(fake.connectCallCount == 0)

        m._test_simulateDidDiscover(peripheralID: idB, name: "B")

        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == idB)
        #expect(m.ftmsSensor(for: idB)?.connectedSensorSnapshot.connectionState == .connecting)
        #expect(m.ftmsSensor(for: idA)?.connectedSensorSnapshot.connectionState == .disconnected)
    }

    @Test func poweredOn_afterFirstFails_autoReconnectsSecondCandidate() {
        let idA = UUID()
        let idB = UUID()
        let fake = FakeFTMSCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[idA] = FakeFTMSPeripheral(identifier: idA, name: "A")
        fake.peripheralsById[idB] = FakeFTMSPeripheral(identifier: idB, name: "B")

        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(id: idA, name: "A", isEnabled: true),
            FTMSKnownSensorRecord(id: idB, name: "B", isEnabled: true),
        ])
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
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
        #expect(m.ftmsSensor(for: idA)?.connectedSensorSnapshot.connectionState == .disconnected)
        #expect(m.ftmsSensor(for: idB)?.connectedSensorSnapshot.connectionState == .connecting)
    }

    @Test func poweredOn_whenOneAlreadyConnected_doesNotIssueAdditionalConnect() {
        let idA = UUID()
        let idB = UUID()
        let fake = FakeFTMSCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[idA] = FakeFTMSPeripheral(identifier: idA, name: "A")
        fake.peripheralsById[idB] = FakeFTMSPeripheral(identifier: idB, name: "B")

        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(id: idA, name: "A", isEnabled: true),
            FTMSKnownSensorRecord(id: idB, name: "B", isEnabled: true),
        ])
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        let connectedA = FitnessMachineSensor(
            id: idA,
            name: "A",
            initialConnectionState: .connected,
            initialIsEnabled: true
        )
        m._test_registerSensor(connectedA)

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)

        #expect(fake.scanForPeripheralsCallCount == 0)
        #expect(fake.connectCallCount == 0)
        #expect(m.ftmsSensor(for: idB)?.connectedSensorSnapshot.connectionState == .disconnected)
    }

    @Test func userScanSheetClose_doesNotStopBackgroundScan() {
        let id = UUID()
        let fake = FakeFTMSCentral(
            state: .poweredOff,
            authorization: .allowedAlways
        )
        fake.peripheralsById[id] = FakeFTMSPeripheral(identifier: id, name: "S")

        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(id: id, name: "S", isEnabled: true),
        ])
        let m = FitnessMachineSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }

        fake.simulate(authorization: .allowedAlways, state: .poweredOn)
        #expect(fake.scanForPeripheralsCallCount == 1)

        m.startScan()
        #expect(fake.scanForPeripheralsCallCount == 2)

        m.stopScan()
        #expect(fake.stopScanCallCount == 0)
    }
}
