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
    }

    @Test func truncated_fails() {
        var d = Data([0x00, 0x00, 0x10])
        let r = IndoorBikeDataParser.parse(d)
        guard case .failure = r else {
            Issue.record("Expected failure")
            return
        }
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
    }
}
