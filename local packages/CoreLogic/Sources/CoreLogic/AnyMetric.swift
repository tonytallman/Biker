//
//  AnyMetric.swift
//  CoreLogic
//

import Combine
import Foundation

/// Type-erased ``Metric`` for a fixed ``Dimension``, e.g. storing ``[AnyMetric<UnitSpeed>]``.
public struct AnyMetric<U: Dimension>: Metric {
    public typealias UnitType = U

    public let publisher: AnyPublisher<Measurement<U>, Never>
    public let isAvailable: AnyPublisher<Bool, Never>

    public init<M: Metric>(_ base: M) where M.UnitType == U {
        publisher = base.publisher
        isAvailable = base.isAvailable
    }

    public init(
        publisher: some Publisher<Measurement<U>, Never>,
        isAvailable: some Publisher<Bool, Never> = Just(true)
    ) {
        self.publisher = publisher.eraseToAnyPublisher()
        self.isAvailable = isAvailable.eraseToAnyPublisher()
    }
}
