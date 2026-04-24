//
//  HRBluetoothAvailability.swift
//  HeartRateService
//

@preconcurrency import CoreBluetooth
import Foundation

public enum HRBluetoothAvailability: Sendable, Hashable, CaseIterable {
    case notDetermined
    case denied
    case restricted
    case unsupported
    case resetting
    case poweredOff
    case poweredOn
}

public enum HRBluetoothAvailabilityReducer: Sendable {
    public static func reduce(
        authorization: CBManagerAuthorization,
        state: CBManagerState
    ) -> HRBluetoothAvailability {
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

    private static func reduceAllowedAlways(state: CBManagerState) -> HRBluetoothAvailability {
        switch state {
        case .unknown:
            return .notDetermined
        case .resetting:
            return .resetting
        case .unsupported:
            return .unsupported
        case .unauthorized:
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
