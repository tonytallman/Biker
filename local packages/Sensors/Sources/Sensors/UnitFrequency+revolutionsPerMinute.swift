//
//  UnitFrequency+revolutionsPerMinute.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import Foundation

extension UnitFrequency {
    /// Rotations per minute; base representation matches ``UnitFrequency`` (hertz) via `1/60` Hz per rpm.
    static let revolutionsPerMinute = UnitFrequency(
        symbol: "rpm",
        converter: UnitConverterLinear(coefficient: 1.0 / 60.0)
    )
}
