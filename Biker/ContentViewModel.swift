//
//  BikerViewModel.swift
//  Biker
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine
import BikerCore

final class ContentViewModel: ObservableObject {
    @Published var speed: Measurement<UnitSpeed>?

    private var cancellables: Set<AnyCancellable> = []

    init(metricsProvider: MetricsProvider) {
        metricsProvider.speedMetricProvider.speed
            .sink { [weak self] in
                self?.speed = $0
            }
            .store(in: &cancellables)
    }

    #if DEBUG
    init(speed: Measurement<UnitSpeed>) {
        self.speed = speed
    }
    #endif
}
