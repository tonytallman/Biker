//
//  BluetoothAvailability.swift
//  SettingsVM
//

import Foundation

/// High-level Bluetooth stack / power / permission state for Settings and scan UX.
public enum BluetoothAvailability: Sendable, Hashable, CaseIterable {
    case notDetermined
    case denied
    case restricted
    case unsupported
    case resetting
    case poweredOff
    case poweredOn
}
