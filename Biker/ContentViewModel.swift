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
    @Published var speed = "--"

    private var cancellables: Set<AnyCancellable> = []

    init(metricsProvider: MetricsProvider) {
        metricsProvider.speedMetricProvider.speed
            .sink { [weak self] speed in
                guard let self else { return }
                self.speed = speedFormatted(speed)
            }
            .store(in: &cancellables)
    }

    private func speedFormatted(_ speed: Measurement<UnitSpeed>) -> String {
        speed.formatted()
    }

    #if DEBUG
    init(speed: Measurement<UnitSpeed>) {
        self.speed = speedFormatted(speed)
    }
    #endif
}
