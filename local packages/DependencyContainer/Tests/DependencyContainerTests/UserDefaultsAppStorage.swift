//
//  UserDefaultsAppStorageTests.swift
//  DependencyContainerTests
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation
import Testing

import DependencyContainer

@Suite("UserDefaultsAppStorage Tests")
struct UserDefaultsAppStorageTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

    private func removeSuite(_ suiteName: String) {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    @Test("get returns nil for missing key")
    func getReturnsNilForMissingKey() {
        let (defaults, suiteName) = makeDefaults()
        defer { removeSuite(suiteName) }
        let storage = UserDefaultsAppStorage(defaults)
        #expect(storage.get(forKey: "missing") == nil)
    }

    @Test("set and get round-trip string")
    func setAndGetRoundTripString() {
        let (defaults, suiteName) = makeDefaults()
        defer { removeSuite(suiteName) }
        let storage = UserDefaultsAppStorage(defaults)
        storage.set(value: "value", forKey: "key")
        #expect(storage.get(forKey: "key") as? String == "value")
    }

    @Test("set and get round-trip bool")
    func setAndGetRoundTripBool() {
        let (defaults, suiteName) = makeDefaults()
        defer { removeSuite(suiteName) }
        let storage = UserDefaultsAppStorage(defaults)
        storage.set(value: true, forKey: "key")
        #expect(storage.get(forKey: "key") as? Bool == true)
    }

    @Test("set and get round-trip double")
    func setAndGetRoundTripDouble() {
        let (defaults, suiteName) = makeDefaults()
        defer { removeSuite(suiteName) }
        let storage = UserDefaultsAppStorage(defaults)
        storage.set(value: 1.34, forKey: "key")
        #expect(storage.get(forKey: "key") as? Double == 1.34)
    }

    @Test("set nil removes value")
    func setNilRemovesValue() {
        let (defaults, suiteName) = makeDefaults()
        defer { removeSuite(suiteName) }
        let storage = UserDefaultsAppStorage(defaults)
        storage.set(value: "value", forKey: "key")
        storage.set(value: nil, forKey: "key")
        #expect(storage.get(forKey: "key") == nil)
    }

    @Test("asAppStorage() returns UserDefaultsAppStorage backed by same defaults")
    func asAppStorageConvenience() {
        let (defaults, suiteName) = makeDefaults()
        defer { removeSuite(suiteName) }
        let storage = defaults.asAppStorage()
        storage.set(value: "viaExtension", forKey: "key")
        #expect(storage.get(forKey: "key") as? String == "viaExtension")
        #expect(defaults.string(forKey: "key") == "viaExtension")
    }
}
