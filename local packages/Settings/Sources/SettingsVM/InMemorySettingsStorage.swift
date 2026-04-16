//
//  InMemorySettingsStorage.swift
//  Settings
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation

/// In-memory settings storage for use in previews and tests.
public final class InMemorySettingsStorage: SettingsStorage {
    private var storage: [String: Any] = [:]

    public init() {}

    public func get(forKey key: String) -> Any? {
        storage[key]
    }

    public func set(value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}
