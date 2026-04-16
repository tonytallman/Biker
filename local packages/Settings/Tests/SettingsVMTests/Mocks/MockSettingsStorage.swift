//
//  MockSettingsStorage.swift
//  SettingsVMTests
//

import Foundation
import SettingsVM

final class MockSettingsStorage: SettingsStorage {
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
