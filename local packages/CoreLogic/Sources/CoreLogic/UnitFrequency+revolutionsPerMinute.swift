//
//  UnitFrequency+revolutionsPerMinute.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation

extension UnitFrequency {
    /// Revolutions per minute (RPM) - a custom frequency unit for cycling cadence
    public static let revolutionsPerMinute = UnitFrequency(
        symbol: "rpm",
        converter: UnitConverterLinear(coefficient: 1.0 / 60.0)
    )
}
