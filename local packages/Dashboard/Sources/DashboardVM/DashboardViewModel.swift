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
    package var primaryMetric: MetricViewModel = MetricViewModel(title: "Speed", value: "--", units: "--")
    package var secondaryMetric1: MetricViewModel = MetricViewModel(title: "TIME", value: "--", units: "")
    package var secondaryMetric2: MetricViewModel = MetricViewModel(title: "DISTANCE", value: "--", units: "")
    package var secondaryMetric3: MetricViewModel = MetricViewModel(title: "CADENCE", value: "--", units: "--")
    /// Formatted BPM when heart rate is available; `nil` hides the dashboard HR widget.
    package private(set) var heartRateBPM: String?

    private var cancellables: Set<AnyCancellable> = []
    
    /// Initialize with publishers for speed, cadence, time, and distance
    /// - Parameters:
    ///   - speed: Publisher of speed measurements
    ///   - cadence: Publisher of cadence measurements
    ///   - time: Publisher of time measurements
    ///   - distance: Publisher of distance measurements
    ///   - heartRate: Publisher of BPM in `UnitFrequency` (composition root uses beats-per-minute); `nil` when unavailable.
    public init(
        speed: AnyPublisher<Measurement<UnitSpeed>, Never>,
        cadence: AnyPublisher<Measurement<UnitFrequency>, Never>,
        time: AnyPublisher<Measurement<UnitDuration>, Never>,
        distance: AnyPublisher<Measurement<UnitLength>, Never>,
        heartRate: AnyPublisher<Measurement<UnitFrequency>?, Never>
    ) {
        // Subscribe to speed publisher
        speed
            .sink { [weak self] speedMeasurement in
                guard let self else { return }
                self.primaryMetric = MetricViewModel(
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
                self.secondaryMetric3 = MetricViewModel(
                    title: "CADENCE",
                    value: self.formatCadence(cadenceMeasurement),
                    units: cadenceMeasurement.unit.symbol
                )
            }
            .store(in: &cancellables)
        
        // Subscribe to time publisher
        time
            .sink { [weak self] timeMeasurement in
                guard let self else { return }
                self.secondaryMetric1 = MetricViewModel(
                    title: "TIME",
                    value: self.formatTime(timeMeasurement),
                    units: ""
                )
            }
            .store(in: &cancellables)
        
        // Subscribe to distance publisher
        distance
            .sink { [weak self] distanceMeasurement in
                guard let self else { return }
                self.secondaryMetric2 = MetricViewModel(
                    title: "DISTANCE",
                    value: self.formatDistance(distanceMeasurement),
                    units: distanceMeasurement.unit.symbol
                )
            }
            .store(in: &cancellables)

        heartRate
            .sink { [weak self] measurement in
                guard let self else { return }
                if let m = measurement {
                    self.heartRateBPM = String(format: "%.0f", m.value)
                } else {
                    self.heartRateBPM = nil
                }
            }
            .store(in: &cancellables)
    }
    
    private func formatSpeed(_ speed: Measurement<UnitSpeed>) -> String {
        String(format: "%.1f", speed.value)
    }
    
    private func formatCadence(_ cadence: Measurement<UnitFrequency>) -> String {
        String(format: "%.0f", cadence.value)
    }
    
    private func formatTime(_ time: Measurement<UnitDuration>) -> String {
        let totalSeconds = Int(time.converted(to: .seconds).value)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDistance(_ distance: Measurement<UnitLength>) -> String {
        String(format: "%.2f", distance.value)
    }
}
