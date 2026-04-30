//
//  MockAppStorage.swift
//  DependencyContainerTests
//
//  Created by Tony Tallman on 2/12/26.
//

import CyclingSpeedAndCadenceService
import DependencyContainer
import FitnessMachineService
import Foundation
import HeartRateService

final class MockAppStorage: AppStorage {
    private var storage: [String: Any] = [:]
    private(set) var setKeys: [String] = []

    func get(forKey key: String) -> Any? {
        storage[key]
    }

    func set(value: Any?, forKey key: String) {
        setKeys.append(key)
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }

    func resetSetKeys() {
        setKeys.removeAll()
    }
}

extension MockAppStorage: CyclingSpeedAndCadenceService.Storage {}
extension MockAppStorage: FitnessMachineService.Storage {}
extension MockAppStorage: HeartRateService.Storage {}
