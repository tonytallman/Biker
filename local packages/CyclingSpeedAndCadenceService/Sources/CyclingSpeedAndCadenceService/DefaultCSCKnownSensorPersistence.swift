//
//  DefaultCSCKnownSensorPersistence.swift
//  CyclingSpeedAndCadenceService
//
//  Runtime default: JSON rows in keyed `Storage` (`CSC.knownSensors.v1`),
//  with one-shot migration from legacy `knownSensors`.
//

import Foundation

@MainActor
final class DefaultCSCKnownSensorPersistence: CSCKnownSensorPersistence {
    private let storage: Storage
    private static let key = "CSC.knownSensors.v1"
    /// Pre–per-store-schema blob: `[{ "id", "name" }]` under the same namespaced `Storage` as v1
    /// (full key e.g. `Settings.knownSensors` when using `withNamespacedKeys("Settings")`).
    private static let legacyKey = "knownSensors"

    private struct LegacyKnownSensorEntry: Decodable, Equatable {
        let id: UUID
        let name: String
    }

    init(storage: Storage) {
        self.storage = storage
    }

    func loadRecords() -> [CSCKnownSensorRecord] {
        if let data = storage.get(forKey: Self.key) as? Data,
           !data.isEmpty,
           let records = try? JSONDecoder().decode([CSCKnownSensorRecord].self, from: data),
           !records.isEmpty
        {
            return records
        }

        if let migrated = migrateFromLegacyIfNeeded() {
            return migrated
        }

        if let data = storage.get(forKey: Self.key) as? Data,
           !data.isEmpty,
           let records = try? JSONDecoder().decode([CSCKnownSensorRecord].self, from: data)
        {
            return records
        }
        return []
    }

    func saveRecords(_ records: [CSCKnownSensorRecord]) {
        if records.isEmpty {
            storage.set(value: nil, forKey: Self.key)
            return
        }
        if let data = try? JSONEncoder().encode(records) {
            storage.set(value: data, forKey: Self.key)
        }
    }

    /// One-shot migration: legacy `knownSensors` id+name list → `CSC.knownSensors.v1` rows; then remove legacy.
    private func migrateFromLegacyIfNeeded() -> [CSCKnownSensorRecord]? {
        guard let data = storage.get(forKey: Self.legacyKey) as? Data, !data.isEmpty else { return nil }
        guard let legacy = try? JSONDecoder().decode([LegacyKnownSensorEntry].self, from: data) else { return nil }
        if legacy.isEmpty {
            storage.set(value: nil, forKey: Self.legacyKey)
            return nil
        }
        let def = CSCKnownSensorDefaults.defaultWheelDiameterMeters
        let migrated: [CSCKnownSensorRecord] = legacy.map { row in
            CSCKnownSensorRecord(
                id: row.id,
                name: row.name,
                isEnabled: true,
                wheelDiameterMeters: def
            )
        }
        saveRecords(migrated)
        storage.set(value: nil, forKey: Self.legacyKey)
        return migrated
    }
}
