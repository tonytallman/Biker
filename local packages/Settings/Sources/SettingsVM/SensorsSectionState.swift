//
//  SensorsSectionState.swift
//  SettingsVM
//

import Foundation

/// Drives the Sensors section layout (SEN-PERM-1, SEN-PERM-3, SEN-PERM-4).
public enum SensorsSectionState: Sendable, Equatable {
    /// Bluetooth permission not granted; no list, no scan affordance (SEN-PERM-1, SEN-PERM-2).
    case permissionBlocked
    /// Permission OK but radio off, unsupported, or resetting; list + BT-off copy; no scan (SEN-PERM-3; SEN-PERM-4: never shown when `permissionBlocked`).
    case bluetoothUnavailable
    /// Normal list, scan + when `.poweredOn` (SEN-PERM-5 when permission granted and radio on).
    case normal
}
