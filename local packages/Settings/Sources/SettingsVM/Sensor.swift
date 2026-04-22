//
//  Sensor.swift
//  SettingsVM
//

import Combine
import Foundation
import SettingsStrings

// MARK: - Connection state

public enum SensorConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected

    /// Localized label for the sensors list (Settings).
    public var localizedStatusText: String {
        switch self {
        case .connected:
            String(localized: "Connected", bundle: .settingsStrings, comment: "BLE sensor is connected")
        case .connecting:
            String(localized: "Connecting…", bundle: .settingsStrings, comment: "BLE sensor connection in progress")
        case .disconnected:
            String(localized: "Disconnected", bundle: .settingsStrings, comment: "BLE sensor is not connected")
        }
    }
}

// MARK: - Base sensor

/// Per-sensor contract for list and scan rows. All conformers are main-actor bound.
/// `Identifiable` is not inherited: Swift 6 requires a `nonisolated` `id` for `Identifiable`, which
/// conflicts with main-actor–isolated state on conformers. Use `\.id` where an identity key path is needed.
@MainActor
public protocol Sensor: AnyObject {
    var id: UUID { get }
    var name: String { get }
    var type: SensorType { get }
    var connectionState: AnyPublisher<SensorConnectionState, Never> { get }
    var isEnabled: AnyPublisher<Bool, Never> { get }
    func connect()
    func disconnect()
    func forget()
    func setEnabled(_ enabled: Bool)
}
