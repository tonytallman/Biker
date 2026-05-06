//
//  HeartRateService.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Foundation

extension UnitFrequency {
    /// One beat per minute; base representation matches ``UnitFrequency`` (hertz) via `1/60` Hz per bpm.
    static let beatsPerMinute = UnitFrequency(
        symbol: "bpm",
        converter: UnitConverterLinear(coefficient: 1.0 / 60.0)
    )
}
