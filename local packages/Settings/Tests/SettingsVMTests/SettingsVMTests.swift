//
//  SettingsVMTests.swift
//  SettingsVMTests
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation
import Testing
import SettingsVM
import SettingsModel

@MainActor
@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {
    let metricsSettings: SettingsModel.Settings
    let systemSettings: SettingsModel.SystemSettings
    let mockScreenController: MockScreenController
    let mockLocationPermissions: MockLocationPermissionsSettings
    let mockBluetoothPermissions: MockBluetoothPermissionsSettings
    let mockSystemSettingsNavigator: MockSystemSettingsNavigator
    let mockForegroundNotifier: MockForegroundNotifier
    let viewModel: SettingsVM.SettingsViewModel
    
    init() {
        metricsSettings = SettingsModel.Settings()

        mockScreenController = MockScreenController()
        mockLocationPermissions = MockLocationPermissionsSettings()
        mockBluetoothPermissions = MockBluetoothPermissionsSettings()
        mockSystemSettingsNavigator = MockSystemSettingsNavigator()
        mockForegroundNotifier = MockForegroundNotifier()
        systemSettings = SettingsModel.DefaultSystemSettings(
            bluetoothPermissionsSettings: mockBluetoothPermissions,
            locationPermissionsSettings: mockLocationPermissions,
            systemSettingsNavigator: mockSystemSettingsNavigator,
            screenController: mockScreenController,
            foregroundNotifier: mockForegroundNotifier,
        )

        viewModel = SettingsVM.SettingsViewModel(
            metricsSettings: metricsSettings,
            systemSettings: systemSettings,
        )
    }
    
    @Test("Set keep screen on updates state and disables idle timer")
    func testSetKeepScreenOnUpdatesStateAndDisablesIdleTimer() {
        mockScreenController.reset() // Ignore initial emission
        
        viewModel.setKeepScreenOn(false)
        
        #expect(viewModel.keepScreenOn == false)
        #expect(mockScreenController.callCount == 1)
        #expect(mockScreenController.lastDisabledValue == false)
    }
    
    @Test("External keep screen on change updates state and disables idle timer")
    func testExternalKeepScreenOnChangeUpdatesStateAndDisablesIdleTimer() {
        mockScreenController.reset()
        
        systemSettings.setKeepScreenOn(false)
        
        #expect(viewModel.keepScreenOn == false)
        #expect(mockScreenController.callCount == 1)
        #expect(mockScreenController.lastDisabledValue == false)
    }
    
    @Test("Set speed units updates state")
    func testSetSpeedUnitsUpdatesState() {
        viewModel.setSpeedUnits(.kilometersPerHour)
        
        #expect(viewModel.currentSpeedUnits.symbol == UnitSpeed.kilometersPerHour.symbol)
    }
    
    @Test("External speed units change updates state")
    func testExternalSpeedUnitsChangeUpdatesState() {
        metricsSettings.setSpeedUnits(.kilometersPerHour)
        
        #expect(viewModel.currentSpeedUnits.symbol == UnitSpeed.kilometersPerHour.symbol)
    }
    
    @Test("Set distance units updates state")
    func testSetDistanceUnitsUpdatesState() {
        viewModel.setDistanceUnits(.kilometers)
        
        #expect(viewModel.currentDistanceUnits.symbol == UnitLength.kilometers.symbol)
    }
    
    @Test("External distance units change updates state")
    func testExternalDistanceUnitsChangeUpdatesState() {
        metricsSettings.setDistanceUnits(.kilometers)
        
        #expect(viewModel.currentDistanceUnits.symbol == UnitLength.kilometers.symbol)
    }
    
    @Test("Set auto pause threshold updates state")
    func testSetAutoPauseThresholdUpdatesState() {
        let mph = Measurement(value: 5.0, unit: UnitSpeed.milesPerHour)
        viewModel.setAutoPauseThreshold(mph)
        
        let current = viewModel.currentAutoPauseThreshold
        let convertedValue = current.converted(to: .milesPerHour).value
        #expect(abs(convertedValue - 5.0) < 0.0001)
    }
    
    @Test("External auto pause threshold change updates state")
    func testExternalAutoPauseThresholdChangeUpdatesState() {
        let kph = Measurement(value: 7.0, unit: UnitSpeed.kilometersPerHour)
        metricsSettings.setAutoPauseThreshold(kph)
        
        let current = viewModel.currentAutoPauseThreshold
        let convertedValue = current.converted(to: .kilometersPerHour).value
        #expect(abs(convertedValue - 7.0) < 0.0001)
    }
    
    @Test("Refresh background statuses updates status text")
    func testRefreshBackgroundStatusesUpdatesStatusText() {
        mockLocationPermissions.locationBackgroundStatus = "Always"
        mockBluetoothPermissions.bluetoothBackgroundStatus = "Allowed"
        
        viewModel.refreshBackgroundStatuses()
        
        #expect(viewModel.locationBackgroundStatusText == "Always")
        #expect(viewModel.bluetoothBackgroundStatusText == "Allowed")
    }
    
    @Test("Open location permissions delegates to location permissions settings")
    func testOpenLocationPermissionsDelegatesToLocationPermissionsSettings() {
        mockSystemSettingsNavigator.reset()
        
        viewModel.openLocationPermissions()
        
        #expect(mockSystemSettingsNavigator.openPermissionsCallCount == 1)
    }
    
    @Test("Open bluetooth permissions delegates to bluetooth permissions settings")
    func testOpenBluetoothPermissionsDelegatesToBluetoothPermissionsSettings() {
        mockSystemSettingsNavigator.reset()
        
        viewModel.openBluetoothPermissions()
        
        #expect(mockSystemSettingsNavigator.openPermissionsCallCount == 1)
    }
}
