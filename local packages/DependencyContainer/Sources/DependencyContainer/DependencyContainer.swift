//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import CoreLogic
import SpeedFromLocationServices

/// Dependency container and composition root for the Biker app. It exposes the root object, ``ContentViewModel``, from which all other objects are indirectly accessed.
@MainActor
final public class DependencyContainer {
    private let preferences = Preferences()
    private let logger = ConsoleLogger()
    private let speedProvider: SpeedMetricProvider
    private let cadenceProvider: CadenceMetricProvider
    private let metricsProvider: MetricsProvider

    public init() {
        #if DEBUG
        speedProvider = FakeSpeedProvider()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        cadenceProvider = FakeCadenceProvider()
            .inUnits(.revolutionsPerMinute)
        #else
        speedProvider = SpeedService()
            .asSpeedMetricProvider()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        cadenceProvider = FakeCadenceProvider() // TODO: Replace with production cadence provider
            .inUnits(.revolutionsPerMinute)
        #endif
        metricsProvider = MetricsProvider(speedMetricProvider: speedProvider, cadenceMetricProvider: cadenceProvider)
    }

    private func getDashboardViewModel() -> DashboardViewModel {
        ProductionDashboardViewModel(metricsProvider: metricsProvider)
    }
    
    private func getSettingsViewModel() -> SettingsViewModel {
        ProductionSettingsViewModel(preferences: preferences)
    }
    
    public func getContentViewModel() -> ContentViewModel {
        return ProductionContentViewModel(
            dashboardViewModelFactory: getDashboardViewModel,
            settingsViewModelFactory: getSettingsViewModel,
        )
    }
}

