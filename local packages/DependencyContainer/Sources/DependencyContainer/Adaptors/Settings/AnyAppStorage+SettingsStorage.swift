//
//  File.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 4/25/26.
//

import SettingsVM

extension AnyAppStorage: SettingsStorage { }

package extension AppStorage {
    func asSettingsStorage() -> AnyAppStorage {
        .init(self)
    }
}
