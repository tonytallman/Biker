//
//  CSCKnownSensorStore.swift
//  CyclingSpeedAndCadenceService
//

import Foundation

/// In-memory view of known CSC records with coalesced `save` calls.
@MainActor
final class CSCKnownSensorStore {
    private let persistence: any CSCKnownSensorPersistence
    private var recordsByID: [UUID: CSCKnownSensorRecord] = [:]
    private var lastSavedRecords: [CSCKnownSensorRecord] = []

    init(persistence: any CSCKnownSensorPersistence) {
        self.persistence = persistence
    }

    /// Loads, filters, and normalizes persisted rows; refreshes the in-memory mirror.
    /// Writes back when anything was dropped (wrong `sensorType`) or a wheel value was repaired.
    func loadAll() -> [CSCKnownSensorRecord] {
        let raw = persistence.loadRecords()
        var next: [UUID: CSCKnownSensorRecord] = [:]
        var diskDiffers = false
        for r in raw {
            if r.sensorType != CSCKnownSensorType.cyclingSpeedAndCadence.rawValue {
                diskDiffers = true
                continue
            }
            var row = r
            if !row.wheelDiameterMeters.isFinite || row.wheelDiameterMeters <= 0 {
                row.wheelDiameterMeters = CSCKnownSensorDefaults.defaultWheelDiameterMeters
                diskDiffers = true
            }
            if next[row.id] != nil {
                diskDiffers = true
                continue
            }
            next[row.id] = row
        }
        recordsByID = next
        let sorted = next.values.sorted { $0.id.uuidString < $1.id.uuidString }
        if diskDiffers {
            persistence.saveRecords(sorted)
        }
        lastSavedRecords = sorted
        return sorted
    }

    /// Inserts or updates. Persists only when the serialized set changed.
    func upsert(_ record: CSCKnownSensorRecord) {
        var r = record
        if r.sensorType != CSCKnownSensorType.cyclingSpeedAndCadence.rawValue {
            r.sensorType = CSCKnownSensorType.cyclingSpeedAndCadence.rawValue
        }
        if !r.wheelDiameterMeters.isFinite || r.wheelDiameterMeters <= 0 {
            r.wheelDiameterMeters = CSCKnownSensorDefaults.defaultWheelDiameterMeters
        }
        if recordsByID[r.id] == r { return }
        recordsByID[r.id] = r
        persistIfChanged()
    }

    /// Removes a row. Persists when the set changed.
    func remove(id: UUID) {
        guard recordsByID.removeValue(forKey: id) != nil else { return }
        persistIfChanged()
    }

    // MARK: - Internals

    private func persistIfChanged() {
        let next = recordsByID.values.sorted { $0.id.uuidString < $1.id.uuidString }
        guard next != lastSavedRecords else { return }
        lastSavedRecords = next
        persistence.saveRecords(next)
    }
}
