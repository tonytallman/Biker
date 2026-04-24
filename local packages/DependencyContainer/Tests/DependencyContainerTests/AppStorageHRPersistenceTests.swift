//
//  AppStorageHRPersistenceTests.swift
//  DependencyContainerTests
//

import Foundation
import Testing

@testable import DependencyContainer
@testable import HeartRateService

@MainActor
struct AppStorageHRPersistenceTests {
    @Test func appStorage_roundTripsKnownSensorsThroughStore() {
        let storage = MockAppStorage()
        let store = HRKnownSensorStore(persistence: storage)
        _ = store.loadAll()

        let id = UUID()
        store.upsert(
            HRKnownSensorRecord(
                id: id,
                name: "H",
                isEnabled: true
            )
        )

        let reloaded = HRKnownSensorStore(persistence: storage).loadAll()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].id == id)
        #expect(reloaded[0].name == "H")
        #expect(reloaded[0].isEnabled == true)
        #expect(storage.get(forKey: "HR.knownSensors.v1") is Data)
    }

    @Test func corruptPayload_loadsEmptyFromStore() {
        let storage = MockAppStorage()
        storage.set(value: "not-json-data", forKey: "HR.knownSensors.v1")
        let store = HRKnownSensorStore(persistence: storage)
        #expect(store.loadAll().isEmpty)
    }
}
