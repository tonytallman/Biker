//
//  SettingsViewModel.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation
import Observation

import SettingsModel

/// Base class for settings view models.
@MainActor
@Observable
open class SettingsViewModel {
    /// Protocol for preferences that can be used by SettingsViewModel
    public protocol Settings {
        var speedUnits: AnyPublisher<UnitSpeed, Never> { get }
        var distanceUnits: AnyPublisher<UnitLength, Never> { get }
        var autoPauseThreshold: AnyPublisher<Measurement<UnitSpeed>, Never> { get }
        func setSpeedUnits(_ units: UnitSpeed)
        func setDistanceUnits(_ units: UnitLength)
        func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>)
    }
    
    private let preferences: Settings
    private var cancellables: Set<AnyCancellable> = []
    
    public var currentSpeedUnits: UnitSpeed = .milesPerHour
    public var currentDistanceUnits: UnitLength = .miles
    public var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    
    public let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    public let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]
    
    public init(preferences: Settings) {
        self.preferences = preferences
        
        // Subscribe to preference changes
        preferences.speedUnits
            .sink { [weak self] units in
                guard let self else { return }
                self.currentSpeedUnits = units
            }
            .store(in: &cancellables)
        
        preferences.distanceUnits
            .sink { [weak self] units in
                guard let self else { return }
                self.currentDistanceUnits = units
            }
            .store(in: &cancellables)
        
        preferences.autoPauseThreshold
            .sink { [weak self] threshold in
                guard let self else { return }
                self.currentAutoPauseThreshold = threshold
            }
            .store(in: &cancellables)
    }
    
    public func setSpeedUnits(_ units: UnitSpeed) {
        preferences.setSpeedUnits(units)
    }
    
    public func setDistanceUnits(_ units: UnitLength) {
        preferences.setDistanceUnits(units)
    }
    
    public func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>) {
        preferences.setAutoPauseThreshold(threshold)
    }
}

/// Production implementation of SettingsViewModel
public final class ProductionSettingsViewModel: SettingsViewModel {
    public override init(preferences: Settings) {
        super.init(preferences: preferences)
    }
}

extension SettingsModel.Settings: SettingsViewModel.Settings {}
