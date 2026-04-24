//
//  SensorProvider.swift
//  SettingsVM
//

import Combine
import Foundation

/// Aggregated sensor discovery and known-sensor lists for Settings.
@MainActor
public protocol SensorProvider {
    var knownSensors: AnyPublisher<[any Sensor], Never> { get }
    var discoveredSensors: AnyPublisher<[any Sensor], Never> { get }
    func scan()
    func stopScan()
}
