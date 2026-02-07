//
//  FakeMetricsProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Combine
import Foundation

import CoreLogic

/// Fake metrics provider to be used while production providers are under development.
/// Generates random cadence and derives speed and distance delta from it.
struct FakeMetrics {
    var speed: AnyPublisher<Measurement<UnitSpeed>, Never>
    var cadence: AnyPublisher<Measurement<UnitFrequency>, Never>
    var distanceDelta: AnyPublisher<Measurement<UnitLength>, Never>
}

enum FakeMetricsProvider {
    /// Creates fake metrics with cadence as the single source of truth.
    /// Speed and distance delta are derived from the cadence stream.
    static func make() -> FakeMetrics {
        // Single source of truth: cadence stream
        // Same algorithm as the original FakeCadenceProvider
        let defaultCadence = 90.0
        let unit: UnitFrequency = .revolutionsPerMinute
        let subject = CurrentValueSubject<Measurement<UnitFrequency>, Never>(.init(value: defaultCadence, unit: unit))
        
        // Create the timer and merge it into the publisher chain
        // The timer publisher will be retained as long as there are subscribers
        let cadencePublisher = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { _ -> Measurement<UnitFrequency> in
                let currentValue = subject.value.value
                let bias = (defaultCadence - currentValue) / defaultCadence
                let offset = Double.random(in: (-1 + bias) ... (1 + bias))
                let newValue = currentValue + offset
                return Measurement(value: newValue, unit: unit)
            }
            .handleEvents(receiveOutput: { value in
                subject.send(value)
            })
            .share()
            .eraseToAnyPublisher()
        
        // Merge the initial value with the timer updates
        let cadence = Publishers.Merge(
            subject.prefix(1),
            cadencePublisher
        )
        .share()
        .eraseToAnyPublisher()
        
        // Derive speed from cadence
        // Formula: speed_mps = cadence_rpm * (meters_per_revolution / 60)
        // Using 5.96 meters per revolution so that 90 rpm ≈ 20 mph (8.94 m/s)
        let metersPerRevolution = 5.96
        let speed = cadence
            .map { cadenceMeasurement -> Measurement<UnitSpeed> in
                let cadenceRpm = cadenceMeasurement.value
                let speedMps = cadenceRpm * (metersPerRevolution / 60.0)
                return Measurement(value: speedMps, unit: .metersPerSecond)
            }
            .share()
            .eraseToAnyPublisher()
        
        // Derive distance delta from speed
        // Each tick is 1 second, so distance delta (m) = speed (m/s)
        let distanceDelta = speed
            .map { speedMeasurement -> Measurement<UnitLength> in
                let speedMps = speedMeasurement.value
                return Measurement(value: speedMps, unit: .meters)
            }
            .share()
            .eraseToAnyPublisher()
        
        return FakeMetrics(
            speed: speed,
            cadence: cadence,
            distanceDelta: distanceDelta
        )
    }
}
