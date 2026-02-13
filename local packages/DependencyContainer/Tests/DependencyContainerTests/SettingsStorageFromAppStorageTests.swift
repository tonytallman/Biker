//
//  SettingsStorageFromAppStorageTests.swift
//  DependencyContainerTests
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation
import Testing

import DependencyContainer

@Suite("SettingsStorageFromAppStorage Tests")
struct SettingsStorageFromAppStorageTests {
    @Test("get delegates to underlying AppStorage")
    func getDelegatesToAppStorage() {
        let mock = MockAppStorage()
        mock.set(value: "delegated", forKey: "key")
        let adaptor = SettingsStorageFromAppStorage(mock)
        #expect(adaptor.get(forKey: "key") as? String == "delegated")
    }

    @Test("set delegates to underlying AppStorage")
    func setDelegatesToAppStorage() {
        let mock = MockAppStorage()
        let adaptor = SettingsStorageFromAppStorage(mock)
        adaptor.set(value: "value", forKey: "key")
        #expect(mock.get(forKey: "key") as? String == "value")
    }

    @Test("set nil removes value from underlying AppStorage")
    func setNilRemovesValue() {
        let mock = MockAppStorage()
        mock.set(value: "initial", forKey: "key")
        let adaptor = SettingsStorageFromAppStorage(mock)
        adaptor.set(value: nil, forKey: "key")
        #expect(adaptor.get(forKey: "key") == nil)
        #expect(mock.get(forKey: "key") == nil)
    }

    @Test("asSettingsStorage() returns adaptor that delegates to receiver")
    func asSettingsStorageConvenience() {
        let mock = MockAppStorage()
        let storage = mock.asSettingsStorage()
        storage.set(value: "viaExtension", forKey: "k")
        #expect(storage.get(forKey: "k") as? String == "viaExtension")
        #expect(mock.get(forKey: "k") as? String == "viaExtension")
    }
}
