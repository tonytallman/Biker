//
//  CompositionRoot.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation

/// Creates the app objects and factories needed in the app. The only visible instance member is the ``getMetricsProvider()`` function. All other objects are accessed indirectly through the returned metrics provider.
final class CompositionRoot {
    static let shared = CompositionRoot()

    private init() {
        // Use FakeSpeedProvider and convert to use units from Preferences.
        speedProvider = FakeSpeedProvider()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
    }

    private let preferences = Preferences()
    private let speedProvider: SpeedMetricProvider

    /// Returns the ``MetricsProvider`` to be used in the app.
    func getMetricsProvider() -> MetricsProvider {
        MetricsProvider(speedMetricProvider: speedProvider)
    }
}
