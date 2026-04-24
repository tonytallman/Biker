//
//  HRBluetoothAvailabilityReducerTests.swift
//  HeartRateServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation
import Testing

@testable import HeartRateService

@MainActor
struct HRBluetoothAvailabilityReducerTests {
    @Test(arguments: [CBManagerState.unknown, .resetting, .unsupported, .unauthorized, .poweredOff, .poweredOn])
    func deniedAuthorization_ignoresState(state: CBManagerState) {
        let o = HRBluetoothAvailabilityReducer.reduce(authorization: .denied, state: state)
        #expect(o == .denied)
    }

    @Test
    func restricted_isRestricted() {
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .restricted, state: .poweredOn) == .restricted
        )
    }

    @Test
    func notDetermined_isNotDetermined() {
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .notDetermined, state: .poweredOn)
                == .notDetermined
        )
    }

    @Test
    func allowedAlways_mapsCentralState() {
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .poweredOn) == .poweredOn
        )
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .poweredOff) == .poweredOff
        )
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .resetting) == .resetting
        )
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unsupported) == .unsupported
        )
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unauthorized) == .denied
        )
        #expect(
            HRBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unknown) == .notDetermined
        )
    }
}
