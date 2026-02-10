//
//  SettingsViewModel.swift
//  PhoneUI
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import CoreBluetooth
import CoreLocation
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
    
    private let settings: Settings
    private let screenController: ScreenController
    private let locationPermissionsSettings: LocationPermissionsSettings
    private let bluetoothPermissionsSettings: BluetoothPermissionsSettings
    private var cancellables: Set<AnyCancellable> = []
    
    public var currentSpeedUnits: UnitSpeed = .milesPerHour
    public var currentDistanceUnits: UnitLength = .miles
    public var currentAutoPauseThreshold: Measurement<UnitSpeed> = .init(value: 3, unit: .milesPerHour)
    public var currentKeepScreenOn: Bool = true
    public var locationBackgroundStatusText: String = ""
    public var bluetoothBackgroundStatusText: String = ""
    
    public let availableSpeedUnits: [UnitSpeed] = [.milesPerHour, .kilometersPerHour]
    public let availableDistanceUnits: [UnitLength] = [.miles, .kilometers]
    
    public convenience init(settings: Settings) {
        self.init(
            settings: settings,
            screenController: DefaultScreenController(),
            locationPermissionsSettings: DefaultLocationPermissionsSettings(),
            bluetoothPermissionsSettings: DefaultBluetoothPermissionsSettings()
        )
    }
    
    package init(
        settings: Settings,
        screenController: ScreenController,
        locationPermissionsSettings: LocationPermissionsSettings,
        bluetoothPermissionsSettings: BluetoothPermissionsSettings
    ) {
        self.settings = settings
        self.screenController = screenController
        self.locationPermissionsSettings = locationPermissionsSettings
        self.bluetoothPermissionsSettings = bluetoothPermissionsSettings
        
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
        
        // Subscribe to foreground notification to refresh statuses when returning from Settings
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshBackgroundStatuses()
            }
            .store(in: &cancellables)
        
        // Initial refresh of background statuses
        refreshBackgroundStatuses()
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
    
    public func openBluetoothPermissions() {
        bluetoothPermissionsSettings.openPermissions()
    }
    
    public func openLocationPermissions() {
        locationPermissionsSettings.openPermissions()
    }
    
    public func refreshBackgroundStatuses() {
        locationBackgroundStatusText = locationPermissionsSettings.locationBackgroundStatus
        bluetoothBackgroundStatusText = bluetoothPermissionsSettings.bluetoothBackgroundStatus
    }
}

/// Production implementation of SettingsViewModel
public final class ProductionSettingsViewModel: SettingsViewModel {}

extension SettingsModel.Settings: SettingsViewModel.Settings {}
