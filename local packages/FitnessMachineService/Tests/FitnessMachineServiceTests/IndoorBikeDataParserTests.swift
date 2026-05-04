//
//  IndoorBikeDataParserTests.swift
//  FitnessMachineServiceTests
//

import Foundation
import Testing

@testable import FitnessMachineService

struct IndoorBikeDataParserTests {
    @Test func emptyBuffer_fails() {
        let r = IndoorBikeDataParser.parse(Data())
        guard case .failure(let e) = r else {
            Issue.record("Expected failure")
            return
        }
        guard case .dataTooShort = e else {
            Issue.record("Expected dataTooShort")
            return
        }
    }

    @Test func flagsOnly_noSpeedNoCadence() {
        // More data set -> no instantaneous speed; no optional fields.
        var d = Data([0x01, 0x00])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond == nil)
        #expect(v.cadenceRPM == nil)
        #expect(v.totalDistanceMeters == nil)
    }

    @Test func instantaneousSpeed_only() {
        // flags = 0 -> speed present. raw 3600 -> 36 km/h -> 10 m/s
        var d = Data([0x00, 0x00, 0x10, 0x0E])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(abs((v.speedMetersPerSecond ?? 0) - 10.0) < 0.001)
        #expect(v.cadenceRPM == nil)
        #expect(v.totalDistanceMeters == nil)
    }

    @Test func instantaneousCadence_only_moreDataNoSpeed() {
        // More data (bit0), instant cadence (bit2): after flags, cadence UInt16
        var d = Data([0x05, 0x00, 0x64, 0x00])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond == nil)
        #expect(v.cadenceRPM == 50.0)
    }

    @Test func speedAndCadence() {
        // speed + average speed skipped? flags: speed (bit0 clear), avg speed (bit1), inst cadence (bit2)
        // = bit1 | bit2 = 6, but bit0 clear so 0x0006
        // Order: inst speed, avg speed, inst cadence
        // inst speed raw 100 -> 1 km/h
        // avg speed raw 0
        // cadence raw 120 -> 60 rpm
        var d = Data([0x06, 0x00])
        d.append(contentsOf: [0x64, 0x00])
        d.append(contentsOf: [0x00, 0x00])
        d.append(contentsOf: [0x78, 0x00])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond != nil)
        #expect(abs((v.cadenceRPM ?? 0) - 60.0) < 0.001)
        #expect(v.totalDistanceMeters == nil)
    }

    @Test func truncated_fails() {
        var d = Data([0x00, 0x00, 0x10])
        let r = IndoorBikeDataParser.parse(d)
        guard case .failure = r else {
            Issue.record("Expected failure")
            return
        }
    }

    @Test func totalDistance_only_moreDataAndDistanceFlag() {
        // More Data (bit0) + Total Distance (bit4): 0x0011, then 1000 m LE24
        let d = Data([0x11, 0x00, 0xE8, 0x03, 0x00])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond == nil)
        #expect(v.cadenceRPM == nil)
        #expect(v.totalDistanceMeters == 1000)
    }

    @Test func heartRatePresent_only() {
        // More Data (bit0) + Heart Rate (bit9): flags LE 0x0201, then 1 BPM octet.
        let d = Data([0x01, 0x02, 0x96])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond == nil)
        #expect(v.cadenceRPM == nil)
        #expect(v.totalDistanceMeters == nil)
        #expect(v.heartRateBPM == 150)
        #expect(v.elapsedTimeSeconds == nil)
    }

    @Test func elapsedTimePresent_only() {
        // More Data + Elapsed Time (bit11): flags LE 0x0801, then UInt16 LE seconds.
        let d = Data([0x01, 0x08, 0x3C, 0x00])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond == nil)
        #expect(v.heartRateBPM == nil)
        #expect(v.elapsedTimeSeconds == 60)
    }

    @Test func realisticTrainerStyle_payload() {
        // Speed + cadence + total distance + inst power (common on trainers)
        // bit0 clear (speed), bit2 cadence, bit4 distance, bit6 power → 0x0054
        var d = Data([0x54, 0x00])
        d.append(contentsOf: [0x20, 0x4E])
        d.append(contentsOf: [0xC8, 0x00])
        d.append(contentsOf: [0x00, 0x00, 0x00])
        d.append(contentsOf: [0x2C, 0x01])
        let r = IndoorBikeDataParser.parse(d)
        guard case .success(let v) = r else {
            Issue.record("Expected success")
            return
        }
        #expect(v.speedMetersPerSecond != nil)
        #expect(v.cadenceRPM != nil)
        #expect(v.totalDistanceMeters == 0)
    }
}
