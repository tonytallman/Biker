//
//  SystemSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import Combine
import Foundation

@MainActor
public protocol SystemSettings {
    var keepScreenOn: any Subject<Bool, Never> { get }
    var willEnterForeground: AnyPublisher<Void, Never> { get }
    var locationBackgroundStatus: String { get }
    var bluetoothBackgroundStatus: String { get }
    func openPermissions()
    func setIdleTimerDisabled(_ disabled: Bool)
}

private let keepScreenOnKey = "keepScreenOn"

@MainActor
public final class DefaultSystemSettings: SystemSettings {
    private let storage: SettingsStorage
    private let bluetoothPermissionsSettings: BluetoothPermissionsSettings
    private let locationPermissionsSettings: LocationPermissionsSettings
    private let systemSettingsNavigator: SystemSettingsNavigator
    private let screenController: ScreenController
    private let foregroundNotifier: ForegroundNotifier
    private var cancellables: Set<AnyCancellable> = []

    public let keepScreenOn: any Subject<Bool, Never>

    public convenience init(storage: SettingsStorage) {
        self.init(
            storage: storage,
            bluetoothPermissionsSettings: DefaultBluetoothPermissionsSettings(),
            locationPermissionsSettings: DefaultLocationPermissionsSettings(),
            systemSettingsNavigator: DefaultSystemSettingsNavigator(),
            screenController: DefaultScreenController(),
            foregroundNotifier: DefaultForegroundNotifier()
        )
    }

    package init(
        storage: SettingsStorage,
        bluetoothPermissionsSettings: BluetoothPermissionsSettings,
        locationPermissionsSettings: LocationPermissionsSettings,
        systemSettingsNavigator: SystemSettingsNavigator,
        screenController: ScreenController,
        foregroundNotifier: ForegroundNotifier
    ) {
        self.storage = storage
        self.bluetoothPermissionsSettings = bluetoothPermissionsSettings
        self.locationPermissionsSettings = locationPermissionsSettings
        self.systemSettingsNavigator = systemSettingsNavigator
        self.screenController = screenController
        self.foregroundNotifier = foregroundNotifier

        let initialKeepScreenOn = (storage.get(forKey: keepScreenOnKey) as? Bool) ?? true
        let subject = CurrentValueSubject<Bool, Never>(initialKeepScreenOn)
        self.keepScreenOn = subject

        subject.dropFirst().sink { [storage] value in
            storage.set(value: value, forKey: keepScreenOnKey)
        }.store(in: &cancellables)
    }

    public var willEnterForeground: AnyPublisher<Void, Never> {
        foregroundNotifier.willEnterForeground
    }

    public var locationBackgroundStatus: String {
        locationPermissionsSettings.locationBackgroundStatus
    }

    public var bluetoothBackgroundStatus: String {
        bluetoothPermissionsSettings.bluetoothBackgroundStatus
    }

    public func openPermissions() {
        systemSettingsNavigator.openAppPermissions()
    }

    public func setIdleTimerDisabled(_ disabled: Bool) {
        screenController.setIdleTimerDisabled(disabled)
    }
}
