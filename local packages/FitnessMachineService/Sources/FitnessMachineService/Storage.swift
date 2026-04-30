//
//  Storage.swift
//  FitnessMachineService
//

import Foundation

public enum FTMSKnownSensorType: String, Sendable, Codable {
    case fitnessMachine = "fitnessMachine"
}

/// One persisted known FTMS sensor row (schema version implied by the storage key, e.g. `…v1`).
public struct FTMSKnownSensorRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var sensorType: String
    public var isEnabled: Bool

    public init(
        id: UUID,
        name: String,
        sensorType: String = FTMSKnownSensorType.fitnessMachine.rawValue,
        isEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.sensorType = sensorType
        self.isEnabled = isEnabled
    }
}

public protocol Storage {
    func get(forKey key: String) -> Any?
    func set(value: Any?, forKey key: String)
}
