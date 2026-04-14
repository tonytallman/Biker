//
//  CSCMeasurementParserTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

struct CSCMeasurementParserTests {
    @Test func parseWheelOnly_success() throws {
        // flags wheel, revs=100, lastWheelTime=1024 (1 second in 1/1024 units)
        let data = Data([0x01, 0x64, 0x00, 0x00, 0x00, 0x00, 0x04])
        let result = CSCMeasurementParser.parse(data)
        let m = try result.get()
        let w = try #require(m.wheel)
        #expect(w.cumulativeRevolutions == 100)
        #expect(w.lastEventTime1024 == 1024)
        #expect(m.crank == nil)
    }

    @Test func parseCrankOnly_success() throws {
        // flags crank, revs=60, time=2048
        let data = Data([0x02, 0x3C, 0x00, 0x00, 0x08])
        let result = CSCMeasurementParser.parse(data)
        let m = try result.get()
        #expect(m.wheel == nil)
        let c = try #require(m.crank)
        #expect(c.cumulativeRevolutions == 60)
        #expect(c.lastEventTime1024 == 2048)
    }

    @Test func parseCombined_success() throws {
        // wheel + crank
        let data = Data([
            0x03,
            0x0A, 0x00, 0x00, 0x00, 0x00, 0x04,
            0x05, 0x00, 0x00, 0x08,
        ])
        let m = try CSCMeasurementParser.parse(data).get()
        #expect(m.wheel?.cumulativeRevolutions == 10)
        #expect(m.wheel?.lastEventTime1024 == 1024)
        #expect(m.crank?.cumulativeRevolutions == 5)
        #expect(m.crank?.lastEventTime1024 == 2048)
    }

    @Test func parseTooShort_fails() {
        let data = Data([0x01])
        let result = CSCMeasurementParser.parse(data)
        guard case let .failure(err) = result else {
            Issue.record("Expected failure")
            return
        }
        guard case .dataTooShort = err else {
            Issue.record("Expected dataTooShort")
            return
        }
    }

    @Test func parseInvalidFlags_noWheelNoCrank_fails() {
        let data = Data([0x00])
        let result = CSCMeasurementParser.parse(data)
        guard case .failure = result else {
            Issue.record("Expected failure")
            return
        }
    }

    @Test func deltaCalculator_wheelSpeedAndDistance() throws {
        var calc = CSCDeltaCalculator(wheelCircumferenceMeters: 2.0)
        // Sample 1: 100 revs, 1024 ticks = 1s
        let m0 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 100, lastEventTime1024: 1024),
            crank: nil
        )
        #expect(calc.push(m0) == nil)

        // +10 revs over +1024 ticks = 1s → 20m distance, 20 m/s
        let m1 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 110, lastEventTime1024: 2048),
            crank: nil
        )
        guard let u1 = calc.push(m1) else {
            Issue.record("Expected derived update")
            return
        }
        #expect(u1.distanceDeltaMeters == 20.0)
        #expect(u1.speedMetersPerSecond == 20.0)
        #expect(u1.cadenceRPM == nil)
    }

    @Test func deltaCalculator_zeroTimeDelta_skipsSpeed() throws {
        var calc = CSCDeltaCalculator(wheelCircumferenceMeters: 2.0)
        let m0 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 1, lastEventTime1024: 100),
            crank: nil
        )
        #expect(calc.push(m0) == nil)

        let m1 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 2, lastEventTime1024: 100),
            crank: nil
        )
        #expect(calc.push(m1) == nil)
    }

    @Test func deltaCalculator_crankCadence() throws {
        var calc = CSCDeltaCalculator()
        let m0 = CSCMeasurement(
            wheel: nil,
            crank: CSCCrankSample(cumulativeRevolutions: 10, lastEventTime1024: 0)
        )
        #expect(calc.push(m0) == nil)

        // 10 crank revs in 6144 ticks → 6144/1024 = 6s → 10/6 rev/s * 60 = 100 rpm
        let m1 = CSCMeasurement(
            wheel: nil,
            crank: CSCCrankSample(cumulativeRevolutions: 20, lastEventTime1024: 6144)
        )
        guard let u = calc.push(m1) else {
            Issue.record("Expected derived update")
            return
        }
        #expect(u.cadenceRPM != nil)
        if let rpm = u.cadenceRPM {
            #expect(abs(rpm - 100.0) < 0.001)
        }
        #expect(u.speedMetersPerSecond == nil)
    }

    @Test func deltaCalculator_wheelUInt32Wraparound() throws {
        var calc = CSCDeltaCalculator(wheelCircumferenceMeters: 1.0)
        let m0 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: .max - 4, lastEventTime1024: 0),
            crank: nil
        )
        #expect(calc.push(m0) == nil)

        let m1 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 5, lastEventTime1024: 1024),
            crank: nil
        )
        guard let u = calc.push(m1) else {
            Issue.record("Expected derived update")
            return
        }
        // 10 revs in 1s, circumference 1m → 10 m/s, 10m delta
        #expect(u.distanceDeltaMeters == 10.0)
        #expect(u.speedMetersPerSecond == 10.0)
    }

    @Test func deltaCalculator_timeUInt16Wraparound() throws {
        var calc = CSCDeltaCalculator(wheelCircumferenceMeters: 2.0)
        // 65534 → 0 is a UInt16 time delta of 2 ticks (wrapping).
        let m0 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 0, lastEventTime1024: .max - 1),
            crank: nil
        )
        #expect(calc.push(m0) == nil)

        let m1 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 1, lastEventTime1024: 0),
            crank: nil
        )
        guard let u = calc.push(m1) else {
            Issue.record("Expected derived update")
            return
        }
        let dt = 2.0 / 1024.0
        #expect(u.distanceDeltaMeters == 2.0)
        #expect(abs((u.speedMetersPerSecond ?? 0) - (2.0 / dt)) < 0.0001)
    }
}
