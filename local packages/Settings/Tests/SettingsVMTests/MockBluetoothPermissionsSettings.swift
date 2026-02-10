//
//  MockBluetoothPermissionsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import SettingsModel

@MainActor
final class MockBluetoothPermissionsSettings: BluetoothPermissionsSettings {
    var bluetoothBackgroundStatus: String = "Not Determined"
    var openPermissionsCallCount = 0
    
    func openPermissions() {
        openPermissionsCallCount += 1
    }
    
    func reset() {
        openPermissionsCallCount = 0
    }
}
