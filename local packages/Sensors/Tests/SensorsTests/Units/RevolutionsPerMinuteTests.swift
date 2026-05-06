//
//  RevolutionsPerMinuteTests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct RevolutionsPerMinuteTests {
    @Test func revolutionsPerMinuteSymbolAndConversion() {
        #expect(UnitFrequency.revolutionsPerMinute.symbol == "rpm")
        let sixty = Measurement(value: 60, unit: UnitFrequency.revolutionsPerMinute)
        #expect(sixty.converted(to: .hertz).value == 1.0)
        let oneHz = Measurement(value: 1, unit: UnitFrequency.hertz)
        #expect(oneHz.converted(to: UnitFrequency.revolutionsPerMinute).value == 60)
    }
}
