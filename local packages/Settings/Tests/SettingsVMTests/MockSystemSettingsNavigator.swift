//
//  MockSystemSettingsNavigator.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import SettingsModel

final class MockSystemSettingsNavigator: SystemSettingsNavigator {
    var openPermissionsCallCount = 0
    
    func openAppPermissions() {
        openPermissionsCallCount += 1
    }
    
    func reset() {
        openPermissionsCallCount = 0
    }
}
