//
//  UnitFrequency+BPM.swift
//  HeartRateService
//

import Foundation

extension UnitFrequency {
    /// Beats per minute for heart rate (defined in this package only; do not add to CoreLogic).
    public static let beatsPerMinute = UnitFrequency(
        symbol: "bpm",
        converter: UnitConverterLinear(coefficient: 1.0 / 60.0)
    )
}
