//
//  LocationPermissionsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import CoreLocation
import SettingsStrings
import UIKit

package protocol LocationPermissionsSettings {
    var locationBackgroundStatus: String { get }
}

package struct DefaultLocationPermissionsSettings: LocationPermissionsSettings {
    package init() {}

    package var locationBackgroundStatus: String {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways:
            String(localized: "Always", bundle: .settingsStrings, comment: "Location permission status: always allow (including background)")
        case .authorizedWhenInUse:
            String(localized: "While Using", bundle: .settingsStrings, comment: "Location permission status: allow only when app is in use")
        case .denied:
            String(localized: "Denied", bundle: .settingsStrings, comment: "Location permission status: user denied")
        case .restricted:
            String(localized: "Restricted", bundle: .settingsStrings, comment: "Location permission status: restricted by parental controls or device policy")
        case .notDetermined:
            String(localized: "Not Determined", bundle: .settingsStrings, comment: "Location permission status: user has not been asked yet")
        @unknown default:
            String(localized: "Unknown", bundle: .settingsStrings, comment: "Location permission status: unknown or future case")
        }
    }
}
