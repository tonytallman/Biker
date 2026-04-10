//
//  MinimumMetric.swift
//  CoreLogic
//

import Combine
import Foundation

/// Running minimum of measurement samples while the context's activity is ``ActivityState/active``.
public final class MinimumMetric<U: Dimension>: Metric {
    public typealias UnitType = U

    public let publisher: AnyPublisher<Measurement<U>, Never>

    /// - Parameters:
    ///   - source: Instantaneous samples (e.g. heart rate).
    ///   - context: Shared activity state (e.g. from auto-pause for the current ride).
    public init(source: some Publisher<Measurement<U>, Never>, context: MetricContext) {
        self.publisher = source.statistic(
            whileActive: context.activityState,
            initial: nil
        ) { current, next in
            let a = current.converted(to: U.baseUnit())
            let b = next.converted(to: U.baseUnit())
            return a.value <= b.value ? a : b
        }
    }
}
