//
//  AppStorage+HRPersistence.swift
//  DependencyContainer
//

import HeartRateService

extension AnyAppStorage: HRPersistence { }

package extension AppStorage {
    func asHRPersistence() -> HRPersistence {
        AnyAppStorage(self)
    }
}
