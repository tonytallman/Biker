//
//  BluetoothPermissionsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import CoreBluetooth
import SettingsStrings
import UIKit

package protocol BluetoothPermissionsSettings {
    var bluetoothBackgroundStatus: String { get }
}

package struct DefaultBluetoothPermissionsSettings: BluetoothPermissionsSettings {
    package init() {}

    package var bluetoothBackgroundStatus: String {
        switch CBManager.authorization {
        case .allowedAlways:
            String(localized: "Allowed", bundle: .settingsStrings, comment: "Bluetooth permission status: user allowed background use")
        case .denied:
            String(localized: "Denied", bundle: .settingsStrings, comment: "Bluetooth permission status: user denied")
        case .restricted:
            String(localized: "Restricted", bundle: .settingsStrings, comment: "Bluetooth permission status: restricted by parental controls or device policy")
        case .notDetermined:
            String(localized: "Not Determined", bundle: .settingsStrings, comment: "Bluetooth permission status: user has not been asked yet")
        @unknown default:
            String(localized: "Unknown", bundle: .settingsStrings, comment: "Bluetooth permission status: unknown or future case")
        }
    }
}
