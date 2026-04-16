//
//  DiscoveredSensorInfo.swift
//  SettingsVM
//

import Foundation

/// A BLE peripheral discovered during a sensor scan (Settings layer; no CoreBluetooth dependency).
public struct DiscoveredSensorInfo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int

    public init(id: UUID, name: String, rssi: Int) {
        self.id = id
        self.name = name
        self.rssi = rssi
    }
}
