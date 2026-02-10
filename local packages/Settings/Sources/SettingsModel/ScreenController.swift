//
//  ScreenController.swift
//  Settings
//
//  Created by Tony Tallman on 2/9/26.
//


import UIKit

package protocol ScreenController {
  @MainActor func setIdleTimerDisabled(_ disabled: Bool)
}

package struct DefaultScreenController: ScreenController {
  @MainActor public init() {}
  @MainActor public func setIdleTimerDisabled(_ disabled: Bool) {
      UIApplication.shared.isIdleTimerDisabled = disabled
  }
}
