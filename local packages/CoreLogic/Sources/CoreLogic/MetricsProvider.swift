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
    public let cadenceMetricProvider: CadenceMetricProvider

    public init(speedMetricProvider: SpeedMetricProvider, cadenceMetricProvider: CadenceMetricProvider) {
        self.speedMetricProvider = speedMetricProvider
        self.cadenceMetricProvider = cadenceMetricProvider
    }
}
