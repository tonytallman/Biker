//
//  MockFitnessMachineDelegate.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Sensors

final class MockFitnessMachineDelegate: FitnessMachineService.Delegate {
    var hasFitnessMachineService = true
    var featureCharacteristicValue: Data?

    private let indoorBikeContinuation: AsyncStream<Data>.Continuation
    private let indoorBikeStream: AsyncStream<Data>

    init() {
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.indoorBikeStream = stream
        self.indoorBikeContinuation = continuation
    }

    func has(serviceId: String) async -> Bool {
        hasFitnessMachineService
    }

    func read(characteristicId: String) async -> Data? {
        featureCharacteristicValue
    }

    func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        indoorBikeStream
    }

    func sendIndoorBikeData(_ data: Data) {
        indoorBikeContinuation.yield(data)
    }
}
