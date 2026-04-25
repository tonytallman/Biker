//
//  Storage.swift
//  HeartRateService
//

import Foundation

public enum HRKnownSensorType: String, Sendable, Codable {
    case heartRate = "heartRate"
}

/// One persisted known heart rate sensor row (schema version implied by the storage key, e.g. `…v1`).
public struct HRKnownSensorRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var sensorType: String
    public var isEnabled: Bool

    public init(
        id: UUID,
        name: String,
        sensorType: String = HRKnownSensorType.heartRate.rawValue,
        isEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.sensorType = sensorType
        self.isEnabled = isEnabled
    }
}

/// Key-value persistence port with the same method shape as the app’s `AppStorage` protocol; concrete storage types in `DependencyContainer` conform to this protocol.
public protocol Storage {
    func get(forKey key: String) -> Any?
    func set(value: Any?, forKey key: String)
}
