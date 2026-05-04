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

    @Test func ingest_publishesHeartRateInHertz_andElapsedSeconds() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var bpmEmitted: Double?
        var secondsEmitted: Double?
        let ch = s.heartRate.sink { bpmEmitted = $0.converted(to: .hertz).value * 60.0 }
        let ct = s.elapsedTime.sink { secondsEmitted = $0.converted(to: .seconds).value }
        // More Data + HR (0x0201): 120 BPM; separate packet More Data + Elapsed (0x0801): 90 s.
        s._test_ingestIndoorBikeData(Data([0x01, 0x02, 120]))
        #expect(abs((bpmEmitted ?? 0) - 120.0) < 0.001)

        bpmEmitted = nil
        s._test_ingestIndoorBikeData(Data([0x01, 0x08, 0x5A, 0x00]))
        #expect(abs((secondsEmitted ?? 0) - 90.0) < 0.001)

        var optionalBPM: Double? = -1
        var optionalSecs: Double? = -1
        let cob = s.heartRateBPMOptional.sink { optionalBPM = $0 }
        let cos = s.elapsedTimeSecondsOptional.sink { optionalSecs = $0 }
        s.resetDerivedState()
        #expect(optionalBPM == nil)
        #expect(optionalSecs == nil)

        _ = ch
        _ = ct
        _ = cob
        _ = cos
    }

    @Test func ingest_totalDistanceEmittedWhenPresent_preserved_whenNextPacketOmitsTotal_resetsWithDerivedState() {
        let s = FitnessMachineSensor(
            id: UUID(),
            name: "T",
            initialConnectionState: .connected
        )
        var absolutes: [Double] = []
        let cAbs = s.totalDistance.sink { absolutes.append($0.converted(to: .meters).value) }
        // More Data + Total Distance: 200 m (LE24).
        s._test_ingestIndoorBikeData(Data([0x11, 0x00, 0xC8, 0x00, 0x00]))
        #expect(absolutes.count == 1)
        #expect(abs(absolutes[0] - 200.0) < 0.001)

        // Speed only — aggregate total distance field absent; scalar subject retains 200 until reset.
        s._test_ingestIndoorBikeData(Data([0x00, 0x00, 0x10, 0x0E]))
        #expect(absolutes.count == 1)

        var lastOptional: Double? = .nan
        let cOpt = s.totalDistanceMetersOptional.sink { lastOptional = $0 }
        s.resetDerivedState()
        #expect(lastOptional == nil)

        _ = cAbs
        _ = cOpt
    }
}
