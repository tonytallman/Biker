//
//  AppStorageWithNamespacedKeysTests.swift
//  DependencyContainerTests
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation
import Testing

import DependencyContainer

@Suite("AppStorageWithNamespacedKeys Tests")
struct AppStorageWithNamespacedKeysTests {
    @Test("get prepends prefix when reading from backing storage")
    func getPrependsPrefix() {
        let mock = MockAppStorage()
        mock.set(value: "stored", forKey: "Settings.key")
        let namespaced = AppStorageWithNamespacedKeys(storage: mock, keyPrefix: "Settings")
        #expect(namespaced.get(forKey: "key") as? String == "stored")
    }

    @Test("set prepends prefix when writing to backing storage")
    func setPrependsPrefix() {
        let mock = MockAppStorage()
        let namespaced = AppStorageWithNamespacedKeys(storage: mock, keyPrefix: "Settings")
        namespaced.set(value: "value", forKey: "key")
        #expect(mock.setKeys == ["Settings.key"])
        #expect(mock.get(forKey: "Settings.key") as? String == "value")
    }

    @Test("withNamespacedKeys returns AppStorageWithNamespacedKeys that delegates with prefix")
    func withNamespacedKeysConvenience() {
        let mock = MockAppStorage()
        let namespaced = mock.withNamespacedKeys("MyPrefix")
        namespaced.set(value: 42, forKey: "k")
        #expect(mock.get(forKey: "MyPrefix.k") as? Int == 42)
        #expect(namespaced.get(forKey: "k") as? Int == 42)
    }
}
