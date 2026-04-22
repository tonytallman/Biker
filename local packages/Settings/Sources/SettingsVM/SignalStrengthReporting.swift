//
//  SignalStrengthReporting.swift
//  SettingsVM
//

import Combine
import Foundation

/// Optional capability: discovered (or in-range) sensors that report signal strength.
@MainActor
public protocol SignalStrengthReporting: Sensor {
    var rssi: AnyPublisher<Int, Never> { get }
}
