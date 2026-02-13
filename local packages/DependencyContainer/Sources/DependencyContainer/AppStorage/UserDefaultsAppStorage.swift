//
//  UserDefaultsAppStorage.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation

final package class UserDefaultsAppStorage: AppStorage {
    private let defaults: UserDefaults

    package init(_ defaults: UserDefaults) {
        self.defaults = defaults
    }

    package func get(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    package func set(value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

package extension UserDefaults {
    func asAppStorage() -> UserDefaultsAppStorage {
        .init(self)
    }
}
