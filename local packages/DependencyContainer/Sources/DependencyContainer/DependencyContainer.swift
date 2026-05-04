//
//  DependencyContainer.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation

import CoreLogic
import DashboardVM
import FitnessMachineService
import HeartRateService
import MainVM
import MetricsFromCoreLocation
import SettingsVM

/// Dependency container and composition root for the Biker app. It exposes the root object, ``MainViewModel``, from which all other objects are indirectly accessed.
@MainActor
final public class DependencyContainer {
    private let settingsDependencies = SettingsDependencies(
        appStorage: UserDefaults.standard.asAppStorage(),
    )
    
    // Retain the publishers to keep their timers running
    private let speedPublisher: AnyPublisher<Measurement<UnitSpeed>, Never>
    private let cadencePublisher: AnyPublisher<Measurement<UnitFrequency>, Never>
    private let distancePublisher: AnyPublisher<Measurement<UnitLength>, Never>
    private let timePublisher: AnyPublisher<Measurement<UnitDuration>, Never>
    /// `nil` when no heart-rate source is available (MET-GEN-2).
    private let heartRatePublisher: AnyPublisher<Measurement<UnitFrequency>?, Never>
    
    // Retain SpeedAndDistanceService to keep location manager running (needed as CLLocationManagerDelegate)
    private let speedAndDistanceService: SpeedAndDistanceService
    
    // Retain TimeService to keep timer running
    private let timeService: TimeService
    
    // Retain AutoPauseService to keep subscriptions active
    private let autoPauseService: AutoPauseService

    /// Retain BLE/GPS metric selectors (release) so subscriptions stay alive.
    private let speedSelector: PrioritizedMetricSelector<UnitSpeed>?
    private let cadenceSelector: PrioritizedMetricSelector<UnitFrequency>?
    private let distanceSelector: PrioritizedMetricSelector<UnitLength>?
    private let hrSelector: PrioritizedMetricSelector<UnitFrequency>?
    private let timeSelector: PrioritizedMetricSelector<UnitDuration>?
    private let totalDistanceSelector: PrioritizedMetricSelector<UnitLength>?

    /// Retain per-family lex adaptors (release) so CSC/FTMS Combine wiring stays active.
    private let cscPeripheralLexMetrics: CSCPeripheralLexMetrics?
    private let ftmsPeripheralLexMetrics: FTMSPeripheralLexMetrics?

    /// Shared metric scope for the current ride (auto-pause, future persistence).
    private let currentRide: MetricContext

    private let distanceMetric: AccumulatingMetric<UnitLength>
    private let timeMetric: AccumulatingMetric<UnitDuration>

    public init() {
        let settings = settingsDependencies.metricsSettings
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

        currentRide = MetricContext(autoPauseService: autoPauseService)

        // Display-converted speed
        speedPublisher = rawSpeed
            .inUnits(settings.speedUnits)
        cadencePublisher = fake.cadence
            .inUnits(Just(.revolutionsPerMinute))
        distanceMetric = AccumulatingMetric<UnitLength>(
            source: fake.distanceDelta,
            context: currentRide
        )
        distancePublisher = distanceMetric.publisher
            .inUnits(settings.distanceUnits)
        speedSelector = nil
        cadenceSelector = nil
        distanceSelector = nil
        hrSelector = nil
        timeSelector = nil
        totalDistanceSelector = nil
        cscPeripheralLexMetrics = nil
        ftmsPeripheralLexMetrics = nil
        heartRatePublisher = fake.cadence
            .map { cad -> Measurement<UnitFrequency>? in
                let rpm = cad.converted(to: .revolutionsPerMinute).value
                let bpm = min(200, max(50, 50 + rpm * 0.2))
                return Measurement(value: bpm, unit: UnitFrequency.beatsPerMinute)
            }
            .eraseToAnyPublisher()
        timeMetric = AccumulatingMetric<UnitDuration>(
            source: timeService.timePulse,
            context: currentRide
        )
        timePublisher = timeMetric.publisher
        #else
        let bleManager = settingsDependencies.bluetoothSensorManager
        let ftmsManager = settingsDependencies.fitnessMachineSensorManager
        let hrManager = settingsDependencies.heartRateSensorManager

        let metricTick = timeService.timePulse.map { _ in () }.eraseToAnyPublisher()

        let cscLex = CSCPeripheralLexMetrics(manager: bleManager)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsManager)
        cscPeripheralLexMetrics = cscLex
        ftmsPeripheralLexMetrics = ftmsLex

