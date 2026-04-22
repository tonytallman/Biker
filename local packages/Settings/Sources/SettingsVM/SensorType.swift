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
}
