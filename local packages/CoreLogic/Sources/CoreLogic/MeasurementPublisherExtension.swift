//
//  MeasurementPublisherExtension.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/20/25.
//

import Combine
import Foundation

private struct StatisticScanState<UnitType: Dimension> {
    var accumulated: Measurement<UnitType>?
    var lastSeq: Int
}

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
    
    /// Reduces measurement values with a custom function, but only while activity state is `.active`.
    /// When activity state is `.paused`, the last reduced value is held and new source samples are ignored.
    /// Output values use the base unit for the dimension.
    ///
    /// - Parameters:
    ///   - activityState: Whether reduction runs for each new source value.
    ///   - initial: Seed for the statistic. Pass `nil` to use the first **active** sample as the seed (for running max/min).
    ///   - reduce: Combines the current statistic with the next sample (both in base units).
    /// - Returns: A publisher emitting the current statistic whenever it may have changed.
    public func statistic<UnitType: Dimension>(
        whileActive activityState: some Publisher<ActivityState, Never>,
        initial: Measurement<UnitType>?,
        reduce: @escaping (Measurement<UnitType>, Measurement<UnitType>) -> Measurement<UnitType>
    ) -> AnyPublisher<Measurement<UnitType>, Never>
    where Output == Measurement<UnitType> {
        let zero = Measurement<UnitType>(value: 0, unit: UnitType.baseUnit())
        let tagged = self.scan((seq: 0, value: zero)) { state, measurement in
            (seq: state.seq + 1, value: measurement)
        }

        let seed = initial?.converted(to: UnitType.baseUnit())

        return Publishers.CombineLatest(tagged, activityState)
            .scan(StatisticScanState(accumulated: seed, lastSeq: 0)) { state, input in
                let ((seq, measurement), activity) = input
                guard activity == .active, seq != state.lastSeq else {
                    return StatisticScanState(accumulated: state.accumulated, lastSeq: seq)
                }
                let mBase = measurement.converted(to: UnitType.baseUnit())
                let newAccumulated: Measurement<UnitType>
                if let acc = state.accumulated {
                    newAccumulated = reduce(acc, mBase)
                } else {
                    newAccumulated = mBase
                }
                return StatisticScanState(accumulated: newAccumulated, lastSeq: seq)
            }
            .compactMap(\.accumulated)
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
        return statistic(whileActive: activityState, initial: zero) { $0 + $1 }
    }
}