        let gpsSpeed = GPSMetricAdaptors.speed(service: speedAndDistanceService)
        let speedSel = PrioritizedMetricSelector(
            sources: [cscLex.speed, ftmsLex.speed, gpsSpeed],
            tick: metricTick
        )
        speedSelector = speedSel

        // Raw speed (before unit conversion)
        let rawSpeed = speedSel.publisher

        // Auto-pause service
        autoPauseService = AutoPauseService(
            speed: rawSpeed,
            threshold: settings.autoPauseThreshold
        )

        currentRide = MetricContext(autoPauseService: autoPauseService)

        // Display-converted speed
        speedPublisher = rawSpeed
            .inUnits(settings.speedUnits)

        let cadSel = PrioritizedMetricSelector(
            sources: [cscLex.cadence, ftmsLex.cadence],
            tick: metricTick
        )
        cadenceSelector = cadSel
        cadencePublisher = cadSel.publisher
            .inUnits(Just(.revolutionsPerMinute))

        let gpsDist = GPSMetricAdaptors.distanceDelta(service: speedAndDistanceService)
        let distSel = PrioritizedMetricSelector(
            sources: [ftmsLex.distanceDelta, cscLex.distanceDelta, gpsDist],
            tick: metricTick
        )
        distanceSelector = distSel
        distanceMetric = AccumulatingMetric<UnitLength>(
            source: distSel.publisher,
            context: currentRide
        )
        let localAccumulatedDistance = AnyMetric<UnitLength>(publisher: distanceMetric.publisher)
        let totalDistSel = PrioritizedMetricSelector(
            sources: [ftmsLex.totalDistance, localAccumulatedDistance],
            tick: metricTick
        )
        totalDistanceSelector = totalDistSel
        distancePublisher = totalDistSel.publisher
            .inUnits(settings.distanceUnits)

        timeMetric = AccumulatingMetric<UnitDuration>(
            source: timeService.timePulse,
            context: currentRide
        )
        let localRideTime = AnyMetric<UnitDuration>(publisher: timeMetric.publisher)
        let timeSel = PrioritizedMetricSelector(
            sources: [ftmsLex.elapsedTime, localRideTime],
            tick: metricTick
        )
        timeSelector = timeSel
        timePublisher = timeSel.publisher

        let hrSel = PrioritizedMetricSelector(
            sources: [
                HRMetricAdaptors.heartRate(manager: hrManager),
                ftmsLex.heartRate,
            ],
            tick: metricTick
        )
        hrSelector = hrSel
        heartRatePublisher = Publishers.CombineLatest(
            hrSel.isAvailable.removeDuplicates(),
            hrSel.publisher
        )
        .map { available, measurement -> Measurement<UnitFrequency>? in
            guard available else { return nil }
            return measurement.converted(to: .beatsPerMinute)
        }
        .removeDuplicates { lhs, rhs in
            switch (lhs, rhs) {
            case (nil, nil): return true
            case let (l?, r?): return l.value == r.value && l.unit == r.unit
            default: return false
            }
        }
        .eraseToAnyPublisher()
        #endif
    }

    private func getDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            speed: speedPublisher,
            cadence: cadencePublisher,
            time: timePublisher,
            distance: distancePublisher,
            heartRate: heartRatePublisher
        )
    }
    
    public func getMainViewModel() -> MainViewModel {
        return MainViewModel(
            dashboardViewModelFactory: getDashboardViewModel,
            settingsViewModelFactory: settingsDependencies.getSettingsViewModel
        )
    }
}
