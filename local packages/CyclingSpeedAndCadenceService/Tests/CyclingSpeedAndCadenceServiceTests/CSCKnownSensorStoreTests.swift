//
//  CSCKnownSensorStoreTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

@MainActor
private final class InMemoryCSCPersistence: CSCKnownSensorPersistence {
    var records: [CSCKnownSensorRecord] = []
    var saveCount = 0

    init(records: [CSCKnownSensorRecord] = []) {
        self.records = records
    }

    func loadRecords() -> [CSCKnownSensorRecord] { records }
    func saveRecords(_ records: [CSCKnownSensorRecord]) {
        saveCount += 1
        self.records = records
    }
}

@MainActor
struct CSCKnownSensorStoreTests {
    @Test func loadAll_dropsNonCSC() {
        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(
                id: UUID(),
                name: "X",
                sensorType: "fitnessMachine",
                isEnabled: true,
                wheelDiameterMeters: 0.5
            ),
        ])
        let s = CSCKnownSensorStore(persistence: p)
        let v = s.loadAll()
        #expect(v.isEmpty)
    }

    @Test func loadAll_repairsInvalidWheel() {
        let id = UUID()
        let p = InMemoryCSCPersistence(records: [
            CSCKnownSensorRecord(
                id: id,
                name: "A",
                sensorType: CSCKnownSensorType.cyclingSpeedAndCadence.rawValue,
                isEnabled: true,
                wheelDiameterMeters: -1
            ),
        ])
        let s = CSCKnownSensorStore(persistence: p)
        let v = s.loadAll()
        #expect(v.count == 1)
        #expect(v[0].wheelDiameterMeters == CSCKnownSensorDefaults.defaultWheelDiameterMeters)
    }

    @Test func upsert_coalescesUnchanged() {
        let p = InMemoryCSCPersistence()
        let s = CSCKnownSensorStore(persistence: p)
        _ = s.loadAll()
        let r = CSCKnownSensorRecord(
            id: UUID(),
            name: "A",
            isEnabled: true,
            wheelDiameterMeters: CSCKnownSensorDefaults.defaultWheelDiameterMeters
        )
        s.upsert(r)
        #expect(p.saveCount == 1)
        s.upsert(r)
        #expect(p.saveCount == 1)
    }

    @Test func remove_persists() {
        let id = UUID()
        let p = InMemoryCSCPersistence()
        let s = CSCKnownSensorStore(persistence: p)
        _ = s.loadAll()
        s.upsert(
            CSCKnownSensorRecord(
                id: id,
                name: "A",
                isEnabled: true,
                wheelDiameterMeters: 0.5
            )
        )
        s.remove(id: id)
        #expect(p.records.isEmpty)
    }
}
