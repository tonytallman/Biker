//
//  MockHeartRateDelegate.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Combine
import Foundation
import Sensors

final class MockHeartRateDelegate: HeartRateService.Delegate {
    var hasHeartRateService = true
    let heartRateData = PassthroughSubject<Data, Never>()

    func has(serviceId: String) async -> Bool {
        hasHeartRateService
    }

    func subscribeTo(characteristicId: String) -> AnyPublisher<Data, Never> {
        heartRateData.eraseToAnyPublisher()
    }
}
