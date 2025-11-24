//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import SpeedFromLocationServices

/// Dependency container and composition root for the Biker app. It exposes the root object, ``ContentViewModel``, from which all other objects are indirectly accessed.
final public class DependencyContainer {
    private let preferences = Preferences()
    private let logger = ConsoleLogger()
    private let speedProvider: SpeedMetricProvider
    private let metricsProvider: MetricsProvider

    public init() {
        speedProvider = SpeedService()
            .asSpeedMetricProvider()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        metricsProvider = MetricsProvider(speedMetricProvider: speedProvider)
    }

    public func getContentViewModel() -> ContentViewModel {
        ContentViewModel(metricsProvider: metricsProvider)
    }
}
