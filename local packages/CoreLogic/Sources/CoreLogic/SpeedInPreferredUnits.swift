//
//  SpeedInPreferredUnits.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation
import Combine

/// Decorator that converts a speed metric into the specified units.
public class SpeedInSpecifiedUnits: SpeedMetricProvider {
    // Retain the wrapped instance.
    private let speedMetric: SpeedMetricProvider
    
    public let speed: AnyPublisher<Measurement<UnitSpeed>, Never>

    public init(speedMetric: SpeedMetricProvider, speedUnits: AnyPublisher<UnitSpeed, Never>) {
        self.speedMetric = speedMetric
        self.speed = Publishers.CombineLatest(speedMetric.speed, speedUnits)
            .map { $0.converted(to: $1) }
            .eraseToAnyPublisher()
    }
}

extension SpeedMetricProvider {
    /// Decorates the speed metric to convert it to the specified speed units.
    public func inUnits(_ speedUnits: AnyPublisher<UnitSpeed, Never>) -> SpeedMetricProvider {
        SpeedInSpecifiedUnits(speedMetric: self, speedUnits: speedUnits)
    }
}
