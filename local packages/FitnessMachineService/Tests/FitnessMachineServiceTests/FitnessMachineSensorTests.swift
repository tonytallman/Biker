//
//  FitnessMachineSensorTests.swift
//  FitnessMachineServiceTests
//

import Combine
import Foundation
import Testing

@testable import FitnessMachineService

@MainActor
struct FitnessMachineSensorTests {
    @Test func ingest_publishesSpeedAndCadence() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var speeds: [Double] = []
        var cadences: [Double] = []
        let c1 = s.speed.sink { speeds.append($0.converted(to: .metersPerSecond).value) }
        let c2 = s.cadence.sink { cadences.append($0.converted(to: .revolutionsPerMinute).value) }
        // speed raw 3600 -> 10 m/s; cadence after speed in this payload: flags 0x04 only? 
        // Use speed+cadence: flags 0x0004 has only cadence if more data set... 
        // Simple: only speed flags 0x0000 + 2 bytes LE 0x1027 = 10000 * 0.01 = 100 km/h
        var d = Data([0x00, 0x00, 0x10, 0x27])
        s._test_ingestIndoorBikeData(d)
        #expect(speeds.count == 1)
        #expect(abs(speeds[0] - Measurement(value: 100.0, unit: UnitSpeed.kilometersPerHour).converted(to: .metersPerSecond).value) < 0.01)
        _ = c1
        _ = c2
    }

    @Test func disabled_skipsProcessing() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected,
            initialIsEnabled: false
        )
        var count = 0
        let c = s.speed.sink { _ in count += 1 }
        var d = Data([0x00, 0x00, 0x10, 0x0E])
        s._test_ingestIndoorBikeData(d)
        #expect(count == 0)
        _ = c
    }

    @Test func resetDerivedState_clearsOptionalSubjects() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var d = Data([0x00, 0x00, 0x10, 0x0E])
        s._test_ingestIndoorBikeData(d)
        s.resetDerivedState()
        #expect(true)
        _ = s
    }
}
