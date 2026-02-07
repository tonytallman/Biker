//
//  SettingsModel.swift
//  SettingsModel
//
//  Created by Tony Tallman on 1/20/25.
//

import Combine
import Foundation

public class Settings {
    // Private subjects to manage state internally
    private let speedUnitsSubject = CurrentValueSubject<UnitSpeed, Never>(.milesPerHour)
    private let distanceUnitsSubject = CurrentValueSubject<UnitLength, Never>(.miles)
    private let autoPauseThresholdSubject = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))

    // Public read-only publishers
    public var speedUnits: AnyPublisher<UnitSpeed, Never> { speedUnitsSubject.eraseToAnyPublisher() }
    public var distanceUnits: AnyPublisher<UnitLength, Never> { distanceUnitsSubject.eraseToAnyPublisher() }
    public var autoPauseThreshold: AnyPublisher<Measurement<UnitSpeed>, Never> { autoPauseThresholdSubject.eraseToAnyPublisher() }

    public init() {}

    // Setters to update values
    public func setSpeedUnits(_ units: UnitSpeed) {
        speedUnitsSubject.send(units)
    }

    public func setDistanceUnits(_ units: UnitLength) {
        distanceUnitsSubject.send(units)
    }

    public func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>) {
        autoPauseThresholdSubject.send(threshold)
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
