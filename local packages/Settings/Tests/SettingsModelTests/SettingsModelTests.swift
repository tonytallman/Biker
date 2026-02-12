//
//  SettingsModelTests.swift
//  SettingsModelTests
//
//  Created by Tony Tallman on 1/20/25.
//

import Combine
import Foundation
import Testing

import SettingsModel

@Suite("Settings Tests")
struct SettingsTests {
    @Test("Default values are correct")
    func testDefaultValues() async throws {
        let settings = Settings()

        var speedValues: [UnitSpeed] = []
        var distanceValues: [UnitLength] = []
        var autoPauseValues: [Measurement<UnitSpeed>] = []
        var keepScreenOnValues: [Bool] = []

        let speedCancellable = settings.speedUnits.sink { speedValues.append($0) }
        let distanceCancellable = settings.distanceUnits.sink { distanceValues.append($0) }
        let autoPauseCancellable = settings.autoPauseThreshold.sink { autoPauseValues.append($0) }
        let keepScreenOnCancellable = settings.keepScreenOn.sink { keepScreenOnValues.append($0) }

        defer {
            speedCancellable.cancel()
            distanceCancellable.cancel()
            autoPauseCancellable.cancel()
            keepScreenOnCancellable.cancel()
        }

        #expect(speedValues == [.milesPerHour])
        #expect(distanceValues == [.miles])
        #expect(autoPauseValues.count == 1)
        #expect(autoPauseValues[0].converted(to: .milesPerHour).value == 3.0)
        #expect(keepScreenOnValues == [true])
    }

    @Test("setSpeedUnits publishes new value")
    func testSetSpeedUnits() async throws {
        let settings = Settings()

        var receivedValues: [UnitSpeed] = []
        let cancellable = settings.speedUnits.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        settings.setSpeedUnits(.kilometersPerHour)

        #expect(receivedValues == [.milesPerHour, .kilometersPerHour])
    }

    @Test("setDistanceUnits publishes new value")
    func testSetDistanceUnits() async throws {
        let settings = Settings()

        var receivedValues: [UnitLength] = []
        let cancellable = settings.distanceUnits.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        settings.setDistanceUnits(.kilometers)

        #expect(receivedValues == [.miles, .kilometers])
    }

    @Test("setAutoPauseThreshold publishes new value")
    func testSetAutoPauseThreshold() async throws {
        let settings = Settings()

        var receivedValues: [Measurement<UnitSpeed>] = []
        let cancellable = settings.autoPauseThreshold.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        let newThreshold = Measurement(value: 5.0, unit: UnitSpeed.milesPerHour)
        settings.setAutoPauseThreshold(newThreshold)

        #expect(receivedValues.count == 2)
        #expect(receivedValues[0].converted(to: .milesPerHour).value == 3.0)
        #expect(receivedValues[1].converted(to: .milesPerHour).value == 5.0)
    }

    @Test("setKeepScreenOn publishes new value")
    func testSetKeepScreenOn() async throws {
        let settings = Settings()

        var receivedValues: [Bool] = []
        let cancellable = settings.keepScreenOn.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        settings.setKeepScreenOn(false)

        #expect(receivedValues == [true, false])
    }

    @Test("useMetricUnits sets both speed and distance to metric")
    func testUseMetricUnits() async throws {
        let settings = Settings()

        var speedValues: [UnitSpeed] = []
        var distanceValues: [UnitLength] = []
        let speedCancellable = settings.speedUnits.sink { speedValues.append($0) }
        let distanceCancellable = settings.distanceUnits.sink { distanceValues.append($0) }
        defer {
            speedCancellable.cancel()
            distanceCancellable.cancel()
        }

        settings.useMetricUnits()

        #expect(speedValues == [.milesPerHour, .kilometersPerHour])
        #expect(distanceValues == [.miles, .kilometers])
    }

