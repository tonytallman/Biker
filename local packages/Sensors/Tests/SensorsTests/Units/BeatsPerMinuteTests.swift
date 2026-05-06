//
//  UnitFrequencyExtensionsTests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct BeatsPerMinuteTests {
    @Test func beatsPerMinuteSymbolAndConversion() {
        #expect(UnitFrequency.beatsPerMinute.symbol == "bpm")
        let sixty = Measurement(value: 60, unit: UnitFrequency.beatsPerMinute)
        #expect(sixty.converted(to: .hertz).value == 1.0)
        let oneHz = Measurement(value: 1, unit: UnitFrequency.hertz)
        #expect(oneHz.converted(to: UnitFrequency.beatsPerMinute).value == 60)
    }
}
