//
//  CSCKnownSensorPersistenceAdapterTests.swift
//  DependencyContainerTests
//

import CyclingSpeedAndCadenceService
import Foundation
import Testing
@testable import DependencyContainer

@MainActor
struct CSCKnownSensorPersistenceAdapterTests {
    @Test func roundTrip_encodesDataUnderKey() {
        let storage = MockAppStorage()
        let adapter = CSCKnownSensorPersistenceAdapter(appStorage: storage)
        let id = UUID()
        let row = [
            CSCKnownSensorRecord(
                id: id,
                name: "K",
                isEnabled: true,
                wheelDiameterMeters: 0.6
            ),
        ]
        adapter.saveRecords(row)
        let reloaded = adapter.loadRecords()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].id == id)
        #expect(reloaded[0].name == "K")
        #expect(reloaded[0].isEnabled == true)
        #expect((reloaded[0].wheelDiameterMeters - 0.6) < 0.000_001)
        #expect(storage.get(forKey: "CSC.knownSensors.v1") is Data)
    }

    @Test func corruptedPayload_returnsEmpty() {
        let storage = MockAppStorage()
        storage.set(value: "not-json-data", forKey: "CSC.knownSensors.v1")
        let adapter = CSCKnownSensorPersistenceAdapter(appStorage: storage)
        #expect(adapter.loadRecords().isEmpty)
    }
}
