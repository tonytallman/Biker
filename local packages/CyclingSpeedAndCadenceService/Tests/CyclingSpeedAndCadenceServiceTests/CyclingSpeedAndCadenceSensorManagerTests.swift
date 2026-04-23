//
//  CyclingSpeedAndCadenceSensorManagerTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Combine
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
private final class WeakRefBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

@MainActor
struct CyclingSpeedAndCadenceSensorManagerTests {
    @Test func mergedDerivedUpdates_fansInFromTwoSensors() {
        let m = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        let a = makeSensor(id: UUID(), name: "A", connected: true)
        let b = makeSensor(id: UUID(), name: "B", connected: true)
        m._test_registerSensor(a)
        m._test_registerSensor(b)
        var received: [CSCDerivedUpdate] = []
        let c = m.derivedUpdates.sink { received.append($0) }
        a._test_ingestCSCMeasurementData(wheelData(revolutions: 0, time1024: 0))
        a._test_ingestCSCMeasurementData(wheelData(revolutions: 1, time1024: 1024))
        b._test_ingestCSCMeasurementData(wheelData(revolutions: 0, time1024: 0))
        b._test_ingestCSCMeasurementData(wheelData(revolutions: 1, time1024: 1024))
        _ = c
        #expect(received.count == 2)
    }

    @Test func hasConnectedSensor_trueWhenAnyKnownIsConnected() {
        let m = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        var hasConnected = false
        let c = m.hasConnectedSensor.sink { hasConnected = $0 }
        m._test_registerSensor(makeSensor(id: UUID(), name: "Z", connected: true))
        _ = c
        #expect(hasConnected == true)
    }

    @Test func forget_releasesSensor() {
        let m = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        let id = UUID()
        var sensor: CyclingSpeedAndCadenceSensor! = makeSensor(id: id, name: "X", connected: false)
        m._test_registerSensor(sensor)
        let weakRef = WeakRefBox<CyclingSpeedAndCadenceSensor>(sensor)
        sensor = nil
        #expect(weakRef.value != nil)
        m._test_forgetWithoutCancel(peripheralID: id)
        #expect(weakRef.value == nil)
    }

    @Test func knownSensors_sortedByName() {
        let m = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        m._test_registerSensor(makeSensor(id: UUID(), name: "B", connected: true))
        m._test_registerSensor(makeSensor(id: UUID(), name: "A", connected: true))
        var names: [String] = []
        let c = m.knownSensors.sink { list in names = list.map(\ConnectedSensor.name) }
        _ = c
        #expect(names == ["A", "B"])
    }

    @Test func init_seedsWheelAndEnabledFromPersistence() {
        let id = UUID()
        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(
                id: id,
                name: "Stored",
                isEnabled: false,
                wheelDiameterMeters: 0.5
            ),
        ])
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p)
        let s = m.cscSensor(for: id)
        #expect(s != nil)
        #expect(s?.isEnabledValue == false)
        #expect(s?.currentWheelDiameter == Measurement(value: 0.5, unit: UnitLength.meters))
    }

    @Test func registerSensor_newRecordDefaultsEnabled() {
        let p = InMemoryCSCPersistence()
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p)
        let id = UUID()
        let s = makeSensor(id: id, name: "N", connected: true)
        m._test_registerSensor(s)
        #expect(p.records.contains(where: { $0.id == id && $0.isEnabled == true }))
    }

    @Test func forget_removesFromPersistence() {
        let p = InMemoryCSCPersistence()
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p)
        let id = UUID()
        m._test_registerSensor(makeSensor(id: id, name: "X", connected: true))
        #expect(p.records.map(\.id).contains(id))
        m.forget(peripheralID: id)
        #expect(p.records.isEmpty)
    }

    @Test func setWheel_persists() {
        let p = InMemoryCSCPersistence()
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p)
        let id = UUID()
        m._test_registerSensor(makeSensor(id: id, name: "W", connected: true))
        m.setWheelDiameter(peripheralID: id, Measurement(value: 0.6, unit: UnitLength.meters))
        #expect(
            p.records.contains(where: { r in
                r.id == id && (r.wheelDiameterMeters - 0.6) < 0.0001
            })
        )
    }

    @Test func setEnabled_persists() {
        let p = InMemoryCSCPersistence()
        let m = CyclingSpeedAndCadenceSensorManager(persistence: p)
        let id = UUID()
        m._test_registerSensor(makeSensor(id: id, name: "E", connected: true))
        m.setEnabled(peripheralID: id, false)
        #expect(p.records.contains(where: { $0.id == id && $0.isEnabled == false }))
    }

    private func makeSensor(
        id: UUID,
        name: String,
        connected: Bool
    ) -> CyclingSpeedAndCadenceSensor {
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: name,
            initialConnectionState: connected ? .connected : .disconnected
        )
        s.setConnectionState(connected ? .connected : .disconnected)
        return s
    }

    private func wheelData(revolutions: UInt32, time1024: UInt16) -> Data {
        var d = Data([0x01])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }
}
