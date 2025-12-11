//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation
import CoreLogic
import SpeedFromLocationServices

/// Dependency container and composition root for the Biker app. It exposes the root object, ``ContentViewModel``, from which all other objects are indirectly accessed.
@MainActor
final public class DependencyContainer {
    private let preferences = Preferences()
    private let logger = ConsoleLogger()
    private let metricsProvider: MetricsProvider
    
    // Retain the publishers to keep their timers running
    private let speedPublisher: AnyPublisher<Measurement<UnitSpeed>, Never>
    private let cadencePublisher: AnyPublisher<Measurement<UnitFrequency>, Never>
    
    // Retain SpeedService to keep location manager running (needed as CLLocationManagerDelegate)
    private let speedService: SpeedService

    public init() {
        speedService = SpeedService()
        #if DEBUG
        speedPublisher = FakeSpeedProvider.makeSpeed()
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        cadencePublisher = FakeCadenceProvider.makeCadence()
            .inUnits(Just(.revolutionsPerMinute).eraseToAnyPublisher())
        #else
        speedPublisher = speedService.speed
            .inUnits(preferences.speedUnits.eraseToAnyPublisher())
        cadencePublisher = Empty<Measurement<UnitFrequency>, Never>()
            .inUnits(Just(.revolutionsPerMinute).eraseToAnyPublisher())
        #endif
        metricsProvider = MetricsProvider(speed: speedPublisher, cadence: cadencePublisher)
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

