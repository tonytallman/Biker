//
//  FTMSKnownSensorStoreTests.swift
//  FitnessMachineServiceTests
//

import Foundation
import Testing

@testable import FitnessMachineService

private let ftmsKnownSensorsStorageKey = "FTMS.knownSensors.v1"

private final class InMemoryFTMSPersistence: Storage {
    private var storage: [String: Any] = [:]
    private(set) var setCount = 0

    init(encodedRecordsData: Data? = nil) {
        if let encodedRecordsData {
            storage[ftmsKnownSensorsStorageKey] = encodedRecordsData
        }
    }

    init(records: [FTMSKnownSensorRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            storage[ftmsKnownSensorsStorageKey] = data
        }
    }

    func get(forKey key: String) -> Any? { storage[key] }

    func set(value: Any?, forKey key: String) {
        setCount += 1
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    var recordsOnDisk: [FTMSKnownSensorRecord] {
        guard let data = storage[ftmsKnownSensorsStorageKey] as? Data,
              let r = try? JSONDecoder().decode([FTMSKnownSensorRecord].self, from: data)
        else { return [] }
        return r
    }
}

@MainActor
struct FTMSKnownSensorStoreTests {
    @Test func loadAll_dropsNonFTMS() {
        let records = [
            FTMSKnownSensorRecord(
                id: UUID(),
                name: "X",
                sensorType: "cyclingSpeedAndCadence",
                isEnabled: true
            ),
        ]
        let p = InMemoryFTMSPersistence(records: records)
        let s = FTMSKnownSensorStore(persistence: p)
        let v = s.loadAll()
        #expect(v.isEmpty)
        #expect(p.recordsOnDisk.isEmpty)
    }

    @Test func upsert_coalescesUnchanged() {
        let p = InMemoryFTMSPersistence()
        let s = FTMSKnownSensorStore(persistence: p)
        _ = s.loadAll()
        let r = FTMSKnownSensorRecord(
            id: UUID(),
            name: "A",
            isEnabled: true
        )
        s.upsert(r)
        #expect(p.setCount == 1)
        s.upsert(r)
        #expect(p.setCount == 1)
    }

    @Test func remove_persists() {
        let id = UUID()
        let p = InMemoryFTMSPersistence()
        let s = FTMSKnownSensorStore(persistence: p)
        _ = s.loadAll()
        s.upsert(FTMSKnownSensorRecord(id: id, name: "X", isEnabled: true))
        #expect(p.recordsOnDisk.map(\.id).contains(id))
        s.remove(id: id)
        #expect(!p.recordsOnDisk.map(\.id).contains(id))
    }

    @Test func load_returnsEmpty_forCorruptData() {
        let p = InMemoryFTMSPersistence(encodedRecordsData: Data("not-json".utf8))
        let s = FTMSKnownSensorStore(persistence: p)
        let v = s.loadAll()
        #expect(v.isEmpty)
    }
}
