//
//  DashboardViewModel.swift
//  PhoneUI
//
//  Observable view model for DashboardView that subscribes to speed and cadence publishers
//

import Combine
import Foundation
import Observation

import DashboardModel

/// Observable view model for DashboardView
@MainActor
@Observable
public final class DashboardViewModel {
    package var primaryMetric: Metric = Metric(title: "Speed", value: "--", units: "--")
    package var secondaryMetric1: Metric = Metric(title: "TIME", value: "--", units: "")
    package var secondaryMetric2: Metric = Metric(title: "DISTANCE", value: "--", units: "")
    package var secondaryMetric3: Metric = Metric(title: "CADENCE", value: "--", units: "--")
    
    private var cancellables: Set<AnyCancellable> = []
    
    /// Initialize with publishers for speed and cadence
    /// - Parameters:
    ///   - speed: Publisher of speed measurements
    ///   - cadence: Publisher of cadence measurements
    public init(
        speed: AnyPublisher<Measurement<UnitSpeed>, Never>,
        cadence: AnyPublisher<Measurement<UnitFrequency>, Never>
    ) {
        // Subscribe to speed publisher
        speed
            .sink { [weak self] speedMeasurement in
                guard let self else { return }
                self.primaryMetric = Metric(
                    title: "Speed",
                    value: self.formatSpeed(speedMeasurement),
                    units: speedMeasurement.unit.symbol
                )
            }
            .store(in: &cancellables)
        
        // Subscribe to cadence publisher
        cadence
            .sink { [weak self] cadenceMeasurement in
                guard let self else { return }
                self.secondaryMetric3 = Metric(
                    title: "CADENCE",
                    value: self.formatCadence(cadenceMeasurement),
                    units: cadenceMeasurement.unit.symbol
                )
            }
            .store(in: &cancellables)
    }
    
    private func formatSpeed(_ speed: Measurement<UnitSpeed>) -> String {
        String(format: "%.1f", speed.value)
    }
    
    private func formatCadence(_ cadence: Measurement<UnitFrequency>) -> String {
        String(format: "%.0f", cadence.value)
    }
}
