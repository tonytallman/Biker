//
//  CyclingSpeedAndCadenceSensorManagerTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Combine
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

@MainActor
private final class WeakRefBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

@MainActor
struct CyclingSpeedAndCadenceSensorManagerTests {
    @Test func mergedDerivedUpdates_fansInFromTwoSensors() {
        let m = CyclingSpeedAndCadenceSensorManager()
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
        let m = CyclingSpeedAndCadenceSensorManager()
        var hasConnected = false
        let c = m.hasConnectedSensor.sink { hasConnected = $0 }
        m._test_registerSensor(makeSensor(id: UUID(), name: "Z", connected: true))
        _ = c
        #expect(hasConnected == true)
    }

    @Test func forget_releasesSensor() {
        let m = CyclingSpeedAndCadenceSensorManager()
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
        let m = CyclingSpeedAndCadenceSensorManager()
        m._test_registerSensor(makeSensor(id: UUID(), name: "B", connected: true))
        m._test_registerSensor(makeSensor(id: UUID(), name: "A", connected: true))
        var names: [String] = []
        let c = m.knownSensors.sink { names = $0.map(\.name) }
        _ = c
        #expect(names == ["A", "B"])
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
