//
//  MeasurementPublisherExtension.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/20/25.
//

import Combine
import Foundation

extension Publisher where Failure == Never {
    /// Converts the measurement publisher to the specified units.
    /// Works with any `Measurement` type such as `Measurement<UnitSpeed>`, `Measurement<UnitLength>`, or `Measurement<UnitFrequency>`.
    /// - Parameter units: A publisher that emits the desired units.
    /// - Returns: A publisher that emits measurements converted to the specified units.
    public func inUnits<UnitType: Dimension>(_ units: some Publisher<UnitType, Never>) -> AnyPublisher<Measurement<UnitType>, Never> where Output == Measurement<UnitType> {
        Publishers.CombineLatest(self, units)
            .map { $0.converted(to: $1) }
            .eraseToAnyPublisher()
    }
    
    /// Accumulates measurement values into a running total.
    /// The output uses the base unit for the dimension (e.g., meters for UnitLength).
    /// Use `.inUnits()` after `.accumulated()` to convert to desired display units.
    /// - Returns: A publisher that emits the accumulated sum after each input.
    public func accumulated<UnitType: Dimension>() -> AnyPublisher<Measurement<UnitType>, Never> where Output == Measurement<UnitType> {
        let zero = Measurement<UnitType>(value: 0, unit: UnitType.baseUnit())
        return self.scan(zero, +)
            .eraseToAnyPublisher()
    }
}
