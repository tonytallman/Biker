//
//  HRKnownSensorStore.swift
//  HeartRateService
//

import Foundation

/// In-memory view of known HR records with coalesced `save` calls.
@MainActor
final class HRKnownSensorStore {
    private static let storageKey = "HR.knownSensors.v1"

    private let persistence: any HRPersistence
    private var recordsByID: [UUID: HRKnownSensorRecord] = [:]
    private var lastSavedRecords: [HRKnownSensorRecord] = []

    init(persistence: any HRPersistence) {
        self.persistence = persistence
    }

    func loadAll() -> [HRKnownSensorRecord] {
        let raw = loadRawRecordsFromDisk()
        var next: [UUID: HRKnownSensorRecord] = [:]
        var diskDiffers = false
        for r in raw {
            if r.sensorType != HRKnownSensorType.heartRate.rawValue {
                diskDiffers = true
                continue
            }
            if next[r.id] != nil {
                diskDiffers = true
                continue
            }
            next[r.id] = r
        }
        recordsByID = next
        let sorted = next.values.sorted { $0.id.uuidString < $1.id.uuidString }
        if diskDiffers {
            writeRecordsToDisk(sorted)
        }
        lastSavedRecords = sorted
        return sorted
    }

    func upsert(_ record: HRKnownSensorRecord) {
        var r = record
        if r.sensorType != HRKnownSensorType.heartRate.rawValue {
            r.sensorType = HRKnownSensorType.heartRate.rawValue
        }
        if recordsByID[r.id] == r { return }
        recordsByID[r.id] = r
        persistIfChanged()
    }

    func remove(id: UUID) {
        guard recordsByID.removeValue(forKey: id) != nil else { return }
        persistIfChanged()
    }

    private func loadRawRecordsFromDisk() -> [HRKnownSensorRecord] {
        guard let data = persistence.get(forKey: Self.storageKey) as? Data,
              !data.isEmpty,
              let records = try? JSONDecoder().decode([HRKnownSensorRecord].self, from: data)
        else { return [] }
        return records
    }

    private func writeRecordsToDisk(_ records: [HRKnownSensorRecord]) {
        if records.isEmpty {
            persistence.set(value: nil, forKey: Self.storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(records) {
            persistence.set(value: data, forKey: Self.storageKey)
        }
    }

    private func persistIfChanged() {
        let next = recordsByID.values.sorted { $0.id.uuidString < $1.id.uuidString }
        guard next != lastSavedRecords else { return }
        lastSavedRecords = next
        writeRecordsToDisk(next)
    }
}
