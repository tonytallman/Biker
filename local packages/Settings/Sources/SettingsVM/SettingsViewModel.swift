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
import UIKit

/// Base class for settings view models.
@MainActor
@Observable
open class SettingsViewModel {
    /// Protocol for settings that can be used by SettingsViewModel
    public protocol Settings {
        var speedUnits: AnyPublisher<UnitSpeed, Never> { get }
        var distanceUnits: AnyPublisher<UnitLength, Never> { get }
        var autoPauseThreshold: AnyPublisher<Measurement<UnitSpeed>, Never> { get }
        var keepScreenOn: AnyPublisher<Bool, Never> { get }
        func setSpeedUnits(_ units: UnitSpeed)
        func setDistanceUnits(_ units: UnitLength)
        func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>)
        func setKeepScreenOn(_ keepOn: Bool)
    }

    package protocol ScreenController {
        @MainActor func setIdleTimerDisabled(_ disabled: Bool)
    }
    
    private let settings: Settings
    private let screenController: ScreenController
    private var cancellables: Set<AnyCancellable> = []
    
    public var currentSpeedUnits: UnitSpeed = .milesPerHour
    public var currentDistanceUnits: UnitLength = .miles
    public var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    public var currentKeepScreenOn: Bool = true
    
    public let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    public let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]
    
    public convenience init(settings: Settings) {
        self.init(settings: settings, screenController: DefaultScreenController())
    }
    
    package init(settings: Settings, screenController: ScreenController) {
        self.settings = settings
        self.screenController = screenController
        
        // Subscribe to settings changes
        settings.speedUnits
            .sink { [weak self] units in
                guard let self else { return }
                self.currentSpeedUnits = units
            }
            .store(in: &cancellables)
        
        settings.distanceUnits
            .sink { [weak self] units in
                guard let self else { return }
                self.currentDistanceUnits = units
            }
            .store(in: &cancellables)
        
        settings.autoPauseThreshold
            .sink { [weak self] threshold in
                guard let self else { return }
                self.currentAutoPauseThreshold = threshold
            }
            .store(in: &cancellables)
        
        settings.keepScreenOn
            .sink { [weak self] keepOn in
                guard let self else { return }
                self.currentKeepScreenOn = keepOn
                self.screenController.setIdleTimerDisabled(keepOn)
            }
            .store(in: &cancellables)
    }
    
    public func setSpeedUnits(_ units: UnitSpeed) {
        settings.setSpeedUnits(units)
    }
    
    public func setDistanceUnits(_ units: UnitLength) {
        settings.setDistanceUnits(units)
    }
    
    public func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>) {
        settings.setAutoPauseThreshold(threshold)
    }
    
    public func setKeepScreenOn(_ keepOn: Bool) {
        settings.setKeepScreenOn(keepOn)
    }
    
    private struct DefaultScreenController: ScreenController {
        @MainActor func setIdleTimerDisabled(_ disabled: Bool) {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
    }
}

/// Production implementation of SettingsViewModel
public final class ProductionSettingsViewModel: SettingsViewModel {}

extension SettingsModel.Settings: SettingsViewModel.Settings {}

