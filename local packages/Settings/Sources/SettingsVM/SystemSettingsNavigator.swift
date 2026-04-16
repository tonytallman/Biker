//
//  AppSettingsNavigator.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import Foundation
import UIKit

@MainActor package protocol SystemSettingsNavigator {
    func openAppPermissions()
}

package struct DefaultSystemSettingsNavigator: SystemSettingsNavigator {
    package func openAppPermissions() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
