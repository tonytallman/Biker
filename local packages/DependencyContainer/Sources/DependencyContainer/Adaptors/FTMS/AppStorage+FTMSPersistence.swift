//
//  AppStorage+FTMSPersistence.swift
//  DependencyContainer
//

import FitnessMachineService

extension AnyAppStorage: FTMSPersistence { }

package extension AppStorage {
    func asFTMSPersistence() -> FTMSPersistence {
        AnyAppStorage(self)
    }
}
