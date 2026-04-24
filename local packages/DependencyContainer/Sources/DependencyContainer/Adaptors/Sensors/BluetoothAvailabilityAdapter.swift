//
//  BluetoothAvailabilityAdapter.swift
//  DependencyContainer
//
//  Maps per-manager Bluetooth reduction to `SettingsVM.BluetoothAvailability` and combines
//  multiple managers with a most-restrictive rule (ADR-0007 / composition root).

import Combine
import CyclingSpeedAndCadenceService
import FitnessMachineService
import Foundation
import SettingsVM

/// Projects package-local Bluetooth availability into `SettingsVM.BluetoothAvailability`.
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

    static func map(_ value: FTMSBluetoothAvailability) -> BluetoothAvailability {
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

    static func publisher(
        source: AnyPublisher<FTMSBluetoothAvailability, Never>
    ) -> AnyPublisher<BluetoothAvailability, Never> {
        source.map { map($0) }.eraseToAnyPublisher()
    }

    /// Most-restrictive merge: `denied` > `notDetermined` > `unsupported` > `restricted` > `resetting` > `poweredOff` > `poweredOn`.
    static func moreRestrictive(_ a: BluetoothAvailability, _ b: BluetoothAvailability) -> BluetoothAvailability {
        restrictionRank(a) <= restrictionRank(b) ? a : b
    }

    static func combined(
        csc: AnyPublisher<BluetoothAvailability, Never>,
        ftms: AnyPublisher<BluetoothAvailability, Never>
    ) -> AnyPublisher<BluetoothAvailability, Never> {
        Publishers.CombineLatest(csc, ftms)
            .map { moreRestrictive($0, $1) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    static func combined(
        csc: AnyPublisher<CSCBluetoothAvailability, Never>,
        ftms: AnyPublisher<FTMSBluetoothAvailability, Never>
    ) -> AnyPublisher<BluetoothAvailability, Never> {
        combined(
            csc: publisher(source: csc),
            ftms: publisher(source: ftms)
        )
    }

    private static func restrictionRank(_ v: BluetoothAvailability) -> Int {
        switch v {
        case .denied: return 0
        case .notDetermined: return 1
        case .unsupported: return 2
        case .restricted: return 3
        case .resetting: return 4
        case .poweredOff: return 5
        case .poweredOn: return 6
        }
    }
}
