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

@Suite("InMemorySettingsStorage Tests")
struct InMemorySettingsStorageTests {
    @Test("get returns nil for missing key")
    func getMissingKey() {
        let storage = InMemorySettingsStorage()
        #expect(storage.get(forKey: "missing") == nil)
    }

    @Test("set and get round-trip string")
    func setGetString() {
        let storage = InMemorySettingsStorage()
        storage.set(value: "value", forKey: "key")
        #expect(storage.get(forKey: "key") as? String == "value")
    }

    @Test("set and get round-trip bool")
    func setGetBool() {
        let storage = InMemorySettingsStorage()
        storage.set(value: true, forKey: "key")
        #expect(storage.get(forKey: "key") as? Bool == true)
    }

    @Test("set nil removes value")
    func setNilRemoves() {
        let storage = InMemorySettingsStorage()
        storage.set(value: "value", forKey: "key")
        storage.set(value: nil, forKey: "key")
        #expect(storage.get(forKey: "key") == nil)
    }
}

@Suite("Settings Tests")
struct SettingsTests {
    @Test("Default values are correct")
    func testDefaultValues() async throws {
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

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
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

        var receivedValues: [UnitSpeed] = []
        let cancellable = settings.speedUnits.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        settings.setSpeedUnits(.kilometersPerHour)

        #expect(receivedValues == [.milesPerHour, .kilometersPerHour])
    }

    @Test("setDistanceUnits publishes new value")
    func testSetDistanceUnits() async throws {
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

        var receivedValues: [UnitLength] = []
        let cancellable = settings.distanceUnits.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        settings.setDistanceUnits(.kilometers)

        #expect(receivedValues == [.miles, .kilometers])
    }

    @Test("setAutoPauseThreshold publishes new value")
    func testSetAutoPauseThreshold() async throws {
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

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
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

        var receivedValues: [Bool] = []
        let cancellable = settings.keepScreenOn.sink { receivedValues.append($0) }
        defer { cancellable.cancel() }

        settings.setKeepScreenOn(false)

        #expect(receivedValues == [true, false])
    }

    @Test("useMetricUnits sets both speed and distance to metric")
    func testUseMetricUnits() async throws {
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

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
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())

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

    // MARK: - Persistence

