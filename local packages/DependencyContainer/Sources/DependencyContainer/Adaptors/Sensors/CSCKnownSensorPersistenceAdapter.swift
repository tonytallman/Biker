//
//  CSCKnownSensorPersistenceAdapter.swift
//  DependencyContainer
//
//  `AppStorage` / `UserDefaults` backing for CSC known-sensor JSON under a versioned key.
//

import CyclingSpeedAndCadenceService
import Foundation

@MainActor
final class CSCKnownSensorPersistenceAdapter: CSCKnownSensorPersistence {
    private let appStorage: AppStorage
    private static let key = "CSC.knownSensors.v1"

    init(appStorage: AppStorage) {
        self.appStorage = appStorage
    }

    func loadRecords() -> [CSCKnownSensorRecord] {
        guard let data = appStorage.get(forKey: Self.key) as? Data,
              !data.isEmpty,
              let records = try? JSONDecoder().decode([CSCKnownSensorRecord].self, from: data)
        else { return [] }
        return records
    }

    func saveRecords(_ records: [CSCKnownSensorRecord]) {
        if records.isEmpty {
            appStorage.set(value: nil, forKey: Self.key)
            return
        }
        if let data = try? JSONEncoder().encode(records) {
            appStorage.set(value: data, forKey: Self.key)
        }
    }
}
