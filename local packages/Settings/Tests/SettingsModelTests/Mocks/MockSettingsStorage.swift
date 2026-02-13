//
//  MockSettingsStorage.swift
//  SettingsModelTests
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation
import SettingsModel

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
