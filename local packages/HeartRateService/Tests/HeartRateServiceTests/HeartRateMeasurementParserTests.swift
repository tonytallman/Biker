//
//  HeartRateMeasurementParserTests.swift
//  HeartRateServiceTests
//

import Foundation
import Testing

@testable import HeartRateService

struct HeartRateMeasurementParserTests {
    @Test func parse_uint8_bpm() {
        let data = Data([0x00, 72])
        guard case let .success(m) = HeartRateMeasurementParser.parse(data) else {
            Issue.record("Expected success")
            return
        }
        #expect(m.bpm == 72)
    }

    @Test func parse_uint16_bpm() {
        // flags bit0 = 1, LE 300 = 0x012C
        let data = Data([0x01, 0x2C, 0x01])
        guard case let .success(m) = HeartRateMeasurementParser.parse(data) else {
            Issue.record("Expected success")
            return
        }
        #expect(m.bpm == 300)
    }

    @Test func parse_empty_fails() {
        guard case let .failure(e) = HeartRateMeasurementParser.parse(Data()) else {
            Issue.record("Expected failure")
            return
        }
        #expect(e == .dataTooShort(minimumBytes: 1))
    }

    @Test func parse_uint8_truncated_fails() {
        let data = Data([0x00])
        guard case let .failure(e) = HeartRateMeasurementParser.parse(data) else {
            Issue.record("Expected failure")
            return
        }
        #expect(e == .dataTooShort(minimumBytes: 2))
    }

    @Test func parse_uint16_truncated_fails() {
        let data = Data([0x01, 0x00])
        guard case let .failure(e) = HeartRateMeasurementParser.parse(data) else {
            Issue.record("Expected failure")
            return
        }
        #expect(e == .dataTooShort(minimumBytes: 3))
    }

    @Test func parse_ignoresTrailingBytes_uint8() {
        // Extra bytes (e.g. flags with RR later) — BPM still at offset 1 for UINT8 format
        let data = Data([0x00, 120, 0x01, 0x02, 0x03, 0x04])
        guard case let .success(m) = HeartRateMeasurementParser.parse(data) else {
            Issue.record("Expected success")
            return
        }
        #expect(m.bpm == 120)
    }
}
