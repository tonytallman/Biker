//
//  FTMSBluetoothAvailability.swift
//  FitnessMachineService
//

@preconcurrency import CoreBluetooth
import Foundation

public enum FTMSBluetoothAvailability: Sendable, Hashable, CaseIterable {
    case notDetermined
    case denied
    case restricted
    case unsupported
    case resetting
    case poweredOff
    case poweredOn
}

public enum FTMSBluetoothAvailabilityReducer: Sendable {
    public static func reduce(
        authorization: CBManagerAuthorization,
        state: CBManagerState
    ) -> FTMSBluetoothAvailability {
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

    private static func reduceAllowedAlways(state: CBManagerState) -> FTMSBluetoothAvailability {
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
