//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import SpeedFromLocationServices

/// Dependency container and composition root for the Biker app. It exposes the root object, ``ContentViewModel``, from which all other objects are indirectly accessed.
@MainActor
final public class DependencyContainer {
    private let preferences = Preferences()
    private let logger = ConsoleLogger()
    private let speedProvider: SpeedMetricProvider
    private let metricsProvider: MetricsProvider

    public init() {
        #if DEBUG
        speedProvider = FakeSpeedProvider()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        #else
        speedProvider = SpeedService()
            .asSpeedMetricProvider()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        #endif
        metricsProvider = MetricsProvider(speedMetricProvider: speedProvider)
    }

    private func getDashboardViewModel() -> DashboardViewModel {
        ProductionDashboardViewModel(metricsProvider: metricsProvider)
    }
    
    private func getSettingsViewModel() -> SettingsViewModel {
        ProductionSettingsViewModel()
    }
    
    public func getContentViewModel() -> ContentViewModel {
        return ProductionContentViewModel(
            dashboardViewModelFactory: getDashboardViewModel,
            settingsViewModelFactory: getSettingsViewModel,
        )
    }
}
