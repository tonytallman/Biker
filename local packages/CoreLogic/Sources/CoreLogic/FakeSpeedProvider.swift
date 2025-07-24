//
//  FakeSpeedProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine

/// Fake speed provider to be used while production providers are under development.
final class FakeSpeedProvider: SpeedMetricProvider {
    private var timerCancellable: AnyCancellable?
    private let defaultSpeed = 20.0
    private let unit: UnitSpeed = .milesPerHour
    private let subject: CurrentValueSubject<Speed, Never>

    let speed: AnyPublisher<Speed, Never>

    init() {
        subject = CurrentValueSubject<Speed, Never>(.init(value: defaultSpeed, unit: unit))
        speed = subject.eraseToAnyPublisher()

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let currentValue = self.subject.value.value
                let bias = (defaultSpeed - currentValue) / defaultSpeed
                let offset = Double.random(in: (-0.5 + bias) ... (0.5 + bias))
                let newValue = currentValue + offset
                self.subject.send(.init(value: newValue, unit: unit))
            }
    }

    deinit {
        timerCancellable?.cancel()
    }
}
