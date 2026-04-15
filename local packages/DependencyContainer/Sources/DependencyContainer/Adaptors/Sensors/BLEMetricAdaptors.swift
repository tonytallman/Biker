//
//  BLEMetricAdaptors.swift
//  DependencyContainer
//

import Combine
import CoreLogic
import CyclingSpeedAndCadenceService
import Foundation

@MainActor
enum BLEMetricAdaptors {
    static func speed(manager: BluetoothSensorManager) -> AnyMetric<UnitSpeed> {
        let publisher = manager.derivedUpdates
            .compactMap { update -> Measurement<UnitSpeed>? in
                guard let value = update.speedMetersPerSecond else { return nil }
                return Measurement(value: value, unit: UnitSpeed.metersPerSecond)
            }
        return AnyMetric(publisher: publisher, isAvailable: manager.hasConnectedSensor)
    }

    static func cadence(manager: BluetoothSensorManager) -> AnyMetric<UnitFrequency> {
        let publisher = manager.derivedUpdates
            .compactMap { update -> Measurement<UnitFrequency>? in
                guard let value = update.cadenceRPM else { return nil }
                return Measurement(value: value, unit: UnitFrequency.revolutionsPerMinute)
            }
        return AnyMetric(publisher: publisher, isAvailable: manager.hasConnectedSensor)
    }

    static func distanceDelta(manager: BluetoothSensorManager) -> AnyMetric<UnitLength> {
        let publisher = manager.derivedUpdates
            .compactMap { update -> Measurement<UnitLength>? in
                guard let value = update.distanceDeltaMeters else { return nil }
                return Measurement(value: value, unit: UnitLength.meters)
            }
        return AnyMetric(publisher: publisher, isAvailable: manager.hasConnectedSensor)
    }
}
