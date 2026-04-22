//
//  WheelDiameterAdjustable.swift
//  SettingsVM
//

import Combine
import Foundation

/// Optional capability: sensors that expose wheel size / roll-out for speed-from-wheel.
@MainActor
public protocol WheelDiameterAdjustable: Sensor {
    var wheelDiameter: AnyPublisher<Measurement<UnitLength>, Never> { get }
    func setWheelDiameter(_ diameter: Measurement<UnitLength>)
}
