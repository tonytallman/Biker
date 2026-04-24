//
//  CSCDualSensorPreferenceTests.swift
//  DependencyContainerTests
//
//  SEN-TYP-5: a dual-capable CSC sensor is preferred for speed and cadence over a lex-first
//  wheel-only sensor when the dual sensor has data (via ``CyclingSpeedAndCadenceSensorManager/dualCapableSensor``).
//

import Combine
import CoreLogic
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService
@testable import DependencyContainer

@MainActor
@Suite("CSCDualSensorPreference")
struct CSCDualSensorPreferenceTests {
    @Test func prefersDualCapableForSpeedAndCadenceOverLexFirstWheelOnly() {
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let m = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        let a = makeCSCSensor(id: idA, name: "LexFirst", connected: true)
        let b = makeCSCSensor(id: idB, name: "Dual", connected: true)
        a._test_setFeature(CSCFeature(supportsWheel: true, supportsCrank: false))
        b._test_setFeature(CSCFeature(supportsWheel: true, supportsCrank: true))
        m._test_registerSensor(a)
        m._test_registerSensor(b)

        let lex = CSCPeripheralLexMetrics(manager: m)
        var speeds: [Double] = []
        var cadences: [Double] = []
        _ = lex.speed.publisher.sink { speeds.append($0.converted(to: .metersPerSecond).value) }
        _ = lex.cadence.publisher.sink { cadences.append($0.converted(to: .revolutionsPerMinute).value) }

        // A: fast wheel-only (~21 m/s for default circumference).
        a._test_ingestCSCMeasurementData(wheelSample(revolutions: 0, time1024: 0))
        a._test_ingestCSCMeasurementData(wheelSample(revolutions: 10, time1024: 1024))

        // B: slow wheel + 100 rpm cadence (dual path).
        b._test_ingestCSCMeasurementData(combinedWheelCrank(
            wheelRevs: 0,
            wheelTime: 0,
            crankRevs: 10,
            crankTime: 0
        ))
        b._test_ingestCSCMeasurementData(combinedWheelCrank(
            wheelRevs: 1,
            wheelTime: 1024,
            crankRevs: 20,
            crankTime: 6144
        ))

        guard let s = speeds.last, let c = cadences.last else {
            Issue.record("Expected speed and cadence")
            return
        }
        #expect(s < 10)
        #expect(s > 1)
        #expect(abs(c - 100.0) < 0.001)
    }

    private func makeCSCSensor(id: UUID, name: String, connected: Bool) -> CyclingSpeedAndCadenceSensor {
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: name,
            initialConnectionState: connected ? .connected : .disconnected
        )
        s.setConnectionState(connected ? .connected : .disconnected)
        return s
    }

    private func wheelSample(revolutions: UInt32, time1024: UInt16) -> Data {
        var d = Data([0x01])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }

    private func combinedWheelCrank(
        wheelRevs: UInt32,
        wheelTime: UInt16,
        crankRevs: UInt16,
        crankTime: UInt16
    ) -> Data {
        var d = Data([0x03])
        d.append(contentsOf: withUnsafeBytes(of: wheelRevs.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: wheelTime.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: crankRevs.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: crankTime.littleEndian) { Data($0) })
        return d
    }
}
