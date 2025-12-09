//
//  MetricsProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation

/// Provides all of the metrics to be collected and displayed in the app.
public final class MetricsProvider {
    public let speedMetricProvider: SpeedMetricProvider

    public init(speedMetricProvider: SpeedMetricProvider) {
        self.speedMetricProvider = speedMetricProvider
    }
}
