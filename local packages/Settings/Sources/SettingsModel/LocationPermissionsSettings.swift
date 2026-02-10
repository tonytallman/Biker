//
//  LocationPermissionsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import CoreLocation
import SettingsStrings
import UIKit

@MainActor package protocol LocationPermissionsSettings {
    var locationBackgroundStatus: String { get }
    func openPermissions()
}

package struct DefaultLocationPermissionsSettings: LocationPermissionsSettings {
    package init() {}
    
    package var locationBackgroundStatus: String {
        let status = CLLocationManager().authorizationStatus
        switch status {
        case .authorizedAlways:
            return String(localized: "Always", bundle: .settingsStrings, comment: "Location permission status: always allow (including background)")
        case .authorizedWhenInUse:
            return String(localized: "While Using", bundle: .settingsStrings, comment: "Location permission status: allow only when app is in use")
        case .denied:
            return String(localized: "Denied", bundle: .settingsStrings, comment: "Location permission status: user denied")
        case .restricted:
            return String(localized: "Restricted", bundle: .settingsStrings, comment: "Location permission status: restricted by parental controls or device policy")
        case .notDetermined:
            return String(localized: "Not Determined", bundle: .settingsStrings, comment: "Location permission status: user has not been asked yet")
        @unknown default:
            return String(localized: "Unknown", bundle: .settingsStrings, comment: "Location permission status: unknown or future case")
        }
    }

    package func openPermissions() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
