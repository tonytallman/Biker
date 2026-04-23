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
}
