//
//  HRMetricAdaptors.swift
//  DependencyContainer
//

import Combine
import CoreLogic
import Foundation
import HeartRateService

@MainActor
enum HRMetricAdaptors {
    static func heartRate(manager: HeartRateSensorManager) -> AnyMetric<UnitFrequency> {
        AnyMetric(publisher: manager.heartRate, isAvailable: manager.hasConnectedSensor)
    }
}
