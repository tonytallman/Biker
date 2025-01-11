//
//  MetricsProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation

final public class MetricsProvider {
    public static let shared = CompositionRoot.shared.getMetricsProvider()

    public let speedMetricProvider: SpeedMetricProvider

    init(speedMetricProvider: SpeedMetricProvider) {
        self.speedMetricProvider = speedMetricProvider
    }
}
