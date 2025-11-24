import Foundation
import Combine
import CoreLogic

final class ContentViewModel: ObservableObject {
    @Published var speed: Double
    @Published var unit: String
    
    private let watchConnectivityService = WatchConnectivityService.shared
    private var cancellables: Set<AnyCancellable> = []

    init(speed: Double = 18.4, unit: String = "mph") {
        self.speed = speed
        self.unit = unit
        
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
