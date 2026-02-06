//
//  MeasurementTestHelpers.swift
//  CoreLogicTests
//
//  Created by Tony Tallman on 2/5/25.
//

import Foundation

// MARK: - Measurement Convenience Extensions

extension Int {
    var seconds: Measurement<UnitDuration> { Measurement(value: Double(self), unit: .seconds) }
    var minutes: Measurement<UnitDuration> { Measurement(value: Double(self), unit: .minutes) }
    var hours: Measurement<UnitDuration> { Measurement(value: Double(self), unit: .hours) }
    
    var meters: Measurement<UnitLength> { Measurement(value: Double(self), unit: .meters) }
    var kilometers: Measurement<UnitLength> { Measurement(value: Double(self), unit: .kilometers) }
    var miles: Measurement<UnitLength> { Measurement(value: Double(self), unit: .miles) }
}

extension Double {
    var seconds: Measurement<UnitDuration> { Measurement(value: self, unit: .seconds) }
    var minutes: Measurement<UnitDuration> { Measurement(value: self, unit: .minutes) }
    var hours: Measurement<UnitDuration> { Measurement(value: self, unit: .hours) }
    
    var meters: Measurement<UnitLength> { Measurement(value: self, unit: .meters) }
    var kilometers: Measurement<UnitLength> { Measurement(value: self, unit: .kilometers) }
    var miles: Measurement<UnitLength> { Measurement(value: self, unit: .miles) }
}
