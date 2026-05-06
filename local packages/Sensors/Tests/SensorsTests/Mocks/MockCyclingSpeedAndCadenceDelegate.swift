//
//  MockCyclingSpeedAndCadenceDelegate.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Sensors

final class MockCyclingSpeedAndCadenceDelegate: CyclingSpeedAndCadenceService.Delegate {
    var hasCSCService = true
    var featureCharacteristicValue: Data?

    private let measurementContinuation: AsyncStream<Data>.Continuation
    private let measurementStream: AsyncStream<Data>

    init() {
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.measurementStream = stream
        self.measurementContinuation = continuation
    }

    func has(serviceId: String) async -> Bool {
        hasCSCService
    }

    func read(characteristicId: String) async -> Data? {
        featureCharacteristicValue
    }

    func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        measurementStream
    }

    func sendMeasurement(_ data: Data) {
        measurementContinuation.yield(data)
    }
}
