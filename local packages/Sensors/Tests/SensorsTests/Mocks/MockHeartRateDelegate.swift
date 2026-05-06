//
//  MockHeartRateDelegate.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Sensors

final class MockHeartRateDelegate: HeartRateService.Delegate {
    var hasHeartRateService = true

    private let dataContinuation: AsyncStream<Data>.Continuation
    private let dataStream: AsyncStream<Data>

    init() {
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.dataStream = stream
        self.dataContinuation = continuation
    }

    func has(serviceId: String) async -> Bool {
        hasHeartRateService
    }

    func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        dataStream
    }

    func send(_ data: Data) {
        dataContinuation.yield(data)
    }
}
