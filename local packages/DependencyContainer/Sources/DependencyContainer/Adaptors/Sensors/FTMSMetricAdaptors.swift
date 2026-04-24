//
//  FTMSMetricAdaptors.swift
//  DependencyContainer
//

import Combine
import CoreLogic
import FitnessMachineService
import Foundation

@MainActor
enum FTMSMetricAdaptors {
    static func speed(manager: FitnessMachineSensorManager) -> AnyMetric<UnitSpeed> {
        AnyMetric(publisher: manager.speed, isAvailable: manager.hasConnectedSensor)
    }

    static func cadence(manager: FitnessMachineSensorManager) -> AnyMetric<UnitFrequency> {
        AnyMetric(publisher: manager.cadence, isAvailable: manager.hasConnectedSensor)
    }
}
