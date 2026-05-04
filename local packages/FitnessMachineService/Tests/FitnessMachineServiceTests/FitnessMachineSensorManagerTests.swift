//
//  FitnessMachineSensorManagerTests.swift
//  FitnessMachineServiceTests
//

import Combine
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

    var recordsOnDisk: [FTMSKnownSensorRecord] {
        guard let data = storage[ftmsKnownSensorsStorageKey] as? Data,
              let r = try? JSONDecoder().decode([FTMSKnownSensorRecord].self, from: data)
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
struct FitnessMachineSensorManagerTests {
    @Test func mergedSpeed_fansInFromTwoSensors() {
        let m = FitnessMachineSensorManager(storage: InMemoryFTMSPersistence())
        let a = makeSensor(id: UUID(), name: "A", connected: true)
        let b = makeSensor(id: UUID(), name: "B", connected: true)
        m._test_registerSensor(a)
        m._test_registerSensor(b)
        var received: [Measurement<UnitSpeed>] = []
        let c = m.speed.sink { received.append($0) }
        var d = Data([0x00, 0x00, 0x10, 0x0E])
        a._test_ingestIndoorBikeData(d)
        b._test_ingestIndoorBikeData(d)
        _ = c
        #expect(received.count == 2)
    }

    @Test func hasConnectedSensor_trueWhenAnyKnownIsConnected() {
        let m = FitnessMachineSensorManager(storage: InMemoryFTMSPersistence())
        var hasConnected = false
        let c = m.hasConnectedSensor.sink { hasConnected = $0 }
        m._test_registerSensor(makeSensor(id: UUID(), name: "Z", connected: true))
        _ = c
        #expect(hasConnected == true)
    }

    @Test func forget_releasesSensor() {
        let m = FitnessMachineSensorManager(storage: InMemoryFTMSPersistence())
        let id = UUID()
        var sensor: FitnessMachineSensor! = makeSensor(id: id, name: "X", connected: false)
        m._test_registerSensor(sensor)
        let weakRef = WeakRefBox<FitnessMachineSensor>(sensor)
        sensor = nil
        #expect(weakRef.value != nil)
        m._test_forgetWithoutCancel(peripheralID: id)
        #expect(weakRef.value == nil)
    }

    @Test func knownSensors_sortedByName() {
        let m = FitnessMachineSensorManager(storage: InMemoryFTMSPersistence())
        m._test_registerSensor(makeSensor(id: UUID(), name: "B", connected: true))
        m._test_registerSensor(makeSensor(id: UUID(), name: "A", connected: true))
        var names: [String] = []
        let c = m.knownSensors.sink { list in names = list.map(\ConnectedSensor.name) }
        _ = c
        #expect(names == ["A", "B"])
    }

    @Test func init_seedsEnabledFromPersistence() {
        let id = UUID()
        let p = InMemoryFTMSPersistence(records: [
            FTMSKnownSensorRecord(
                id: id,
                name: "Stored",
                isEnabled: false
            ),
        ])
        let m = FitnessMachineSensorManager(storage: p)
        let s = m.ftmsSensor(for: id)
        #expect(s != nil)
        #expect(s?.isEnabledValue == false)
    }

    @Test func forget_removesFromPersistence() {
        let p = InMemoryFTMSPersistence()
        let m = FitnessMachineSensorManager(storage: p)
        let id = UUID()
        m._test_registerSensor(makeSensor(id: id, name: "X", connected: true))
        #expect(p.recordsOnDisk.map(\.id).contains(id))
        m.forget(peripheralID: id)
        #expect(p.recordsOnDisk.isEmpty)
    }

    @Test func startScan_fakeCentral_whenPoweredOn() {
        let fake = FakeFTMSCentral(state: .poweredOn, authorization: .allowedAlways)
        let m = FitnessMachineSensorManager(persistence: InMemoryFTMSPersistence(), central: fake)
        fake.onAuthorizationOrStateChange = { [weak m] in
            m?.handleBluetoothStateChange()
        }
        m.handleBluetoothStateChange()
        m.startScan()
        #expect(fake.scanForPeripheralsCallCount == 1)
    }
}

@MainActor
private func makeSensor(id: UUID, name: String, connected: Bool) -> FitnessMachineSensor {
    let s = FitnessMachineSensor(
        id: id,
        name: name,
        initialConnectionState: connected ? .connected : .disconnected
    )
    return s
}
