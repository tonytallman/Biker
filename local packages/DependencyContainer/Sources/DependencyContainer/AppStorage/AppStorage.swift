//
//  AppStorage.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation
import SettingsModel

package protocol AppStorage {
    func get(forKey key: String) -> Any?
    func set(value: Any?, forKey key: String)
}
