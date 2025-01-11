//
//  FakeSpeedProvider.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/10/25.
//

import Foundation
import Combine

class FakeSpeedProvider: SpeedMetricProvider {
    let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(Measurement<UnitSpeed>(value: 20.0, unit: .milesPerHour))
        .eraseToAnyPublisher()
}