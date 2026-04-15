//
//  GPSMetricAdaptors.swift
//  DependencyContainer
//

import CoreLogic
import Foundation
import MetricsFromCoreLocation

enum GPSMetricAdaptors {
    static func speed(service: SpeedAndDistanceService) -> AnyMetric<UnitSpeed> {
        AnyMetric(publisher: service.speed)
    }

    static func distanceDelta(service: SpeedAndDistanceService) -> AnyMetric<UnitLength> {
        AnyMetric(publisher: service.distanceDelta)
    }
}
