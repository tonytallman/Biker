//
//  CSCBluetoothAvailabilityReducerTests.swift
//  CyclingSpeedAndCadenceServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService

@MainActor
struct CSCBluetoothAvailabilityReducerTests {
    @Test(arguments: [CBManagerState.unknown, .resetting, .unsupported, .unauthorized, .poweredOff, .poweredOn])
    func deniedAuthorization_ignoresState(state: CBManagerState) {
        let o = CSCBluetoothAvailabilityReducer.reduce(authorization: .denied, state: state)
        #expect(o == .denied)
    }

    @Test
    func restricted_isRestricted() {
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .restricted, state: .poweredOn) == .restricted
        )
    }

    @Test
    func notDetermined_isNotDetermined() {
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .notDetermined, state: .poweredOn)
                == .notDetermined
        )
    }

    @Test
    func allowedAlways_mapsCentralState() {
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .poweredOn) == .poweredOn
        )
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .poweredOff) == .poweredOff
        )
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .resetting) == .resetting
        )
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unsupported) == .unsupported
        )
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unauthorized) == .denied
        )
        #expect(
            CSCBluetoothAvailabilityReducer.reduce(authorization: .allowedAlways, state: .unknown) == .notDetermined
        )
    }
}
