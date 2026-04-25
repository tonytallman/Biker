//
//  AppStorage+Storage.swift
//  DependencyContainer
//

import HeartRateService

extension AnyAppStorage: HeartRateService.Storage { }

package extension AppStorage {
    func asHeartRateServiceStorage() -> HeartRateService.Storage {
        AnyAppStorage(self)
    }
}
