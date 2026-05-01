//
//  CyclingSpeedAndCadenceSensorTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Combine
@preconcurrency import CoreBluetooth
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

@MainActor
struct CyclingSpeedAndCadenceSensorTests {
    @Test func ingest_wheelDeltaMatchesExpectedMath() {
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected
        )
        s.setWheelDiameter(Measurement(value: 0.5 / .pi, unit: .meters))
        // Circumference = π * d = 0.5 m
        let m0 = Self.wheelData(revolutions: 10, time1024: 1024)
        let m1 = Self.wheelData(revolutions: 20, time1024: 2048)
        var updates: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { updates.append($0) }
        s._test_ingestCSCMeasurementData(m0)
        s._test_ingestCSCMeasurementData(m1)
        _ = c
        #expect(updates.count == 1)
        #expect(updates[0].distanceDeltaMeters == 5.0)
        #expect(updates[0].speedMetersPerSecond == 5.0)
    }

    @Test func setWheelDiameter_affectsSubsequentSample() {
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected
        )
        s.setWheelDiameter(Measurement(value: 0.5 / .pi, unit: .meters))
        let m0 = Self.wheelData(revolutions: 0, time1024: 0)
        let m1 = Self.wheelData(revolutions: 1, time1024: 1024)
        s._test_ingestCSCMeasurementData(m0)
        s._test_ingestCSCMeasurementData(m1)
        s.setWheelDiameter(Measurement(value: 1.0 / .pi, unit: .meters))
        let m2 = Self.wheelData(revolutions: 2, time1024: 2048)
        var u: CSCDerivedUpdate?
        let c = s.derivedUpdates.sink { u = $0 }
        s._test_ingestCSCMeasurementData(m2)
        _ = c
        #expect(u?.distanceDeltaMeters == 1.0)
    }

    @Test func setEnabledFalse_suppressesDerivation() {
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected
        )
        s.setEnabled(false)
        var count = 0
        let c = s.derivedUpdates.sink { _ in count += 1 }
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 0, time1024: 0))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 1, time1024: 1024))
        _ = c
        #expect(count == 0)
    }

    @Test func didDisconnect_resetsState() {
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected
        )
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 0, time1024: 0))
        s.didDisconnect()
        #expect(s.connectedSensorSnapshot.connectionState == .disconnected)
        var afterReconnect: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { afterReconnect.append($0) }
        s.setConnectionState(.connected)
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 1, time1024: 1024))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 2, time1024: 2048))
        _ = c
        #expect(afterReconnect.count == 1)
    }

    @Test func init_seedsWheelDiameterAndIsEnabled() {
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "S",
            initialConnectionState: .disconnected,
            initialWheelDiameter: Measurement(value: 0.55, unit: UnitLength.meters),
            initialIsEnabled: false
        )
        #expect(s.isEnabledValue == false)
        #expect(s.currentWheelDiameter == Measurement(value: 0.55, unit: UnitLength.meters))
    }

    @Test func fakePeripheral_bindsToSensor() {
        let f = FakeCSCPeripheral(identifier: UUID(), name: "F")
        let s = CyclingSpeedAndCadenceSensor(
            id: f.identifier,
            name: "A",
            initialConnectionState: .disconnected
        )
        s.bind(peripheral: f)
        s.didConnect()
        #expect(f.discoverServiceUUIDs == [CBUUID(string: "1816")])
    }

    @Test func idleTimeout_emitsZeroSpeedAndDistance_afterWheelUpdate() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        s.setWheelDiameter(Measurement(value: 0.5 / .pi, unit: .meters))
        let m0 = Self.wheelData(revolutions: 10, time1024: 1024)
        let m1 = Self.wheelData(revolutions: 20, time1024: 2048)
        var updates: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { updates.append($0) }
        s._test_ingestCSCMeasurementData(m0)
        s._test_ingestCSCMeasurementData(m1)
        #expect(updates.count == 1)
        #expect(updates[0].speedMetersPerSecond != 0)
        sched.fireNow()
        _ = c
        #expect(updates.count == 2)
        #expect(updates[1].speedMetersPerSecond == 0)
        #expect(updates[1].distanceDeltaMeters == 0)
    }

    @Test func idleTimeout_emitsZeroCadence_afterCrankUpdate() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        let m0 = Self.crankData(revolutions: 10, time1024: 0)
        let m1 = Self.crankData(revolutions: 20, time1024: 6144)
        var updates: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { updates.append($0) }
        s._test_ingestCSCMeasurementData(m0)
        s._test_ingestCSCMeasurementData(m1)
        #expect(updates.count == 1)
        #expect((updates[0].cadenceRPM ?? 0) != 0)
        sched.fireNow()
        _ = c
        #expect(updates.count == 2)
        #expect(updates[1].cadenceRPM == 0)
    }

    @Test func idleTimeout_doesNotEmit_beforeAnyUpdate() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        var count = 0
        let c = s.derivedUpdates.sink { _ in count += 1 }
        sched.fireNow()
        _ = c
        #expect(count == 0)
    }

    @Test func idleTimeout_resetsOnNewUpdate() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        s.setWheelDiameter(Measurement(value: 0.5 / .pi, unit: .meters))
        var idleZeroCount = 0
        let c = s.derivedUpdates.sink { u in
            if u.speedMetersPerSecond == 0, u.distanceDeltaMeters == 0 {
                idleZeroCount += 1
            }
        }
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 0, time1024: 0))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 10, time1024: 1024))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 20, time1024: 2048))
        sched.fireNow()
        _ = c
        #expect(idleZeroCount == 1)
    }

    @Test func idleTimeout_cancelledOnDisconnect() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        var updates: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { updates.append($0) }
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 0, time1024: 0))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 1, time1024: 1024))
        let n = updates.count
        s.didDisconnect()
        sched.fireNow()
        _ = c
        #expect(updates.count == n)
    }

    @Test func idleTimeout_cancelledOnSetEnabledFalse() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        var updates: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { updates.append($0) }
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 0, time1024: 0))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 1, time1024: 1024))
        let n = updates.count
        s.setEnabled(false)
        sched.fireNow()
        _ = c
        #expect(updates.count == n)
    }

    @Test func idleTimeout_doesNotRepeatZeros() {
        let sched = ManualIdleScheduler()
        let s = CyclingSpeedAndCadenceSensor(
            id: UUID(),
            name: "A",
            initialConnectionState: .connected,
            idleTimeout: 99,
            idleScheduler: sched
        )
        var updates: [CSCDerivedUpdate] = []
        let c = s.derivedUpdates.sink { updates.append($0) }
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 0, time1024: 0))
        s._test_ingestCSCMeasurementData(Self.wheelData(revolutions: 1, time1024: 1024))
        sched.fireNow()
        let n = updates.count
        sched.fireNow()
        _ = c
        #expect(updates.count == n)
    }

    private static func wheelData(revolutions: UInt32, time1024: UInt16) -> Data {
        var d = Data([0x01])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }

    private static func crankData(revolutions: UInt16, time1024: UInt16) -> Data {
        var d = Data([0x02])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }
}

/// Test double: single pending callback; `fireNow` runs what `schedule` last installed.
@MainActor
private final class ManualIdleScheduler: CSCIdleScheduler {
    private var token = 0
    private var pending: (Int, @MainActor () -> Void)?

    func schedule(after _: TimeInterval, _ work: @escaping @MainActor () -> Void) -> AnyCancellable {
        token += 1
        let t = token
        pending = (t, work)
        return AnyCancellable { [weak self] in
            guard let self else { return }
            if self.pending?.0 == t {
                self.pending = nil
            }
        }
    }

    func fireNow() {
        guard let (_, work) = pending else { return }
        pending = nil
        work()
    }
}