    @Test("useImperialUnits sets both speed and distance to imperial")
    func testUseImperialUnits() async throws {
        let settings = Settings()

        var speedValues: [UnitSpeed] = []
        var distanceValues: [UnitLength] = []
        let speedCancellable = settings.speedUnits.sink { speedValues.append($0) }
        let distanceCancellable = settings.distanceUnits.sink { distanceValues.append($0) }
        defer {
            speedCancellable.cancel()
            distanceCancellable.cancel()
        }

        // First switch to metric, then back to imperial to test the reversion
        settings.useMetricUnits()
        settings.useImperialUnits()

        #expect(speedValues == [.milesPerHour, .kilometersPerHour, .milesPerHour])
        #expect(distanceValues == [.miles, .kilometers, .miles])
    }
}

@Suite("DefaultSystemSettings Tests")
@MainActor
struct DefaultSystemSettingsTests {
    private let mockScreenController: MockScreenController
    private let mockLocationPermissions: MockLocationPermissionsSettings
    private let mockBluetoothPermissions: MockBluetoothPermissionsSettings
    private let mockSystemSettingsNavigator: MockSystemSettingsNavigator
    private let mockForegroundNotifier: MockForegroundNotifier
    private let systemSettings: DefaultSystemSettings

    init() async throws {
        mockScreenController = MockScreenController()
        mockLocationPermissions = MockLocationPermissionsSettings()
        mockBluetoothPermissions = MockBluetoothPermissionsSettings()
        mockSystemSettingsNavigator = MockSystemSettingsNavigator()
        mockForegroundNotifier = MockForegroundNotifier()

        systemSettings = DefaultSystemSettings(
            bluetoothPermissionsSettings: mockBluetoothPermissions,
            locationPermissionsSettings: mockLocationPermissions,
            systemSettingsNavigator: mockSystemSettingsNavigator,
            screenController: mockScreenController,
            foregroundNotifier: mockForegroundNotifier
        )
    }

    @Test("keepScreenOn default is true")
    func testKeepScreenOnDefault() async throws {
        var receivedValues: [Bool] = []
        let cancellable = systemSettings.keepScreenOn.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        #expect(receivedValues == [true])
    }

    @Test("setKeepScreenOn publishes new value")
    func testSetKeepScreenOn() async throws {
        var receivedValues: [Bool] = []
        let cancellable = systemSettings.keepScreenOn.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        systemSettings.setKeepScreenOn(false)

        #expect(receivedValues == [true, false])
    }

    @Test("locationBackgroundStatus returns value from LocationPermissionsSettings")
    func testLocationBackgroundStatus() async throws {
        mockLocationPermissions.locationBackgroundStatus = "Always"

        #expect(systemSettings.locationBackgroundStatus == "Always")
    }

    @Test("bluetoothBackgroundStatus returns value from BluetoothPermissionsSettings")
    func testBluetoothBackgroundStatus() async throws {
        mockBluetoothPermissions.bluetoothBackgroundStatus = "Allowed"

        #expect(systemSettings.bluetoothBackgroundStatus == "Allowed")
    }

    @Test("openPermissions calls SystemSettingsNavigator.openAppPermissions")
    func testOpenPermissions() async throws {
        mockSystemSettingsNavigator.reset()

        systemSettings.openPermissions()

        #expect(mockSystemSettingsNavigator.openPermissionsCallCount == 1)
    }

    @Test("setIdleTimerDisabled calls ScreenController.setIdleTimerDisabled")
    func testSetIdleTimerDisabled() async throws {
        mockScreenController.reset()

        systemSettings.setIdleTimerDisabled(true)

        #expect(mockScreenController.callCount == 1)
        #expect(mockScreenController.lastDisabledValue == true)
    }

    @Test("willEnterForeground publishes when ForegroundNotifier fires")
    func testWillEnterForeground() async throws {
        var receivedEvents = 0
        let cancellable = systemSettings.willEnterForeground.sink { receivedEvents += 1 }
        defer { cancellable.cancel() }

        #expect(receivedEvents == 0)

        mockForegroundNotifier.sendWillEnterForeground()

        #expect(receivedEvents == 1)
    }
}
