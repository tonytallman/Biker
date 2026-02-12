//
//  SystemSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import Combine

@MainActor
package protocol SystemSettings {
    var keepScreenOn: any Subject<Bool, Never> { get }
    var willEnterForeground: AnyPublisher<Void, Never> { get }
    var locationBackgroundStatus: String { get }
    var bluetoothBackgroundStatus: String { get }
    func openPermissions()
    func setIdleTimerDisabled(_ disabled: Bool)
}

@MainActor
package final class DefaultSystemSettings: SystemSettings {
    private let bluetoothPermissionsSettings: BluetoothPermissionsSettings
    private let locationPermissionsSettings: LocationPermissionsSettings
    private let systemSettingsNavigator: SystemSettingsNavigator
    private let screenController: ScreenController
    private let foregroundNotifier: ForegroundNotifier

    package let keepScreenOn: any Subject<Bool, Never> = CurrentValueSubject<Bool, Never>(true)

    @MainActor package convenience init() {
        self.init(
            bluetoothPermissionsSettings: DefaultBluetoothPermissionsSettings(),
            locationPermissionsSettings: DefaultLocationPermissionsSettings(),
            systemSettingsNavigator: DefaultSystemSettingsNavigator(),
            screenController: DefaultScreenController(),
            foregroundNotifier: DefaultForegroundNotifier()
        )
    }

    package init(
        bluetoothPermissionsSettings: BluetoothPermissionsSettings,
        locationPermissionsSettings: LocationPermissionsSettings,
        systemSettingsNavigator: SystemSettingsNavigator,
        screenController: ScreenController,
        foregroundNotifier: ForegroundNotifier
    ) {
        self.bluetoothPermissionsSettings = bluetoothPermissionsSettings
        self.locationPermissionsSettings = locationPermissionsSettings
        self.systemSettingsNavigator = systemSettingsNavigator
        self.screenController = screenController
        self.foregroundNotifier = foregroundNotifier
    }

    package var willEnterForeground: AnyPublisher<Void, Never> {
        foregroundNotifier.willEnterForeground
    }

    package var locationBackgroundStatus: String {
        locationPermissionsSettings.locationBackgroundStatus
    }

    package var bluetoothBackgroundStatus: String {
        bluetoothPermissionsSettings.bluetoothBackgroundStatus
    }

    package func openPermissions() {
        systemSettingsNavigator.openAppPermissions()
    }

    package func setIdleTimerDisabled(_ disabled: Bool) {
        screenController.setIdleTimerDisabled(disabled)
    }
}
