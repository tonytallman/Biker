//
//  DimensionCoding.swift
//  Settings
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation

public enum SpeedUnitKey: String, CaseIterable {
    case milesPerHour
    case kilometersPerHour

    public var unit: UnitSpeed {
        switch self {
        case .milesPerHour: return .milesPerHour
        case .kilometersPerHour: return .kilometersPerHour
        }
    }

    public init?(unit: UnitSpeed) {
        if unit == .milesPerHour {
            self = .milesPerHour
        } else if unit == .kilometersPerHour {
            self = .kilometersPerHour
        } else {
            return nil
        }
    }
}

public enum DistanceUnitKey: String, CaseIterable {
    case miles
    case kilometers

    public var unit: UnitLength {
        switch self {
        case .miles: return .miles
        case .kilometers: return .kilometers
        }
    }

    public init?(unit: UnitLength) {
        if unit == .miles {
            self = .miles
        } else if unit == .kilometers {
            self = .kilometers
        } else {
            return nil
        }
    }
}
