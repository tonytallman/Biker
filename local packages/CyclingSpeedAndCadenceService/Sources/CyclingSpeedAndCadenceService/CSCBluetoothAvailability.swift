//
//  CSCBluetoothAvailability.swift
//  CyclingSpeedAndCadenceService
//
//  Package-local Bluetooth stack / permission / power state (not SettingsVM).
//  DependencyContainer maps 1:1 to `SettingsVM.BluetoothAvailability`.
//

@preconcurrency import CoreBluetooth
import Foundation

public enum CSCBluetoothAvailability: Sendable, Hashable, CaseIterable {
    case notDetermined
    case denied
    case restricted
    case unsupported
    case resetting
    case poweredOff
    case poweredOn
}

public enum CSCBluetoothAvailabilityReducer: Sendable {
    /// Reduces Core Bluetooth `authorization` + `state` to a single availability value
    /// (ADR-0007). Permission outcomes take precedence over power state; then radio state
    /// when `authorization` is `allowedAlways`.
    public static func reduce(
        authorization: CBManagerAuthorization,
        state: CBManagerState
    ) -> CSCBluetoothAvailability {
        switch authorization {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .allowedAlways:
            return reduceAllowedAlways(state: state)
        @unknown default:
            return .notDetermined
        }
    }

    private static func reduceAllowedAlways(state: CBManagerState) -> CSCBluetoothAvailability {
        switch state {
        case .unknown:
            // Still bootstrapping; treat like indeterminate (Phase 04 risk: first prompt).
            return .notDetermined
        case .resetting:
            return .resetting
        case .unsupported:
            return .unsupported
        case .unauthorized:
            // Legacy central state; permission effectively denied.
            return .denied
        case .poweredOff:
            return .poweredOff
        case .poweredOn:
            return .poweredOn
        @unknown default:
            return .notDetermined
        }
    }
}
