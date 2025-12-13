//
//  FakeCadenceProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation

import CoreLogic

/// Fake cadence provider to be used while production providers are under development.
enum FakeCadenceProvider {
    static func makeCadence() -> AnyPublisher<Measurement<UnitFrequency>, Never> {
        let defaultCadence = 90.0
        let unit: UnitFrequency = .revolutionsPerMinute
        let subject = CurrentValueSubject<Measurement<UnitFrequency>, Never>(.init(value: defaultCadence, unit: unit))
        
        // Create the timer and merge it into the publisher chain
        // The timer publisher will be retained as long as there are subscribers
        let timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { _ -> Measurement<UnitFrequency> in
                let currentValue = subject.value.value
                let bias = (defaultCadence - currentValue) / defaultCadence
                let offset = Double.random(in: (-1 + bias) ... (1 + bias))
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
