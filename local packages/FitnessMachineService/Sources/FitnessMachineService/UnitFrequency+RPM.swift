//
//  UnitFrequency+RPM.swift
//  FitnessMachineService
//

import Foundation

extension UnitFrequency {
    /// Revolutions per minute (RPM) for cycling cadence (matches CoreLogic’s definition; duplicated for package independence).
    static let revolutionsPerMinute = UnitFrequency(
        symbol: "rpm",
        converter: UnitConverterLinear(coefficient: 1.0 / 60.0)
    )
}
