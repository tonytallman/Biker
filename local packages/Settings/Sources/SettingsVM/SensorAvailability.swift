//
//  SensorAvailability.swift
//  SettingsVM
//

import Foundation

/// Gating of sensor data and control for Settings: only ``available(_:)`` may expose a ``SensorProvider``.
public enum SensorAvailability: @unchecked Sendable {
    case notDetermined
    case denied
    case restricted
    case unsupported
    case resetting
    case poweredOff
    case available(any SensorProvider)
}

/// Equality compares **case** only: two ``available`` values are always equal to each other
/// (existential identity is ignored). This is sufficient for `removeDuplicates` on the availability stream
/// and for "did the UI gating category change?".
extension SensorAvailability: Equatable {
    public static func == (lhs: SensorAvailability, rhs: SensorAvailability) -> Bool {
        switch (lhs, rhs) {
        case (.notDetermined, .notDetermined): return true
        case (.denied, .denied): return true
        case (.restricted, .restricted): return true
        case (.unsupported, .unsupported): return true
        case (.resetting, .resetting): return true
        case (.poweredOff, .poweredOff): return true
        case (.available, .available): return true
        default: return false
        }
    }
}

extension SensorAvailability {
    /// Drives the Sensors section layout (SEN-PERM-1, SEN-PERM-3, SEN-PERM-4).
    public var sensorsSectionState: SensorsSectionState {
        switch self {
        case .notDetermined, .denied, .restricted:
            return .permissionBlocked
        case .unsupported, .resetting, .poweredOff:
            return .bluetoothUnavailable
        case .available:
            return .normal
        }
    }
}

/// Maps system ``BluetoothAvailability`` to ``SensorAvailability`` (`.poweredOn` is handled by the
/// composition root, which injects the ``SensorProvider`` in `.available`).
public enum BluetoothAvailabilityMapping {
    public static func sensorAvailability(
        for bluetooth: BluetoothAvailability,
        provider: any SensorProvider
    ) -> SensorAvailability {
        if bluetooth == .poweredOn { return .available(provider) }
        switch bluetooth {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .unsupported: return .unsupported
        case .resetting: return .resetting
        case .poweredOff: return .poweredOff
        case .poweredOn: return .available(provider)
        }
    }
}
