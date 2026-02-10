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
    let settings: SettingsModel.Settings
    let mockScreenController: MockScreenController
    let mockLocationPermissions: MockLocationPermissionsSettings
    let mockBluetoothPermissions: MockBluetoothPermissionsSettings
    let viewModel: SettingsVM.SettingsViewModel
    
    init() {
        settings = SettingsModel.Settings()
        mockScreenController = MockScreenController()
        mockLocationPermissions = MockLocationPermissionsSettings()
        mockBluetoothPermissions = MockBluetoothPermissionsSettings()
        viewModel = SettingsVM.SettingsViewModel(
            settings: settings,
            screenController: mockScreenController,
            locationPermissionsSettings: mockLocationPermissions,
            bluetoothPermissionsSettings: mockBluetoothPermissions
        )
    }
    
    @Test("Set keep screen on updates state and disables idle timer")
    func testSetKeepScreenOnUpdatesStateAndDisablesIdleTimer() {
        mockScreenController.reset() // Ignore initial emission
        
        viewModel.setKeepScreenOn(false)
        
        #expect(viewModel.currentKeepScreenOn == false)
        #expect(mockScreenController.callCount == 1)
        #expect(mockScreenController.lastDisabledValue == false)
    }
    
    @Test("External keep screen on change updates state and disables idle timer")
    func testExternalKeepScreenOnChangeUpdatesStateAndDisablesIdleTimer() {
        mockScreenController.reset()
        
        settings.setKeepScreenOn(false)
        
        #expect(viewModel.currentKeepScreenOn == false)
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
        settings.setSpeedUnits(.kilometersPerHour)
        
        #expect(viewModel.currentSpeedUnits.symbol == UnitSpeed.kilometersPerHour.symbol)
    }
    
    @Test("Set distance units updates state")
    func testSetDistanceUnitsUpdatesState() {
        viewModel.setDistanceUnits(.kilometers)
        
        #expect(viewModel.currentDistanceUnits.symbol == UnitLength.kilometers.symbol)
    }
    
    @Test("External distance units change updates state")
    func testExternalDistanceUnitsChangeUpdatesState() {
        settings.setDistanceUnits(.kilometers)
        
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
        settings.setAutoPauseThreshold(kph)
        
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
        mockLocationPermissions.reset()
        
        viewModel.openLocationPermissions()
        
        #expect(mockLocationPermissions.openPermissionsCallCount == 1)
    }
    
    @Test("Open bluetooth permissions delegates to bluetooth permissions settings")
    func testOpenBluetoothPermissionsDelegatesToBluetoothPermissionsSettings() {
        mockBluetoothPermissions.reset()
        
        viewModel.openBluetoothPermissions()
        
        #expect(mockBluetoothPermissions.openPermissionsCallCount == 1)
    }
}

