//
//  BluetoothPermissionsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import CoreBluetooth
import SettingsStrings
import UIKit

@MainActor package protocol BluetoothPermissionsSettings {
    var bluetoothBackgroundStatus: String { get }
    func openPermissions()
}

package struct DefaultBluetoothPermissionsSettings: BluetoothPermissionsSettings {
    package init() {}
    
    package var bluetoothBackgroundStatus: String {
        let status = CBManager.authorization
        switch status {
        case .allowedAlways:
            return String(localized: "Allowed", bundle: .settingsStrings, comment: "Bluetooth permission status: user allowed background use")
        case .denied:
            return String(localized: "Denied", bundle: .settingsStrings, comment: "Bluetooth permission status: user denied")
        case .restricted:
            return String(localized: "Restricted", bundle: .settingsStrings, comment: "Bluetooth permission status: restricted by parental controls or device policy")
        case .notDetermined:
            return String(localized: "Not Determined", bundle: .settingsStrings, comment: "Bluetooth permission status: user has not been asked yet")
        @unknown default:
            return String(localized: "Unknown", bundle: .settingsStrings, comment: "Bluetooth permission status: unknown or future case")
        }
    }

    package func openPermissions() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
