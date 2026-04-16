//
//  ConnectedSensorInfo.swift
//  SettingsVM
//

import Foundation
import SettingsStrings

/// A sensor the user has paired with (known) and its live connection state.
public struct ConnectedSensorInfo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let connectionState: SensorConnectionState

    public init(id: UUID, name: String, connectionState: SensorConnectionState) {
        self.id = id
        self.name = name
        self.connectionState = connectionState
    }
}

public enum SensorConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected

    /// Localized label for the sensors list (Settings).
    public var localizedStatusText: String {
        switch self {
        case .connected:
            return String(localized: "Connected", bundle: .settingsStrings, comment: "BLE sensor is connected")
        case .connecting:
            return String(localized: "Connecting…", bundle: .settingsStrings, comment: "BLE sensor connection in progress")
        case .disconnected:
            return String(localized: "Disconnected", bundle: .settingsStrings, comment: "BLE sensor is not connected")
        }
    }
}
