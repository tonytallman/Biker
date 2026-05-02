//
//  SensorRowID.swift
//  SettingsVM
//

import Foundation

/// Stable identity for a known or discovered sensor **row** in Settings when one peripheral can back several ``SensorType``s (ADR-0011).
/// Underlying ``Sensor.id`` remains the BLE `peripheral.identifier`; this pairs it with the protocol family for unique SwiftUI / navigation keys.
public struct SensorRowID: Hashable, Sendable {
    public let sensorID: UUID
    public let type: SensorType

    public init(sensorID: UUID, type: SensorType) {
        self.sensorID = sensorID
        self.type = type
    }
}
