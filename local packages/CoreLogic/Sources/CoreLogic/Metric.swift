//
//  Metric.swift
//  CoreLogic
//

import Combine
import Foundation

/// A stream of measurement values suitable for display or further processing.
/// Instantaneous metrics (e.g. current speed) are often plain publishers.
/// Pause-aware reduction types (e.g. ``AccumulatingMetric``) take a ``MetricContext`` and conform to ``Metric``.
public protocol Metric {
    associatedtype UnitType: Dimension

    /// The latest value of this metric (often base units until ``Publisher/inUnits(_:)``).
    var publisher: AnyPublisher<Measurement<UnitType>, Never> { get }

    /// Whether this metric should be considered a live source (e.g. BLE connected vs stalled).
    var isAvailable: AnyPublisher<Bool, Never> { get }
}

extension Metric {
    /// Default: always available (GPS, fake metrics, and existing ``Metric`` types).
    public var isAvailable: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }
}
