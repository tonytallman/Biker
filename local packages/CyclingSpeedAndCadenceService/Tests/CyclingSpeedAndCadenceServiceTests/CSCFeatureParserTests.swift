//
//  CSCFeatureParserTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

struct CSCFeatureParserTests {
    @Test func parse_nilWhenTooShort() {
        #expect(CSCFeature.parse(Data([0x01])) == nil)
        #expect(CSCFeature.parse(Data()) == nil)
    }

    @Test func parse_wheelOnly() {
        let f = CSCFeature.parse(Data([0x01, 0x00]))
        #expect(f?.supportsWheel == true)
        #expect(f?.supportsCrank == false)
        #expect(f?.isDualCapable == false)
    }

    @Test func parse_crankOnly() {
        let f = CSCFeature.parse(Data([0x02, 0x00]))
        #expect(f?.supportsWheel == false)
        #expect(f?.supportsCrank == true)
    }

    @Test func parse_dual() {
        let f = CSCFeature.parse(Data([0x03, 0x00]))
        #expect(f?.supportsWheel == true)
        #expect(f?.supportsCrank == true)
        #expect(f?.isDualCapable == true)
    }

    @Test func parse_littleEndianHighByte() {
        let f = CSCFeature.parse(Data([0x00, 0x01]))
        #expect(f?.supportsWheel == false)
        #expect(f?.supportsCrank == false)
    }
}
