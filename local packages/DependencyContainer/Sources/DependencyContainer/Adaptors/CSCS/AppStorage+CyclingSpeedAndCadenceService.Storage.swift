//
//  AppStorage+CyclingSpeedAndCadenceService.Storage.swift
//  DependencyContainer
//
//  Created by Tony Tallman on 4/30/26.
//

import CyclingSpeedAndCadenceService

extension AnyAppStorage: CyclingSpeedAndCadenceService.Storage { }

package extension AppStorage {
    func asCyclingSpeedAndCadenceServiceStorage() -> CyclingSpeedAndCadenceService.Storage {
        AnyAppStorage(self)
    }
}
