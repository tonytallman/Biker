//
//  SpeedMetricProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine

/// Any type that can provide speed values
protocol SpeedMetricProvider {
    /// A publisher of speed values
    var speed: AnyPublisher<Measurement<UnitSpeed>, Never> { get }
}
