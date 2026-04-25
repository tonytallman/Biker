//
//  AppStorage+Storage.swift
//  DependencyContainer
//

import FitnessMachineService

extension AnyAppStorage: FitnessMachineService.Storage { }

package extension AppStorage {
    func asFitnessMachineServiceStorage() -> FitnessMachineService.Storage {
        AnyAppStorage(self)
    }
}
