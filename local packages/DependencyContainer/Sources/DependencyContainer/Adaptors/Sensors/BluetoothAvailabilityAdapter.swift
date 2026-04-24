//
//  BluetoothAvailabilityAdapter.swift
//  DependencyContainer
//
//  1:1 map from `CSCBluetoothAvailability` to `SettingsVM.BluetoothAvailability` at the composition root (ADR-0009).

import Combine
import CyclingSpeedAndCadenceService
import Foundation
import SettingsVM

/// Projects `CyclingSpeedAndCadenceService.CSCBluetoothAvailability` into `SettingsVM.BluetoothAvailability` (1:1).
enum BluetoothAvailabilityAdapter {
    static func map(_ value: CSCBluetoothAvailability) -> BluetoothAvailability {
        switch value {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .unsupported: return .unsupported
        case .resetting: return .resetting
        case .poweredOff: return .poweredOff
        case .poweredOn: return .poweredOn
        }
    }

    static func publisher(
        source: AnyPublisher<CSCBluetoothAvailability, Never>
    ) -> AnyPublisher<BluetoothAvailability, Never> {
        source.map { map($0) }.eraseToAnyPublisher()
    }
}
