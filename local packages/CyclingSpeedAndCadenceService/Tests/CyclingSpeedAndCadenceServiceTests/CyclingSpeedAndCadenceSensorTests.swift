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

    private static func wheelData(revolutions: UInt32, time1024: UInt16) -> Data {
        var d = Data([0x01])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }
}

@MainActor
private final class FakeCSCPeripheral: CSCPeripheral {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState = .disconnected
    weak var delegate: (any CBPeripheralDelegate)?
    var services: [CBService]?
    var discoverServiceUUIDs: [CBUUID]?

    init(identifier: UUID, name: String) {
        self.identifier = identifier
        self.name = name
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        discoverServiceUUIDs = serviceUUIDs
    }

    func discoverCharacteristics(_: [CBUUID]?, for _: CBService) {}

    func setNotifyValue(_: Bool, for _: CBCharacteristic) {}
}
