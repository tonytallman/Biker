//
//  CompositionRoot.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation

struct CompositionRoot {
    static let shared = CompositionRoot()

    private init() { }

    private let speedProvider: SpeedMetricProvider = FakeSpeedProvider()

    func getMetricsProvider() -> MetricsProvider {
        MetricsProvider(speedMetricProvider: speedProvider)
    }
}
