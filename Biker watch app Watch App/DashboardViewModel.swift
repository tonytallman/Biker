import Combine
import Foundation

import CoreLogic

final class DashboardViewModel: ObservableObject {
    @Published var speed: Double = 0.0
    @Published var unit: String = ""
    
    private let watchConnectivityService = WatchConnectivityService.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Subscribe to speed updates from phone app via WatchConnectivity
        watchConnectivityService.$receivedSpeed
            .compactMap { $0 }
            .sink { [weak self] newSpeed in
                self?.speed = newSpeed
            }
            .store(in: &cancellables)
        
        watchConnectivityService.$receivedSpeedUnits
            .compactMap { $0 }
            .sink { [weak self] newUnit in
                self?.unit = newUnit
            }
            .store(in: &cancellables)
    }
}
