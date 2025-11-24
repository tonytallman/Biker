//
//  SpeedServiceAdaptor.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/24/25.
//

import Combine
import Foundation
import SpeedFromLocationServices

/// Adaptor that takes a ``SpeedService`` instance and makes it look like a ``SpeedMetricProvider`` instance.
final class SpeedServiceAdaptor: SpeedMetricProvider {
    let speed: AnyPublisher<Measurement<UnitSpeed>, Never>

    init(speedService: SpeedFromLocationServices.SpeedService) {
        // SpeedService.speed is in meters per second, according to the documentation.
        speed = speedService.speed
            .map { Measurement(value: $0, unit: .metersPerSecond) }
            .eraseToAnyPublisher()
    }
}

extension SpeedFromLocationServices.SpeedService {
    func asSpeedMetricProvider() -> SpeedServiceAdaptor {
        SpeedServiceAdaptor(speedService: self)
    }
}
