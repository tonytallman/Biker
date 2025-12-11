//
//  FakeCadenceProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine
import CoreLogic

/// Fake cadence provider to be used while production providers are under development.
final class FakeCadenceProvider: CadenceMetricProvider {
    private var timerCancellable: AnyCancellable?
    private let defaultCadence = 90.0
    private let unit: UnitFrequency = .revolutionsPerMinute
    private let subject: CurrentValueSubject<Cadence, Never>

    let cadence: AnyPublisher<Cadence, Never>

    init() {
        subject = CurrentValueSubject<Cadence, Never>(.init(value: defaultCadence, unit: unit))
        cadence = subject.eraseToAnyPublisher()

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let currentValue = self.subject.value.value
                let bias = (defaultCadence - currentValue) / defaultCadence
                let offset = Double.random(in: (-1 + bias) ... (1 + bias))
                let newValue = currentValue + offset
                self.subject.send(.init(value: newValue, unit: unit))
            }
    }

    deinit {
        timerCancellable?.cancel()
    }
}
