//
//  CSCDeltaCalculatorTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

struct CSCDeltaCalculatorTests {
    @Test func wheelSpeedAndDistance() throws {
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

    @Test func zeroTimeDelta_skipsSpeed() throws {
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

    @Test func crankCadence() throws {
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

    @Test func wheelUInt32Wraparound() throws {
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

    @Test func timeUInt16Wraparound() throws {
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

    @Test func wheelCircumferenceChangeAppliesToNextInterval() {
        var calc = CSCDeltaCalculator(wheelCircumferenceMeters: 2.0)
        let m0 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 100, lastEventTime1024: 1024),
            crank: nil
        )
        #expect(calc.push(m0) == nil)
        let m1 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 110, lastEventTime1024: 2048),
            crank: nil
        )
        #expect(calc.push(m1)?.distanceDeltaMeters == 20.0)
        // Next interval uses updated circumference: 3.0 m/rev
        calc.wheelCircumferenceMeters = 3.0
        let m2 = CSCMeasurement(
            wheel: CSCWheelSample(cumulativeRevolutions: 120, lastEventTime1024: 3072),
            crank: nil
        )
        guard let u2 = calc.push(m2) else {
            Issue.record("Expected derived update after circumference change")
            return
        }
        // +10 revs, 1s, 3m/rev → 30 m, 30 m/s
        #expect(u2.distanceDeltaMeters == 30.0)
        #expect(u2.speedMetersPerSecond == 30.0)
    }
}
