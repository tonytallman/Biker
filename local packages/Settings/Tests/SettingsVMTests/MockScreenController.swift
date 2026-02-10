//
//  MockScreenController.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//

import SettingsModel

@MainActor
final class MockScreenController: ScreenController {
    var callCount = 0
    var lastDisabledValue: Bool? = nil
    
    func setIdleTimerDisabled(_ disabled: Bool) {
        callCount += 1
        lastDisabledValue = disabled
    }
    
    func reset() {
        callCount = 0
        lastDisabledValue = nil
    }
}
