//
//  Preferences.swift
//  BikerCore
//
//  Created by Tony Tallman on 1/20/25.
//

import Foundation
import Combine

class Preferences {
    let speedUnits = CurrentValueSubject<UnitSpeed, Never>(UnitSpeed.milesPerHour)
    let distanceUnits = CurrentValueSubject<UnitLength, Never>(UnitLength.miles)

    func useMetricUnits() {
        speedUnits.send(.kilometersPerHour)
        distanceUnits.send(.kilometers)
    }

    func useImperialUnits() {
        speedUnits.send(.milesPerHour)
        distanceUnits.send(.miles)
    }
}
