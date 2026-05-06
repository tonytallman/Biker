//
//  MockCyclingSpeedAndCadenceDelegate.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Combine
import Foundation

import Sensors

final class MockCyclingSpeedAndCadenceDelegate: CyclingSpeedAndCadenceService.Delegate {
    var hasCSCService = true
    var featureCharacteristicValue: Data?
    let measurementData = PassthroughSubject<Data, Never>()

    func has(serviceId: String) async -> Bool {
        hasCSCService
    }

    func read(characteristicId: String) async -> Data? {
        featureCharacteristicValue
    }

    func subscribeTo(characteristicId: String) -> AnyPublisher<Data, Never> {
        measurementData.eraseToAnyPublisher()
    }
}
