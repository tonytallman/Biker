//
//  MetricsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import Combine
import Foundation

public protocol MetricsSettings {
    var speedUnits: any Subject<UnitSpeed, Never> { get }
    var distanceUnits: any Subject<UnitLength, Never> { get }
    var autoPauseThreshold: any Subject<Measurement<UnitSpeed>, Never> { get }
}

public class DefaultMetricsSettings: MetricsSettings {
    private let storage: SettingsStorage
    private var cancellables: Set<AnyCancellable> = []

    private static let speedUnitsKey = "speedUnits"
    private static let distanceUnitsKey = "distanceUnits"
    private static let autoPauseThresholdBaseValueKey = "autoPauseThresholdBaseValue"
    private static let autoPauseThresholdUnitKey = "autoPauseThresholdUnit"

    private let speedUnitsSubject: CurrentValueSubject<UnitSpeed, Never>
    private let distanceUnitsSubject: CurrentValueSubject<UnitLength, Never>
    private let autoPauseThresholdSubject: CurrentValueSubject<Measurement<UnitSpeed>, Never>
    private let keepScreenOnSubject = CurrentValueSubject<Bool, Never>(true)

    // Public read-only publishers
    public var speedUnits: any Subject<UnitSpeed, Never> { speedUnitsSubject }
    public var distanceUnits: any Subject<UnitLength, Never> { distanceUnitsSubject }
    public var autoPauseThreshold: any Subject<Measurement<UnitSpeed>, Never> { autoPauseThresholdSubject }
    public var keepScreenOn: any Subject<Bool, Never> { keepScreenOnSubject }

    public init(storage: SettingsStorage) {
        self.storage = storage

        let speedUnits: UnitSpeed = (storage.get(forKey: Self.speedUnitsKey) as? String)
            .flatMap(SpeedUnitKey.init(rawValue:))?.unit ?? .milesPerHour
        let distanceUnits: UnitLength = (storage.get(forKey: Self.distanceUnitsKey) as? String)
            .flatMap(DistanceUnitKey.init(rawValue:))?.unit ?? .miles
        let autoPauseThreshold: Measurement<UnitSpeed> = Self.restoreAutoPauseThreshold(storage: storage)

        self.speedUnitsSubject = CurrentValueSubject<UnitSpeed, Never>(speedUnits)
        self.distanceUnitsSubject = CurrentValueSubject<UnitLength, Never>(distanceUnits)
        self.autoPauseThresholdSubject = CurrentValueSubject<Measurement<UnitSpeed>, Never>(autoPauseThreshold)

        speedUnitsSubject.dropFirst().sink { [storage] units in
            storage.set(value: SpeedUnitKey(unit: units)?.rawValue, forKey: Self.speedUnitsKey)
        }.store(in: &cancellables)

        distanceUnitsSubject.dropFirst().sink { [storage] units in
            storage.set(value: DistanceUnitKey(unit: units)?.rawValue, forKey: Self.distanceUnitsKey)
        }.store(in: &cancellables)

        autoPauseThresholdSubject.dropFirst().sink { [storage] measurement in
            let baseValue = measurement.converted(to: .metersPerSecond).value
            storage.set(value: baseValue, forKey: Self.autoPauseThresholdBaseValueKey)
            storage.set(value: SpeedUnitKey(unit: measurement.unit)?.rawValue, forKey: Self.autoPauseThresholdUnitKey)
        }.store(in: &cancellables)
    }

    private static func restoreAutoPauseThreshold(storage: SettingsStorage) -> Measurement<UnitSpeed> {
        guard let baseValue = storage.get(forKey: autoPauseThresholdBaseValueKey) as? Double,
              let unitKey = storage.get(forKey: autoPauseThresholdUnitKey) as? String,
              let speedUnitKey = SpeedUnitKey(rawValue: unitKey) else {
            return .init(value: 3, unit: .milesPerHour)
        }
        let baseMeasurement = Measurement<UnitSpeed>(value: baseValue, unit: .metersPerSecond)
        return baseMeasurement.converted(to: speedUnitKey.unit)
    }

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

    public func setKeepScreenOn(_ keepOn: Bool) {
        keepScreenOnSubject.send(keepOn)
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
