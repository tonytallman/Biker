//
//  DependencyContainer.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import SpeedFromLocationServices
import Logging

/// Creates the app objects and factories needed in the app. The only visible instance member is the ``getMetricsProvider()`` function. All other objects are accessed indirectly through the returned metrics provider.
final class DependencyContainer {
    static let shared = DependencyContainer()

    private init() {
        let speedService = SpeedService(logger: SpeedServiceLoggerAdaptor(loggingService: logger))
        speedProvider = SpeedServiceAdaptor(speedService: speedService)
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
    }

    private let preferences = Preferences()
    private let logger = LoggingService()
    private let speedProvider: SpeedMetricProvider

    /// Returns the ``MetricsProvider`` to be used in the app.
    func getMetricsProvider() -> MetricsProvider {
        MetricsProvider(speedMetricProvider: speedProvider)
    }
}
