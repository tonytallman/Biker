//
//  MockFitnessMachineDelegate.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Combine
import Foundation

import Sensors

final class MockFitnessMachineDelegate: FitnessMachineService.Delegate {
    var hasFitnessMachineService = true
    var featureCharacteristicValue: Data?
    let indoorBikeData = PassthroughSubject<Data, Never>()

    func has(serviceId: String) async -> Bool {
        hasFitnessMachineService
    }

    func read(characteristicId: String) async -> Data? {
        featureCharacteristicValue
    }

    func subscribeTo(characteristicId: String) -> AnyPublisher<Data, Never> {
        indoorBikeData.eraseToAnyPublisher()
    }
}
