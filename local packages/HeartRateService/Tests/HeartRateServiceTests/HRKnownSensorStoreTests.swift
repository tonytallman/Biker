//
//  HRKnownSensorStoreTests.swift
//  HeartRateServiceTests
//

import Foundation
import Testing

@testable import HeartRateService

private let hrKnownSensorsStorageKey = "HR.knownSensors.v1"

private final class InMemoryHRPersistence: HRPersistence {
    private var storage: [String: Any] = [:]
    private(set) var setCount = 0

    init(encodedRecordsData: Data? = nil) {
        if let encodedRecordsData {
            storage[hrKnownSensorsStorageKey] = encodedRecordsData
        }
    }

    init(records: [HRKnownSensorRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            storage[hrKnownSensorsStorageKey] = data
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

    var recordsOnDisk: [HRKnownSensorRecord] {
        guard let data = storage[hrKnownSensorsStorageKey] as? Data,
              let r = try? JSONDecoder().decode([HRKnownSensorRecord].self, from: data)
        else { return [] }
        return r
    }
}

@MainActor
struct HRKnownSensorStoreTests {
    @Test func loadAll_dropsNonHR() {
        let records = [
            HRKnownSensorRecord(
                id: UUID(),
                name: "X",
                sensorType: "fitnessMachine",
                isEnabled: true
            ),
        ]
        let p = InMemoryHRPersistence(records: records)
        let s = HRKnownSensorStore(persistence: p)
        let v = s.loadAll()
        #expect(v.isEmpty)
        #expect(p.recordsOnDisk.isEmpty)
    }

    @Test func upsert_coalescesUnchanged() {
        let p = InMemoryHRPersistence()
        let s = HRKnownSensorStore(persistence: p)
        _ = s.loadAll()
        let r = HRKnownSensorRecord(
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
        let p = InMemoryHRPersistence()
        let s = HRKnownSensorStore(persistence: p)
        _ = s.loadAll()
        s.upsert(HRKnownSensorRecord(id: id, name: "X", isEnabled: true))
        #expect(p.recordsOnDisk.map(\.id).contains(id))
        s.remove(id: id)
        #expect(!p.recordsOnDisk.map(\.id).contains(id))
    }

    @Test func load_returnsEmpty_forCorruptData() {
        let p = InMemoryHRPersistence(encodedRecordsData: Data("not-json".utf8))
        let s = HRKnownSensorStore(persistence: p)
        let v = s.loadAll()
        #expect(v.isEmpty)
    }
}
