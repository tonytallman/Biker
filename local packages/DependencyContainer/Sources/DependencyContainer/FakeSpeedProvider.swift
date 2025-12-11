//
//  FakeSpeedProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine
import CoreLogic

/// Fake speed provider to be used while production providers are under development.
enum FakeSpeedProvider {
    static func makeSpeed() -> AnyPublisher<Measurement<UnitSpeed>, Never> {
        let defaultSpeed = 20.0
        let unit: UnitSpeed = .milesPerHour
        let subject = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: defaultSpeed, unit: unit))
        
        // Create the timer and merge it into the publisher chain
        // The timer publisher will be retained as long as there are subscribers
        let timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { _ -> Measurement<UnitSpeed> in
                let currentValue = subject.value.value
                let bias = (defaultSpeed - currentValue) / defaultSpeed
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
