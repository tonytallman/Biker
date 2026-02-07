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
    /// Use `.inUnits()` after `.accumulating()` to convert to desired display units.
    /// - Returns: A publisher that emits the accumulated sum after each input.
    public func accumulating<UnitType: Dimension>() -> AnyPublisher<Measurement<UnitType>, Never> where Output == Measurement<UnitType> {
        let zero = Measurement<UnitType>(value: 0, unit: UnitType.baseUnit())
        return self.scan(zero, +)
            .eraseToAnyPublisher()
    }
    
    /// Accumulates measurement values into a running total, but only while activity state is `.active`.
    /// When activity state is `.paused`, accumulation stops and the last accumulated value is maintained.
    /// The output uses the base unit for the dimension (e.g., meters for UnitLength).
    /// Use `.inUnits()` after `.accumulating(whileActive:)` to convert to desired display units.
    /// - Parameter activityState: A publisher that emits the current activity state.
    /// - Returns: A publisher that emits the accumulated sum after each input, but only while active.
    public func accumulating<UnitType: Dimension>(
        whileActive activityState: some Publisher<ActivityState, Never>
    ) -> AnyPublisher<Measurement<UnitType>, Never>
    where Output == Measurement<UnitType> {
        let zero = Measurement<UnitType>(value: 0, unit: UnitType.baseUnit())

        // Tag each measurement with an incrementing sequence number
        let tagged = self.scan((seq: 0, value: zero)) { state, measurement in
            (seq: state.seq + 1, value: measurement)
        }

        return Publishers.CombineLatest(tagged, activityState)
            .scan((accumulated: zero, lastSeq: 0)) { state, input in
                let ((seq, measurement), activity) = input
                guard activity == .active, seq != state.lastSeq else {
                    return (accumulated: state.accumulated, lastSeq: seq)
                }
                let newValue = Measurement<UnitType>(
                    value: state.accumulated.value
                         + measurement.converted(to: UnitType.baseUnit()).value,
                    unit: UnitType.baseUnit()
                )
                return (accumulated: newValue, lastSeq: seq)
            }
            .map(\.accumulated)
            .eraseToAnyPublisher()
    }
}
