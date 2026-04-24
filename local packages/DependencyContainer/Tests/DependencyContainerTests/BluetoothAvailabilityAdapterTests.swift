//
//  BluetoothAvailabilityAdapterTests.swift
//  DependencyContainerTests
//

import Combine
import CyclingSpeedAndCadenceService
import FitnessMachineService
import Foundation
import HeartRateService
import SettingsVM
import Testing

@testable import DependencyContainer

struct BluetoothAvailabilityAdapterTests {
    @Test
    func mapsOneToOne() {
        for csc in CSCBluetoothAvailability.allCases {
            let mapped = BluetoothAvailabilityAdapter.map(csc)
            switch csc {
            case .notDetermined: #expect(mapped == .notDetermined)
            case .denied: #expect(mapped == .denied)
            case .restricted: #expect(mapped == .restricted)
            case .unsupported: #expect(mapped == .unsupported)
            case .resetting: #expect(mapped == .resetting)
            case .poweredOff: #expect(mapped == .poweredOff)
            case .poweredOn: #expect(mapped == .poweredOn)
            }
        }
    }

    @Test
    func mapsFTMSOneToOne() {
        for ftms in FTMSBluetoothAvailability.allCases {
            let mapped = BluetoothAvailabilityAdapter.map(ftms)
            switch ftms {
            case .notDetermined: #expect(mapped == .notDetermined)
            case .denied: #expect(mapped == .denied)
            case .restricted: #expect(mapped == .restricted)
            case .unsupported: #expect(mapped == .unsupported)
            case .resetting: #expect(mapped == .resetting)
            case .poweredOff: #expect(mapped == .poweredOff)
            case .poweredOn: #expect(mapped == .poweredOn)
            }
        }
    }

    @Test
    func mapsHROneToOne() {
        for hr in HRBluetoothAvailability.allCases {
            let mapped = BluetoothAvailabilityAdapter.map(hr)
            switch hr {
            case .notDetermined: #expect(mapped == .notDetermined)
            case .denied: #expect(mapped == .denied)
            case .restricted: #expect(mapped == .restricted)
            case .unsupported: #expect(mapped == .unsupported)
            case .resetting: #expect(mapped == .resetting)
            case .poweredOff: #expect(mapped == .poweredOff)
            case .poweredOn: #expect(mapped == .poweredOn)
            }
        }
    }

    @Test
    func moreRestrictive_prefersDeniedOverPoweredOn() {
        #expect(
            BluetoothAvailabilityAdapter.moreRestrictive(.poweredOn, .denied) == .denied
        )
        #expect(
            BluetoothAvailabilityAdapter.moreRestrictive(.denied, .poweredOn) == .denied
        )
    }

    @Test
    func moreRestrictive_orderingMatchesPlan() {
        #expect(BluetoothAvailabilityAdapter.moreRestrictive(.notDetermined, .poweredOn) == .notDetermined)
        #expect(BluetoothAvailabilityAdapter.moreRestrictive(.unsupported, .restricted) == .unsupported)
        #expect(BluetoothAvailabilityAdapter.moreRestrictive(.resetting, .poweredOff) == .resetting)
    }

    @MainActor
    @Test
    func combined_publishers_yieldsMostRestrictive() {
        let csc = CurrentValueSubject<BluetoothAvailability, Never>(.poweredOn)
        let ftms = CurrentValueSubject<BluetoothAvailability, Never>(.denied)
        var last: BluetoothAvailability?
        let sub = BluetoothAvailabilityAdapter.combined(
            csc: csc.eraseToAnyPublisher(),
            ftms: ftms.eraseToAnyPublisher()
        )
        .sink { last = $0 }
        #expect(last == .denied)
        ftms.send(.poweredOn)
        #expect(last == .poweredOn)
        csc.send(.poweredOff)
        #expect(last == .poweredOff)
        _ = sub
    }

    @MainActor
    @Test
    func combined_threePublishers_yieldsMostRestrictive() {
        let csc = CurrentValueSubject<CSCBluetoothAvailability, Never>(.poweredOn)
        let ftms = CurrentValueSubject<FTMSBluetoothAvailability, Never>(.poweredOn)
        let hr = CurrentValueSubject<HRBluetoothAvailability, Never>(.denied)
        var last: BluetoothAvailability?
        let sub = BluetoothAvailabilityAdapter.combined(
            csc: csc.eraseToAnyPublisher(),
            ftms: ftms.eraseToAnyPublisher(),
            hr: hr.eraseToAnyPublisher()
        )
        .sink { last = $0 }
        #expect(last == .denied)
        hr.send(.poweredOn)
        #expect(last == .poweredOn)
        ftms.send(.poweredOff)
        #expect(last == .poweredOff)
        _ = sub
    }
}
