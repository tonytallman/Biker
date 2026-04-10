//
//  AccumulatingMetric.swift
//  CoreLogic
//

import Combine
import Foundation

/// Running sum of measurement samples while the context's activity is ``ActivityState/active``.
public final class AccumulatingMetric<U: Dimension>: Metric {
    public typealias UnitType = U

    public let publisher: AnyPublisher<Measurement<U>, Never>

    /// - Parameters:
    ///   - source: Incremental measurements (e.g. distance deltas or time ticks).
    ///   - context: Shared activity state (e.g. from auto-pause for the current ride).
    public init(source: some Publisher<Measurement<U>, Never>, context: MetricContext) {
        let zero = Measurement<U>(value: 0, unit: U.baseUnit())
        self.publisher = source.statistic(
            whileActive: context.activityState,
            initial: zero,
            reduce: { $0 + $1 }
        )
    }
}
