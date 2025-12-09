//
//  Preferences.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation
import Combine

class Preferences {
    // Private subjects to manage state internally
    private let speedUnitsSubject = CurrentValueSubject<UnitSpeed, Never>(.milesPerHour)
    private let distanceUnitsSubject = CurrentValueSubject<UnitLength, Never>(.miles)

    // Public read-only publishers
    var speedUnits: AnyPublisher<UnitSpeed, Never> { speedUnitsSubject.eraseToAnyPublisher() }
    var distanceUnits: AnyPublisher<UnitLength, Never> { distanceUnitsSubject.eraseToAnyPublisher() }

    // Setters to update values
    func setSpeedUnits(_ units: UnitSpeed) {
        speedUnitsSubject.send(units)
    }

    func setDistanceUnits(_ units: UnitLength) {
        distanceUnitsSubject.send(units)
    }

    // Convenience helpers for common unit systems
    func useMetricUnits() {
        speedUnitsSubject.send(.kilometersPerHour)
        distanceUnitsSubject.send(.kilometers)
    }

    func useImperialUnits() {
        speedUnitsSubject.send(.milesPerHour)
        distanceUnitsSubject.send(.miles)
    }
}
