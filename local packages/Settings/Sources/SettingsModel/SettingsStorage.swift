//
//  SettingsStorage.swift
//  Settings
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation

public protocol SettingsStorage {
    func get(forKey key: String) -> Any?
    func set(value: Any?, forKey key: String)
}

public protocol AppStorage {
    func get(forKey key: String) -> Any?
    func set(value: Any?, forKey key: String)
}
