//
//  SettingsViewModel.swift
//  CoreLogic
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine

/// Base class for settings view models.
@MainActor
open class SettingsViewModel: ObservableObject {
    @Published public var speedUnits: String = "--"
    
    public init() {
    }
}

/// Production implementation of SettingsViewModel
final class ProductionSettingsViewModel: SettingsViewModel {
    override init() {
        super.init()
    }
}
