//
//  SensorModels.swift
//  CyclingSpeedAndCadenceService
//

import Foundation

/// A BLE peripheral advertising the Cycling Speed and Cadence service, seen during scanning.
public struct DiscoveredSensor: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let rssi: Int

    public init(id: UUID, name: String, rssi: Int) {
        self.id = id
        self.name = name
        self.rssi = rssi
    }
}

/// Connection state for a known CSC sensor.
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
}

/// A peripheral that may be connected for CSC notifications.
public struct ConnectedSensor: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let connectionState: ConnectionState

    public init(id: UUID, name: String, connectionState: ConnectionState) {
        self.id = id
        self.name = name
        self.connectionState = connectionState
    }
}
