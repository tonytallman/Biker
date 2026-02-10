//
//  MockLocationPermissionsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import SettingsModel

@MainActor
final class MockLocationPermissionsSettings: LocationPermissionsSettings {
    var locationBackgroundStatus: String = "Not Determined"
    var openPermissionsCallCount = 0
    
    func openPermissions() {
        openPermissionsCallCount += 1
    }
    
    func reset() {
        openPermissionsCallCount = 0
    }
}
