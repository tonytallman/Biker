//
//  AppStorage+HRPersistence.swift
//  DependencyContainer
//

import Foundation
import HeartRateService

extension UserDefaultsAppStorage: HRPersistence {}
extension AppStorageWithNamespacedKeys: HRPersistence {}
