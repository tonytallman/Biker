//
//  BluetoothAvailabilityAdapterTests.swift
//  DependencyContainerTests
//

import CyclingSpeedAndCadenceService
import Foundation
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
}
