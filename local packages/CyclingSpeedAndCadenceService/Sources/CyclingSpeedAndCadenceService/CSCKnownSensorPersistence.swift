//
//  CSCKnownSensorPersistence.swift
//  CyclingSpeedAndCadenceService
//
//  Typed DTOs and a persistence port for per-manager known CSC sensors.
//  `DefaultCSCKnownSensorPersistence` is the runtime default over `Storage`; tests inject
//  `CSCKnownSensorPersistence` via the sensor manager's internal initializer.

import Foundation

/// String sentinel for the CSC service family. Other sensor families can use
/// their own `sensorType` values in future combined-key scenarios.
public enum CSCKnownSensorType: String, Sendable, Codable {
    case cyclingSpeedAndCadence = "cyclingSpeedAndCadence"
}

/// Default wheel **diameter** in meters, derived from `CSCDefaults.defaultWheelCircumferenceMeters`.
public enum CSCKnownSensorDefaults {
    public static var defaultWheelDiameterMeters: Double {
        CSCDefaults.defaultWheelCircumferenceMeters / Double.pi
    }
}

/// One persisted known CSC sensor row (schema version implied by the storage key, e.g. `…v1`).
public struct CSCKnownSensorRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var sensorType: String
    public var isEnabled: Bool
    public var wheelDiameterMeters: Double

    public init(
        id: UUID,
        name: String,
        sensorType: String = CSCKnownSensorType.cyclingSpeedAndCadence.rawValue,
        isEnabled: Bool,
        wheelDiameterMeters: Double
    ) {
        self.id = id
        self.name = name
        self.sensorType = sensorType
        self.isEnabled = isEnabled
        self.wheelDiameterMeters = wheelDiameterMeters
    }
}

@MainActor
public protocol CSCKnownSensorPersistence: AnyObject {
    func loadRecords() -> [CSCKnownSensorRecord]
    func saveRecords(_ records: [CSCKnownSensorRecord])
}
