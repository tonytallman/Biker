//
//  DefaultCSCKnownSensorPersistenceTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

private final class MockStorage: Storage {
    private var storage: [String: Any] = [:]

    func get(forKey key: String) -> Any? {
        storage[key]
    }

    func set(value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}

@MainActor
struct DefaultCSCKnownSensorPersistenceTests {
    @Test func roundTrip_encodesDataUnderKey() {
        let storage = MockStorage()
        let persistence = DefaultCSCKnownSensorPersistence(storage: storage)
        let id = UUID()
        let row = [
            CSCKnownSensorRecord(
                id: id,
                name: "K",
                isEnabled: true,
                wheelDiameterMeters: 0.6
            ),
        ]
        persistence.saveRecords(row)
        let reloaded = persistence.loadRecords()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].id == id)
        #expect(reloaded[0].name == "K")
        #expect(reloaded[0].isEnabled == true)
        #expect((reloaded[0].wheelDiameterMeters - 0.6) < 0.000_001)
        #expect(storage.get(forKey: "CSC.knownSensors.v1") is Data)
    }

    @Test func corruptedPayload_returnsEmpty() {
        let storage = MockStorage()
        storage.set(value: "not-json-data", forKey: "CSC.knownSensors.v1")
        let persistence = DefaultCSCKnownSensorPersistence(storage: storage)
        #expect(persistence.loadRecords().isEmpty)
    }

    @Test func legacyKnownSensors_migratesToV1AndRemovesLegacyKey() {
        let id = UUID()
        let storage = MockStorage()
        let legacy: [[String: String]] = [
            ["id": id.uuidString, "name": "Old Wheel"],
        ]
        let legacyData = try! JSONSerialization.data(withJSONObject: legacy, options: [])
        storage.set(value: legacyData, forKey: "knownSensors")

        let persistence = DefaultCSCKnownSensorPersistence(storage: storage)
        let reloaded = persistence.loadRecords()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].id == id)
        #expect(reloaded[0].name == "Old Wheel")
        #expect(reloaded[0].isEnabled == true)
        #expect((reloaded[0].wheelDiameterMeters - CSCKnownSensorDefaults.defaultWheelDiameterMeters) < 0.000_001)
        #expect(storage.get(forKey: "knownSensors") == nil)
        #expect(storage.get(forKey: "CSC.knownSensors.v1") is Data)
    }
}
