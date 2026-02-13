//
//  DimensionCodingTests.swift
//  SettingsModelTests
//
//  Created by Tony Tallman on 2/12/26.
//

import Foundation
import Testing

import SettingsModel

@Suite("SpeedUnitKey Tests")
struct SpeedUnitKeyTests {
    @Test("rawValue round-trip for milesPerHour")
    func rawValueMilesPerHour() {
        let key = SpeedUnitKey.milesPerHour
        #expect(key.rawValue == "milesPerHour")
        #expect(SpeedUnitKey(rawValue: "milesPerHour") == .milesPerHour)
        #expect(SpeedUnitKey(rawValue: "milesPerHour")?.unit == .milesPerHour)
    }

    @Test("rawValue round-trip for kilometersPerHour")
    func rawValueKilometersPerHour() {
        let key = SpeedUnitKey.kilometersPerHour
        #expect(key.rawValue == "kilometersPerHour")
        #expect(SpeedUnitKey(rawValue: "kilometersPerHour") == .kilometersPerHour)
        #expect(SpeedUnitKey(rawValue: "kilometersPerHour")?.unit == .kilometersPerHour)
    }

    @Test("init rawValue returns nil for unknown string")
    func invalidRawValue() {
        #expect(SpeedUnitKey(rawValue: "metersPerSecond") == nil)
        #expect(SpeedUnitKey(rawValue: "") == nil)
    }

    @Test("init unit returns key for milesPerHour and kilometersPerHour")
    func initFromUnit() {
        #expect(SpeedUnitKey(unit: .milesPerHour) == .milesPerHour)
        #expect(SpeedUnitKey(unit: .kilometersPerHour) == .kilometersPerHour)
    }

    @Test("init unit returns nil for unsupported UnitSpeed")
    func initFromUnsupportedSpeedUnit() {
        #expect(SpeedUnitKey(unit: .metersPerSecond) == nil)
    }

    @Test("unit property matches case")
    func unitProperty() {
        #expect(SpeedUnitKey.milesPerHour.unit == .milesPerHour)
        #expect(SpeedUnitKey.kilometersPerHour.unit == .kilometersPerHour)
    }
}

@Suite("DistanceUnitKey Tests")
struct DistanceUnitKeyTests {
    @Test("rawValue round-trip for miles")
    func rawValueMiles() {
        let key = DistanceUnitKey.miles
        #expect(key.rawValue == "miles")
        #expect(DistanceUnitKey(rawValue: "miles") == .miles)
        #expect(DistanceUnitKey(rawValue: "miles")?.unit == .miles)
    }

    @Test("rawValue round-trip for kilometers")
    func rawValueKilometers() {
        let key = DistanceUnitKey.kilometers
        #expect(key.rawValue == "kilometers")
        #expect(DistanceUnitKey(rawValue: "kilometers") == .kilometers)
        #expect(DistanceUnitKey(rawValue: "kilometers")?.unit == .kilometers)
    }

    @Test("init rawValue returns nil for unknown string")
    func invalidRawValue() {
        #expect(DistanceUnitKey(rawValue: "meters") == nil)
        #expect(DistanceUnitKey(rawValue: "") == nil)
    }

    @Test("init unit returns key for miles and kilometers")
    func initFromUnit() {
        #expect(DistanceUnitKey(unit: .miles) == .miles)
        #expect(DistanceUnitKey(unit: .kilometers) == .kilometers)
    }

    @Test("init unit returns nil for unsupported UnitLength")
    func initFromUnsupportedLengthUnit() {
        #expect(DistanceUnitKey(unit: .meters) == nil)
    }

    @Test("unit property matches case")
    func unitProperty() {
        #expect(DistanceUnitKey.miles.unit == .miles)
        #expect(DistanceUnitKey.kilometers.unit == .kilometers)
    }
}
