//
//  SpeedServiceAdaptor.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/24/25.
//

import Combine
import Foundation
import CoreLogic
import SpeedFromLocationServices

/// Adaptor that takes a ``SpeedService`` instance and makes it look like a ``SpeedMetricProvider`` instance.
public final class SpeedServiceAdaptor: SpeedMetricProvider {
    public let speed: AnyPublisher<Measurement<UnitSpeed>, Never>

    public init(speedService: SpeedFromLocationServices.SpeedService) {
        // SpeedService.speed is in meters per second, according to the documentation.
        speed = speedService.speed
            .map { Measurement(value: $0, unit: .metersPerSecond) }
            .eraseToAnyPublisher()
    }
}

extension SpeedFromLocationServices.SpeedService {
    public func asSpeedMetricProvider() -> SpeedServiceAdaptor {
        SpeedServiceAdaptor(speedService: self)
    }
}
