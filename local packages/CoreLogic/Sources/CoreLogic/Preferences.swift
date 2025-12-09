//
//  Preferences.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation
import Combine

public class Preferences {
    // Private subjects to manage state internally
    private let speedUnitsSubject = CurrentValueSubject<UnitSpeed, Never>(.milesPerHour)
    private let distanceUnitsSubject = CurrentValueSubject<UnitLength, Never>(.miles)

    // Public read-only publishers
    public var speedUnits: AnyPublisher<UnitSpeed, Never> { speedUnitsSubject.eraseToAnyPublisher() }
    public var distanceUnits: AnyPublisher<UnitLength, Never> { distanceUnitsSubject.eraseToAnyPublisher() }

    public init() {}

    // Setters to update values
    public func setSpeedUnits(_ units: UnitSpeed) {
        speedUnitsSubject.send(units)
    }

    public func setDistanceUnits(_ units: UnitLength) {
        distanceUnitsSubject.send(units)
    }

    // Convenience helpers for common unit systems
    public func useMetricUnits() {
        speedUnitsSubject.send(.kilometersPerHour)
        distanceUnitsSubject.send(.kilometers)
    }

    public func useImperialUnits() {
        speedUnitsSubject.send(.milesPerHour)
        distanceUnitsSubject.send(.miles)
    }
}
