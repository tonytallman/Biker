//
//  CadenceMetricProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 10 DEC 2025.
//

import Foundation
import Combine

/// Any type that can provide cadence values
public protocol CadenceMetricProvider {
    /// A publisher of cadence values
    var cadence: AnyPublisher<Cadence, Never> { get }
}

public typealias Cadence = Measurement<UnitFrequency>

extension UnitFrequency {
    /// Revolutions per minute (RPM) - a custom frequency unit for cycling cadence
    public static let revolutionsPerMinute = UnitFrequency(
        symbol: "rpm",
        converter: UnitConverterLinear(coefficient: 1.0 / 60.0)
    )
}