    @Test("Settings restores speed units from storage")
    func testRestoresSpeedUnitsFromStorage() async throws {
        let storage = MockSettingsStorage()
        storage.set(value: SpeedUnitKey.kilometersPerHour.rawValue, forKey: "speedUnits")

        let settings = DefaultMetricsSettings(storage: storage)
        var received: [UnitSpeed] = []
        let cancellable = settings.speedUnits.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [.kilometersPerHour])
    }

    @Test("Settings restores distance units from storage")
    func testRestoresDistanceUnitsFromStorage() async throws {
        let storage = MockSettingsStorage()
        storage.set(value: DistanceUnitKey.kilometers.rawValue, forKey: "distanceUnits")

        let settings = DefaultMetricsSettings(storage: storage)
        var received: [UnitLength] = []
        let cancellable = settings.distanceUnits.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [.kilometers])
    }

    @Test("Settings restores autoPauseThreshold from storage")
    func testRestoresAutoPauseThresholdFromStorage() async throws {
        let storage = MockSettingsStorage()
        let fiveMphInMetersPerSecond = Measurement(value: 5, unit: UnitSpeed.milesPerHour).converted(to: .metersPerSecond).value
        storage.set(value: fiveMphInMetersPerSecond, forKey: "autoPauseThresholdBaseValue")
        storage.set(value: SpeedUnitKey.milesPerHour.rawValue, forKey: "autoPauseThresholdUnit")

        let settings = DefaultMetricsSettings(storage: storage)
        var received: [Measurement<UnitSpeed>] = []
        let cancellable = settings.autoPauseThreshold.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received.count == 1)
        #expect(received[0].converted(to: .milesPerHour).value == 5.0)
    }

    @Test("Settings persists speed units when value changes")
    func testPersistsSpeedUnits() async throws {
        let storage = MockSettingsStorage()
        let settings1 = DefaultMetricsSettings(storage: storage)
        settings1.setSpeedUnits(.kilometersPerHour)

        let settings2 = DefaultMetricsSettings(storage: storage)
        var received: [UnitSpeed] = []
        let cancellable = settings2.speedUnits.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [.kilometersPerHour])
    }

    @Test("Settings persists distance units when value changes")
    func testPersistsDistanceUnits() async throws {
        let storage = MockSettingsStorage()
        let settings1 = DefaultMetricsSettings(storage: storage)
        settings1.setDistanceUnits(.kilometers)

        let settings2 = DefaultMetricsSettings(storage: storage)
        var received: [UnitLength] = []
        let cancellable = settings2.distanceUnits.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [.kilometers])
    }

    @Test("Settings persists autoPauseThreshold when value changes")
    func testPersistsAutoPauseThreshold() async throws {
        let storage = MockSettingsStorage()
        let settings1 = DefaultMetricsSettings(storage: storage)
        let threshold = Measurement(value: 4.5, unit: UnitSpeed.milesPerHour)
        settings1.setAutoPauseThreshold(threshold)

        let settings2 = DefaultMetricsSettings(storage: storage)
        var received: [Measurement<UnitSpeed>] = []
        let cancellable = settings2.autoPauseThreshold.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received.count == 1)
        #expect(received[0].converted(to: .milesPerHour).value == 4.5)
    }

    @Test("Settings falls back to defaults when storage is empty")
    func testFallsBackToDefaultsWhenStorageEmpty() async throws {
        let settings = DefaultMetricsSettings(storage: MockSettingsStorage())
        var speed: [UnitSpeed] = []
        var distance: [UnitLength] = []
        var threshold: [Measurement<UnitSpeed>] = []
        let c1 = settings.speedUnits.sink { speed.append($0) }
        let c2 = settings.distanceUnits.sink { distance.append($0) }
        let c3 = settings.autoPauseThreshold.sink { threshold.append($0) }
        defer { c1.cancel(); c2.cancel(); c3.cancel() }

        #expect(speed == [.milesPerHour])
        #expect(distance == [.miles])
        #expect(threshold.count == 1)
        #expect(threshold[0].converted(to: .milesPerHour).value == 3.0)
    }

    @Test("Settings falls back to default autoPauseThreshold when storage has invalid data")
    func testFallsBackToDefaultAutoPauseWhenStorageInvalid() async throws {
        let storage = MockSettingsStorage()
        storage.set(value: 1.0, forKey: "autoPauseThresholdBaseValue")
        storage.set(value: "invalidUnit", forKey: "autoPauseThresholdUnit")

        let settings = DefaultMetricsSettings(storage: storage)
        var received: [Measurement<UnitSpeed>] = []
        let cancellable = settings.autoPauseThreshold.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received.count == 1)
        #expect(received[0].converted(to: .milesPerHour).value == 3.0)
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
            storage: MockSettingsStorage(),
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

        systemSettings.keepScreenOn.send(false)

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

    // MARK: - Persistence

    @Test("DefaultSystemSettings restores keepScreenOn from storage")
    func testRestoresKeepScreenOnFromStorage() async throws {
        let storage = MockSettingsStorage()
        storage.set(value: false, forKey: "keepScreenOn")
        let systemSettings = DefaultSystemSettings(
            storage: storage,
            bluetoothPermissionsSettings: MockBluetoothPermissionsSettings(),
            locationPermissionsSettings: MockLocationPermissionsSettings(),
            systemSettingsNavigator: MockSystemSettingsNavigator(),
            screenController: MockScreenController(),
            foregroundNotifier: MockForegroundNotifier()
        )
        var received: [Bool] = []
        let cancellable = systemSettings.keepScreenOn.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [false])
    }

    @Test("DefaultSystemSettings persists keepScreenOn when value changes")
    func testPersistsKeepScreenOn() async throws {
        let storage = MockSettingsStorage()
        let systemSettings1 = DefaultSystemSettings(
            storage: storage,
            bluetoothPermissionsSettings: MockBluetoothPermissionsSettings(),
            locationPermissionsSettings: MockLocationPermissionsSettings(),
            systemSettingsNavigator: MockSystemSettingsNavigator(),
            screenController: MockScreenController(),
            foregroundNotifier: MockForegroundNotifier()
        )
        systemSettings1.keepScreenOn.send(false)

        let systemSettings2 = DefaultSystemSettings(
            storage: storage,
            bluetoothPermissionsSettings: MockBluetoothPermissionsSettings(),
            locationPermissionsSettings: MockLocationPermissionsSettings(),
            systemSettingsNavigator: MockSystemSettingsNavigator(),
            screenController: MockScreenController(),
            foregroundNotifier: MockForegroundNotifier()
        )
        var received: [Bool] = []
        let cancellable = systemSettings2.keepScreenOn.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [false])
    }

    @Test("DefaultSystemSettings keepScreenOn defaults to true when storage empty")
    func testKeepScreenOnDefaultsWhenStorageEmpty() async throws {
        let systemSettings = DefaultSystemSettings(
            storage: MockSettingsStorage(),
            bluetoothPermissionsSettings: MockBluetoothPermissionsSettings(),
            locationPermissionsSettings: MockLocationPermissionsSettings(),
            systemSettingsNavigator: MockSystemSettingsNavigator(),
            screenController: MockScreenController(),
            foregroundNotifier: MockForegroundNotifier()
        )
        var received: [Bool] = []
        let cancellable = systemSettings.keepScreenOn.sink { received.append($0) }
        defer { cancellable.cancel() }

        #expect(received == [true])
    }
}
