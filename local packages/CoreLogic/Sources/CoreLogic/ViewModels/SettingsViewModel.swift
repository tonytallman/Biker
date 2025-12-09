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
    /// Protocol for preferences that can be used by SettingsViewModel
    public protocol Preferences {
        var speedUnits: AnyPublisher<UnitSpeed, Never> { get }
        var distanceUnits: AnyPublisher<UnitLength, Never> { get }
        func setSpeedUnits(_ units: UnitSpeed)
        func setDistanceUnits(_ units: UnitLength)
    }
    
    private let preferences: Preferences
    
    @Published public var currentSpeedUnits: UnitSpeed = .milesPerHour
    @Published public var currentDistanceUnits: UnitLength = .miles
    
    public let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    public let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]
    
    public init(preferences: Preferences) {
        self.preferences = preferences
        
        // Subscribe to preference changes
        preferences.speedUnits
            .assign(to: &$currentSpeedUnits)
        
        preferences.distanceUnits
            .assign(to: &$currentDistanceUnits)
    }
    
    public func setSpeedUnits(_ units: UnitSpeed) {
        preferences.setSpeedUnits(units)
    }
    
    public func setDistanceUnits(_ units: UnitLength) {
        preferences.setDistanceUnits(units)
    }
}

/// Production implementation of SettingsViewModel
final class ProductionSettingsViewModel: SettingsViewModel {
    override init(preferences: Preferences) {
        super.init(preferences: preferences)
    }
}
