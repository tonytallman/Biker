//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation

import CoreLogic
import DashboardModel
import DashboardVM
import MainVM
import SettingsModel
import SettingsVM
import SpeedFromLocationServices

/// Dependency container and composition root for the Biker app. It exposes the root object, ``MainViewModel``, from which all other objects are indirectly accessed.
@MainActor
final public class DependencyContainer {
    private let preferences = Settings()
    private let logger = ConsoleLogger()
    private let metricsProvider: MetricsProvider
    
    // Retain the publishers to keep their timers running
    private let speedPublisher: AnyPublisher<Measurement<UnitSpeed>, Never>
    private let cadencePublisher: AnyPublisher<Measurement<UnitFrequency>, Never>
    
    // Retain SpeedService to keep location manager running (needed as CLLocationManagerDelegate)
    private let speedService: SpeedService
    
    // Retain TimeService to keep timer running
    private let timeService: TimeService

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
        
        // Create TimeService with 1 second period
        timeService = TimeService(period: Measurement(value: 1.0, unit: .seconds))
        
        metricsProvider = MetricsProvider(speed: speedPublisher, cadence: cadencePublisher)
    }

    private func getDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(speed: speedPublisher, cadence: cadencePublisher, time: timeService.time)
    }
    
    private func getSettingsViewModel() -> SettingsVM.SettingsViewModel {
        SettingsVM.SettingsViewModel(preferences: preferences)
    }
    
    public func getMainViewModel() -> MainViewModel {
        return MainViewModel(
            dashboardViewModelFactory: getDashboardViewModel,
            settingsViewModelFactory: getSettingsViewModel
        )
    }
}
