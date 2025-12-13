//
//  MetricsProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation

/// Provides all of the metrics to be collected and displayed in the app.
public final class MetricsProvider {
    public let speed: AnyPublisher<Measurement<UnitSpeed>, Never>
    public let cadence: AnyPublisher<Measurement<UnitFrequency>, Never>

    public init(speed: AnyPublisher<Measurement<UnitSpeed>, Never>, cadence: AnyPublisher<Measurement<UnitFrequency>, Never>) {
        self.speed = speed
        self.cadence = cadence
    }
}
