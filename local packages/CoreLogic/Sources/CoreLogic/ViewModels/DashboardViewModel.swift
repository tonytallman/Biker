//
//  DashboardViewModel.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine

/// Base class for dashboard view models.
@MainActor
open class DashboardViewModel: ObservableObject {
    @Published public var speed: String = "--"
    @Published public var speedUnits: String = "--"
    @Published public var time: String = "--"
    @Published public var distance: String = "--"
    @Published public var cadence: String = "--"
    @Published public var cadenceUnits: String = "--"
    
    public init() {
    }
}

/// Production implementation of DashboardViewModel
public final class ProductionDashboardViewModel: DashboardViewModel {
    private var cancellables: Set<AnyCancellable> = []

    public init(metricsProvider: MetricsProvider) {
        super.init()
        
        metricsProvider.speedMetricProvider.speed
            .sink { [weak self] speed in
                guard let self else { return }
                self.speed = speedFormatted(speed)
                self.speedUnits = speed.unit.symbol
                
                // Send speed to watch app via WatchConnectivity
                Task { @MainActor in
                    WatchConnectivityService.shared.sendSpeed(speed: speed.value, units: speed.unit.symbol)
                }
            }
            .store(in: &cancellables)
        
        metricsProvider.cadenceMetricProvider.cadence
            .sink { [weak self] cadence in
                guard let self else { return }
                self.cadence = cadenceFormatted(cadence)
                self.cadenceUnits = cadence.unit.symbol
            }
            .store(in: &cancellables)
    }

    private func speedFormatted(_ speed: Measurement<UnitSpeed>) -> String {
        String(format: "%.1f", speed.value)
    }
    
    private func cadenceFormatted(_ cadence: Measurement<UnitFrequency>) -> String {
        String(format: "%.0f", cadence.value)
    }
}
