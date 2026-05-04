//
//  AppStorageFTMSPersistenceTests.swift
//  DependencyContainerTests
//

import Foundation
import Testing

@testable import DependencyContainer
@testable import FitnessMachineService

@MainActor
struct AppStorageFTMSPersistenceTests {
    /// `AppStorage` conforms to `Storage`; `FTMSKnownSensorStore` round-trips JSON via `MockAppStorage`.
    @Test func appStorage_roundTripsKnownSensorsThroughStore() {
        let storage = MockAppStorage()
        let store = FTMSKnownSensorStore(storage: storage)
        _ = store.loadAll()

        let id = UUID()
        store.upsert(
            FTMSKnownSensorRecord(
                id: id,
                name: "K",
                isEnabled: true
            )
        )

        let reloaded = FTMSKnownSensorStore(storage: storage).loadAll()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].id == id)
        #expect(reloaded[0].name == "K")
        #expect(reloaded[0].isEnabled == true)
        #expect(storage.get(forKey: "FTMS.knownSensors.v1") is Data)
    }

    @Test func corruptPayload_loadsEmptyFromStore() {
        let storage = MockAppStorage()
        storage.set(value: "not-json-data", forKey: "FTMS.knownSensors.v1")
        let store = FTMSKnownSensorStore(storage: storage)
        #expect(store.loadAll().isEmpty)
    }
}
