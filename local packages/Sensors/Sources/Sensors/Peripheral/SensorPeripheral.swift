//
//  SensorPeripheral.swift
//  Sensors
//

import Foundation

/// Superset of the surface used by ``HeartRateService``, ``CyclingSpeedAndCadenceService``, and ``FitnessMachineService``.
///
/// Service-specific ``Delegate`` protocols stay nested on those types; conformers opt in via extensions where needed.
package protocol SensorPeripheral: Sendable {
    func has(serviceId: String) async -> Bool
    func read(characteristicId: String) async -> Data?
    func subscribeTo(characteristicId: String) -> AsyncStream<Data>
}
