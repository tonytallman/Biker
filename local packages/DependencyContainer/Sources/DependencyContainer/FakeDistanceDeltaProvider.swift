//
//  FakeDistanceDeltaProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation

import CoreLogic

/// Fake distance delta provider to be used while production providers are under development.
/// Emits distance deltas in meters that match approximately 20 mph (~8.94 m/s).
enum FakeDistanceDeltaProvider {
    static func makeDistanceDelta() -> AnyPublisher<Measurement<UnitLength>, Never> {
        let defaultDelta = 8.94 // meters per second (approximately 20 mph)
        let unit: UnitLength = .meters
        let subject = CurrentValueSubject<Measurement<UnitLength>, Never>(.init(value: defaultDelta, unit: unit))
        
        // Create the timer and merge it into the publisher chain
        // The timer publisher will be retained as long as there are subscribers
        let timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { _ -> Measurement<UnitLength> in
                let currentValue = subject.value.value
                let bias = (defaultDelta - currentValue) / defaultDelta
                let offset = Double.random(in: (-0.5 + bias) ... (0.5 + bias))
                let newValue = currentValue + offset
                return Measurement(value: newValue, unit: unit)
            }
            .eraseToAnyPublisher()
        
        // Merge the initial value with the timer updates
        // The subject and timer are both retained as long as there are subscribers
        return Publishers.Merge(
            subject.prefix(1),
            timerPublisher
        )
        .handleEvents(receiveOutput: { value in
            subject.send(value)
        })
        .share()
        .eraseToAnyPublisher()
    }
}
