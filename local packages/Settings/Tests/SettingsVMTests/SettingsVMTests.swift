//
//  SettingsVMTests.swift
//  SettingsVMTests
//
//  Created by Tony Tallman on 1/20/25.
//

import XCTest
@testable import SettingsVM
import SettingsModel

@MainActor
final class SettingsViewModelTests: XCTestCase {
    @MainActor
    final class MockScreenController: SettingsViewModel.ScreenController {
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
    
    var settings: SettingsModel.Settings!
    var mock: MockScreenController!
    var viewModel: SettingsVM.SettingsViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        settings = SettingsModel.Settings()
        mock = MockScreenController()
        viewModel = SettingsVM.SettingsViewModel(settings: settings, screenController: mock)
    }
    
    func testSetKeepScreenOnUpdatesStateAndDisablesIdleTimer() {
        mock.reset() // Ignore initial emission
        
        viewModel.setKeepScreenOn(false)
        
        XCTAssertEqual(viewModel.currentKeepScreenOn, false)
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(mock.lastDisabledValue, false)
    }
    
    func testExternalKeepScreenOnChangeUpdatesStateAndDisablesIdleTimer() {
        mock.reset()
        
        settings.setKeepScreenOn(false)
        
        XCTAssertEqual(viewModel.currentKeepScreenOn, false)
        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(mock.lastDisabledValue, false)
    }
    
    func testSetSpeedUnitsUpdatesState() {
        viewModel.setSpeedUnits(.kilometersPerHour)
        
        XCTAssertEqual(viewModel.currentSpeedUnits.symbol, UnitSpeed.kilometersPerHour.symbol)
    }
    
    func testExternalSpeedUnitsChangeUpdatesState() {
        settings.setSpeedUnits(.kilometersPerHour)
        
        XCTAssertEqual(viewModel.currentSpeedUnits.symbol, UnitSpeed.kilometersPerHour.symbol)
    }
    
    func testSetDistanceUnitsUpdatesState() {
        viewModel.setDistanceUnits(.kilometers)
        
        XCTAssertEqual(viewModel.currentDistanceUnits.symbol, UnitLength.kilometers.symbol)
    }
    
    func testExternalDistanceUnitsChangeUpdatesState() {
        settings.setDistanceUnits(.kilometers)
        
        XCTAssertEqual(viewModel.currentDistanceUnits.symbol, UnitLength.kilometers.symbol)
    }
    
    func testSetAutoPauseThresholdUpdatesState() {
        let mph = Measurement(value: 5.0, unit: UnitSpeed.milesPerHour)
        viewModel.setAutoPauseThreshold(mph)
        
        let current = viewModel.currentAutoPauseThreshold
        XCTAssertEqual(current.converted(to: .milesPerHour).value, 5.0, accuracy: 0.0001)
    }
    
    func testExternalAutoPauseThresholdChangeUpdatesState() {
        let kph = Measurement(value: 7.0, unit: UnitSpeed.kilometersPerHour)
        settings.setAutoPauseThreshold(kph)
        
        let current = viewModel.currentAutoPauseThreshold
        XCTAssertEqual(current.converted(to: .kilometersPerHour).value, 7.0, accuracy: 0.0001)
    }
}

