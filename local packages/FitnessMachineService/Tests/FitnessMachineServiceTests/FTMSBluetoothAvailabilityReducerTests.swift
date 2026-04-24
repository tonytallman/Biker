//
//  FTMSBluetoothAvailabilityReducerTests.swift
//  FitnessMachineServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation
import Testing

@testable import FitnessMachineService

@MainActor
struct FTMSBluetoothAvailabilityReducerTests {
    @Test(arguments: [CBManagerState.unknown, .resetting, .unsupported, .unauthorized, .poweredOff, .poweredOn])
    func deniedAuthorization_ignoresState(state: CBManagerState) {
        let o = FTMSBluetoothAvailabilityReducer.reduce(authorization: .denied, state: state)
        #expect(o == .denied)
    }

    @Test
    func restricted_isRestricted() {
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .restricted, state: .poweredOn) == .restricted
        )
    }

    @Test
    func notDetermined_isNotDetermined() {
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .notDetermined, state: .poweredOn)
                == .notDetermined
        )
    }

    @Test
    func allowedAlways_mapsCentralState() {
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .poweredOn) == .poweredOn
        )
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .poweredOff) == .poweredOff
        )
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .resetting) == .resetting
        )
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unsupported) == .unsupported
        )
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unauthorized) == .denied
        )
        #expect(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unknown) == .notDetermined
        )
    }
}
