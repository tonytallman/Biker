//
//  MetricsSettings.swift
//  Settings
//
//  Created by Tony Tallman on 2/11/26.
//

import Combine
import Foundation

public protocol MetricsSettings {
    var speedUnits: AnyPublisher<UnitSpeed, Never> { get }
    var distanceUnits: AnyPublisher<UnitLength, Never> { get }
    var autoPauseThreshold: AnyPublisher<Measurement<UnitSpeed>, Never> { get }
    func setSpeedUnits(_ units: UnitSpeed)
    func setDistanceUnits(_ units: UnitLength)
    func setAutoPauseThreshold(_ threshold: Measurement<UnitSpeed>)
}
