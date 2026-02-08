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
import MetricsFromCoreLocation
import SettingsModel
import SettingsVM

/// Dependency container and composition root for the Biker app. It exposes the root object, ``MainViewModel``, from which all other objects are indirectly accessed.
@MainActor
final public class DependencyContainer {
    private let settings = Settings()
    private let logger = ConsoleLogger()
    private let metricsProvider: MetricsProvider
    
    // Retain the publishers to keep their timers running
    private let speedPublisher: AnyPublisher<Measurement<UnitSpeed>, Never>
    private let cadencePublisher: AnyPublisher<Measurement<UnitFrequency>, Never>
    private let distancePublisher: AnyPublisher<Measurement<UnitLength>, Never>
    private let timePublisher: AnyPublisher<Measurement<UnitDuration>, Never>
    
    // Retain SpeedAndDistanceService to keep location manager running (needed as CLLocationManagerDelegate)
    private let speedAndDistanceService: SpeedAndDistanceService
    
    // Retain TimeService to keep timer running
    private let timeService: TimeService
    
    // Retain AutoPauseService to keep subscriptions active
    private let autoPauseService: AutoPauseService

    public init() {
        speedAndDistanceService = SpeedAndDistanceService()
        
        // Create TimeService with 1 second period
        timeService = TimeService(period: Measurement(value: 1.0, unit: .seconds))
        
        #if DEBUG
        // Fake metrics with cadence as the single source of truth
        let fake = FakeMetricsProvider.make()
        
        // Raw speed (before unit conversion)
        let rawSpeed = fake.speed
        
        // Auto-pause service
        autoPauseService = AutoPauseService(
            speed: rawSpeed,
            threshold: settings.autoPauseThreshold
        )
        
        // Display-converted speed
        speedPublisher = rawSpeed.inUnits(settings.speedUnits.eraseToAnyPublisher())
        cadencePublisher = fake.cadence
            .inUnits(Just(.revolutionsPerMinute).eraseToAnyPublisher())
        distancePublisher = fake.distanceDelta
            .accumulating(whileActive: autoPauseService.activityState)
            .inUnits(settings.distanceUnits.eraseToAnyPublisher())
        #else
        // Raw speed (before unit conversion)
        let rawSpeed = speedAndDistanceService.speed
        
        // Auto-pause service
        autoPauseService = AutoPauseService(
            speed: rawSpeed,
            threshold: settings.autoPauseThreshold
        )
        
        // Display-converted speed
        speedPublisher = rawSpeed.inUnits(settings.speedUnits.eraseToAnyPublisher())
        cadencePublisher = Empty<Measurement<UnitFrequency>, Never>()
            .inUnits(Just(.revolutionsPerMinute).eraseToAnyPublisher())
        distancePublisher = speedAndDistanceService.distanceDelta
            .accumulating(whileActive: autoPauseService.activityState)
            .inUnits(settings.distanceUnits.eraseToAnyPublisher())
        #endif
        
        // Time with auto-pause
        timePublisher = timeService.timePulse.accumulating(whileActive: autoPauseService.activityState)
        
        metricsProvider = MetricsProvider(speed: speedPublisher, cadence: cadencePublisher)
    }

    private func getDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(speed: speedPublisher, cadence: cadencePublisher, time: timePublisher, distance: distancePublisher)
    }
    
    private func getSettingsViewModel() -> SettingsVM.SettingsViewModel {
        SettingsVM.SettingsViewModel(settings: settings)
    }
    
    public func getMainViewModel() -> MainViewModel {
        return MainViewModel(
            dashboardViewModelFactory: getDashboardViewModel,
            settingsViewModelFactory: getSettingsViewModel
        )
    }
}
