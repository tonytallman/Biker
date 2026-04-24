//
//  FTMSKnownSensorStore.swift
//  FitnessMachineService
//

import Foundation

/// In-memory view of known FTMS records with coalesced `save` calls.
@MainActor
final class FTMSKnownSensorStore {
    private static let storageKey = "FTMS.knownSensors.v1"

    private let persistence: any FTMSPersistence
    private var recordsByID: [UUID: FTMSKnownSensorRecord] = [:]
    private var lastSavedRecords: [FTMSKnownSensorRecord] = []

    init(persistence: any FTMSPersistence) {
        self.persistence = persistence
    }

    func loadAll() -> [FTMSKnownSensorRecord] {
        let raw = loadRawRecordsFromDisk()
        var next: [UUID: FTMSKnownSensorRecord] = [:]
        var diskDiffers = false
        for r in raw {
            if r.sensorType != FTMSKnownSensorType.fitnessMachine.rawValue {
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

    func upsert(_ record: FTMSKnownSensorRecord) {
        var r = record
        if r.sensorType != FTMSKnownSensorType.fitnessMachine.rawValue {
            r.sensorType = FTMSKnownSensorType.fitnessMachine.rawValue
        }
        if recordsByID[r.id] == r { return }
        recordsByID[r.id] = r
        persistIfChanged()
    }

    func remove(id: UUID) {
        guard recordsByID.removeValue(forKey: id) != nil else { return }
        persistIfChanged()
    }

    private func loadRawRecordsFromDisk() -> [FTMSKnownSensorRecord] {
        guard let data = persistence.get(forKey: Self.storageKey) as? Data,
              !data.isEmpty,
              let records = try? JSONDecoder().decode([FTMSKnownSensorRecord].self, from: data)
        else { return [] }
        return records
    }

    private func writeRecordsToDisk(_ records: [FTMSKnownSensorRecord]) {
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
