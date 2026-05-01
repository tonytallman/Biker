//
//  HeartRateSensorManagerTests.swift
//  HeartRateServiceTests
//

import Combine
import Foundation
import Testing

@testable import HeartRateService

private let hrKnownSensorsStorageKey = "HR.knownSensors.v1"

private final class InMemoryHRPersistence: Storage {
    private var storage: [String: Any] = [:]

    init(records: [HRKnownSensorRecord] = []) {
        if !records.isEmpty, let data = try? JSONEncoder().encode(records) {
            storage[hrKnownSensorsStorageKey] = data
        }
    }

    var recordsOnDisk: [HRKnownSensorRecord] {
        guard let data = storage[hrKnownSensorsStorageKey] as? Data,
              let r = try? JSONDecoder().decode([HRKnownSensorRecord].self, from: data)
        else { return [] }
        return r
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
private final class WeakRefBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

@MainActor
struct HeartRateSensorManagerTests {
    @Test func mergedHeartRate_fansInFromTwoSensors() {
        let m = HeartRateSensorManager(persistence: InMemoryHRPersistence())
        let a = makeSensor(id: UUID(), name: "A", connected: true)
        let b = makeSensor(id: UUID(), name: "B", connected: true)
        m._test_registerSensor(a)
        m._test_registerSensor(b)
        var received: [Double] = []
        let c = m.heartRate.sink { received.append($0.converted(to: .beatsPerMinute).value) }
        let data = Data([0x00, 88])
        a._test_ingestHeartRateMeasurement(data)
        b._test_ingestHeartRateMeasurement(data)
        _ = c
        #expect(received.count == 2)
    }

    @Test func hasConnectedSensor_trueWhenAnyKnownIsConnected() {
        let m = HeartRateSensorManager(persistence: InMemoryHRPersistence())
        var hasConnected = false
        let c = m.hasConnectedSensor.sink { hasConnected = $0 }
        m._test_registerSensor(makeSensor(id: UUID(), name: "Z", connected: true))
        _ = c
        #expect(hasConnected == true)
    }

    @Test func forget_releasesSensor() {
        let m = HeartRateSensorManager(persistence: InMemoryHRPersistence())
        let id = UUID()
        var sensor: HeartRateSensor! = makeSensor(id: id, name: "X", connected: false)
        m._test_registerSensor(sensor)
        let weakRef = WeakRefBox<HeartRateSensor>(sensor)
        sensor = nil
        #expect(weakRef.value != nil)
        m._test_forgetWithoutCancel(peripheralID: id)
        #expect(weakRef.value == nil)
    }

    @Test func knownSensors_sortedByName() {
        let m = HeartRateSensorManager(persistence: InMemoryHRPersistence())
        m._test_registerSensor(makeSensor(id: UUID(), name: "B", connected: true))
        m._test_registerSensor(makeSensor(id: UUID(), name: "A", connected: true))
        var names: [String] = []
        let c = m.knownSensors.sink { list in names = list.map(\ConnectedSensor.name) }
        _ = c
        #expect(names == ["A", "B"])
    }

    @Test func init_seedsEnabledFromPersistence() {
        let id = UUID()
        let p = InMemoryHRPersistence(records: [
            HRKnownSensorRecord(
                id: id,
                name: "Stored",
                isEnabled: false
            ),
        ])
        let m = HeartRateSensorManager(persistence: p)
        let s = m.heartRateSensor(for: id)
        #expect(s != nil)
        #expect(s?.isEnabledValue == false)
    }

    @Test func forget_removesFromPersistence() {
        let p = InMemoryHRPersistence()
        let m = HeartRateSensorManager(persistence: p)
        let id = UUID()
        m._test_registerSensor(makeSensor(id: id, name: "X", connected: true))
        #expect(p.recordsOnDisk.map(\.id).contains(id))
        m.forget(peripheralID: id)
        #expect(p.recordsOnDisk.isEmpty)
    }

    @Test func startScan_fakeCentral_whenPoweredOn() {
        let fake = FakeHRCentral(state: .poweredOn, authorization: .allowedAlways)
        let m = HeartRateSensorManager(persistence: InMemoryHRPersistence(), central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in
            m?.handleBluetoothStateChange()
        }
        m.handleBluetoothStateChange()
        m.startScan()
        #expect(fake.scanForPeripheralsCallCount == 1)
    }

    @Test func setEnabled_false_whenConnected_requestsCancelAndClearsHasConnectedAfterDisconnect() {
        let id = UUID()
        let fake = FakeHRCentral(state: .poweredOn, authorization: .allowedAlways)
        let peripheral = FakeHRPeripheral(identifier: id, name: "HRM")
        peripheral.state = .connected
        fake.peripheralsById[id] = peripheral

        let m = HeartRateSensorManager(persistence: InMemoryHRPersistence(), central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }
        m.handleBluetoothStateChange()

        let sensor = makeSensor(id: id, name: "HRM", connected: true)
        sensor.bind(peripheral: peripheral)
        m._test_registerSensor(sensor)

        var hasConnected = false
        let sub = m.hasConnectedSensor.sink { hasConnected = $0 }
        _ = sub
        #expect(hasConnected == true)

        m.setEnabled(peripheralID: id, false)
        #expect(fake.cancelPeripheralConnectionCallCount == 1)
        #expect(m.heartRateSensor(for: id)?.isEnabledValue == false)

        m._test_simulateDidDisconnect(peripheralID: id)
        #expect(hasConnected == false)
    }

    @Test func setEnabled_true_whenDisabledReconnectsIfPoweredOn() {
        let id = UUID()
        let fake = FakeHRCentral(state: .poweredOn, authorization: .allowedAlways)
        let peripheral = FakeHRPeripheral(identifier: id, name: "HRM")
        peripheral.state = .disconnected
        fake.peripheralsById[id] = peripheral

        let p = InMemoryHRPersistence(records: [
            HRKnownSensorRecord(
                id: id,
                name: "HRM",
                isEnabled: false
            ),
        ])
        let m = HeartRateSensorManager(persistence: p, central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in m?.handleBluetoothStateChange() }
        m.handleBluetoothStateChange()

        #expect(m.heartRateSensor(for: id)?.isEnabledValue == false)
        #expect(fake.connectCallCount == 0)

        m.setEnabled(peripheralID: id, true)
        #expect(m.heartRateSensor(for: id)?.isEnabledValue == true)
        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectPeripheral?.identifier == id)
    }
}

@MainActor
private func makeSensor(id: UUID, name: String, connected: Bool) -> HeartRateSensor {
    HeartRateSensor(
        id: id,
        name: name,
        initialConnectionState: connected ? .connected : .disconnected
    )
}
