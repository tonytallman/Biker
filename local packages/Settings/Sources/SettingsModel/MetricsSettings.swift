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
