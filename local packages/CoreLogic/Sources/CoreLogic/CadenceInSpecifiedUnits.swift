//
//  CadenceInSpecifiedUnits.swift
//  BikerCore
//
//  Created by Tony Tallman on 10 DEC 2025.
//

import Foundation
import Combine

/// Decorator that converts a cadence metric into the specified units.
public class CadenceInSpecifiedUnits: CadenceMetricProvider {
    // Retain the wrapped instance.
    private let cadenceMetric: CadenceMetricProvider
    
    public let cadence: AnyPublisher<Cadence, Never>

    public init(cadenceMetric: CadenceMetricProvider, cadenceUnits: AnyPublisher<UnitFrequency, Never>) {
        self.cadenceMetric = cadenceMetric
        self.cadence = Publishers.CombineLatest(cadenceMetric.cadence, cadenceUnits)
            .map { $0.converted(to: $1) }
            .eraseToAnyPublisher()
    }
}

extension CadenceMetricProvider {
    /// Decorates the cadence metric to convert it to the specified cadence units.
    public func inUnits(_ cadenceUnits: AnyPublisher<UnitFrequency, Never>) -> CadenceMetricProvider {
        CadenceInSpecifiedUnits(cadenceMetric: self, cadenceUnits: cadenceUnits)
    }
    
    /// Decorates the cadence metric to convert it to the specified cadence units.
    public func inUnits(_ cadenceUnits: UnitFrequency) -> CadenceMetricProvider {
        CadenceInSpecifiedUnits(cadenceMetric: self, cadenceUnits: Just(cadenceUnits).eraseToAnyPublisher())
    }
}
