//
//  SensorType.swift
//  SettingsVM
//

import Foundation
import SettingsStrings

/// Type identity for a sensor; Settings stays agnostic of concrete BLE GATT services.
public enum SensorType: Sendable, Hashable, CaseIterable {
    case cyclingSpeedAndCadence
    case fitnessMachine
    case heartRate

    public var localizedName: String {
        switch self {
        case .cyclingSpeedAndCadence:
            String(localized: "SensorType.CyclingSpeedAndCadence", bundle: .settingsStrings, comment: "Display name for Cycling Speed and Cadence sensor type")
        case .fitnessMachine:
            String(localized: "SensorType.FitnessMachine", bundle: .settingsStrings, comment: "Display name for fitness machine (FTMS) sensor type")
        case .heartRate:
            String(localized: "SensorType.HeartRate", bundle: .settingsStrings, comment: "Display name for heart rate sensor type")
        }
    }

    /// SF Symbol for list/detail chrome (known-sensor row, etc.); GitHub #37.
    public var sfSymbolName: String {
        switch self {
        case .cyclingSpeedAndCadence:
            "figure.outdoor.cycle.circle"
        case .fitnessMachine:
            "figure.indoor.cycle.circle"
        case .heartRate:
            "heart.circle"
        }
    }

    /// Lower value = higher precedence when the same peripheral UUID is seen from multiple sensor managers (ADR-0012: FTMS > CSCS > HRS).
    public var priorityRank: Int {
        switch self {
        case .fitnessMachine:
            0
        case .cyclingSpeedAndCadence:
            1
        case .heartRate:
            2
        }
    }
}

/// When per-type managers each emit a ``Sensor`` for the same ``Sensor/id``, keep only the best ``SensorType`` per ADR-0012.
@MainActor
public func deduplicateSensorsByPeripheralPriority(_ sensors: [any Sensor]) -> [any Sensor] {
    var bestById: [UUID: any Sensor] = [:]
    for s in sensors {
        if let existing = bestById[s.id] {
            if s.type.priorityRank < existing.type.priorityRank {
                bestById[s.id] = s
            }
        } else {
            bestById[s.id] = s
        }
    }
    return Array(bestById.values)
}
