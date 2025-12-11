//
//  MeasurementPublisherExtensionTests.swift
//  CoreLogicTests
//
//  Created by Tony Tallman on 1/20/25.
//

import Testing
import Combine
import Foundation
@testable import CoreLogic

@Suite("MeasurementPublisherExtension Tests")
struct MeasurementPublisherExtensionTests {
    
    @Test("Converts UnitSpeed measurements correctly")
    func testSpeedConversion() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 20, unit: .milesPerHour)
        )
        let units = CurrentValueSubject<UnitSpeed, Never>(.kilometersPerHour)
        
        let speedInUnits = speed.inUnits(units)
        
        // Collect the first value using async sequence
        var iterator = speedInUnits.values.makeAsyncIterator()
        let convertedSpeed = try #require(await iterator.next())
        
        // 20 mph ≈ 32.1869 km/h
        #expect(convertedSpeed.unit == .kilometersPerHour)
        #expect(abs(convertedSpeed.value - 32.1869) <= 0.1)
    }
    
    @Test("Updates UnitSpeed measurements when units change")
    func testSpeedConversionUpdates() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 10, unit: .metersPerSecond)
        )
        let units = CurrentValueSubject<UnitSpeed, Never>(.kilometersPerHour)
        
        let speedInUnits = speed.inUnits(units)
        var iterator = speedInUnits.values.makeAsyncIterator()
        
        // Get initial conversion: 10 m/s = 36 km/h
        let firstValue = try #require(await iterator.next())
        #expect(firstValue.unit == .kilometersPerHour)
        #expect(abs(firstValue.value - 36.0) <= 0.1)
        
        // Change units to miles per hour: 10 m/s ≈ 22.3694 mph
        units.send(.milesPerHour)
        
        let secondValue = try #require(await iterator.next())
        #expect(secondValue.unit == .milesPerHour)
        #expect(abs(secondValue.value - 22.3694) <= 0.1)
    }
    
    @Test("Converts UnitLength measurements correctly")
    func testLengthConversion() async throws {
        let distance = CurrentValueSubject<Measurement<UnitLength>, Never>(
            Measurement(value: 10, unit: .miles)
        )
        let units = CurrentValueSubject<UnitLength, Never>(.kilometers)
        
        let distanceInUnits = distance.inUnits(units)
        var iterator = distanceInUnits.values.makeAsyncIterator()
        
        let convertedDistance = try #require(await iterator.next())
        
        // 10 miles ≈ 16.0934 km
        #expect(convertedDistance.unit == .kilometers)
        #expect(abs(convertedDistance.value - 16.0934) <= 0.01)
    }
    
    @Test("Updates UnitLength measurements when units change")
    func testLengthConversionUpdates() async throws {
        let distance = CurrentValueSubject<Measurement<UnitLength>, Never>(
            Measurement(value: 5, unit: .kilometers)
        )
        let units = CurrentValueSubject<UnitLength, Never>(.meters)
        
        let distanceInUnits = distance.inUnits(units)
        var iterator = distanceInUnits.values.makeAsyncIterator()
        
        // Get initial conversion: 5 km = 5000 m
        let firstValue = try #require(await iterator.next())
        #expect(firstValue.unit == .meters)
        #expect(abs(firstValue.value - 5000.0) <= 0.1)
        
        // Change units to miles: 5 km ≈ 3.10686 miles
        units.send(.miles)
        
        let secondValue = try #require(await iterator.next())
        #expect(secondValue.unit == .miles)
        #expect(abs(secondValue.value - 3.10686) <= 0.01)
    }
    
    @Test("Converts UnitFrequency measurements correctly")
    func testFrequencyConversion() async throws {
        let cadence = CurrentValueSubject<Measurement<UnitFrequency>, Never>(
            Measurement(value: 60, unit: .hertz)
        )
        let units = CurrentValueSubject<UnitFrequency, Never>(.revolutionsPerMinute)
        
        let cadenceInUnits = cadence.inUnits(units)
        var iterator = cadenceInUnits.values.makeAsyncIterator()
        
        let convertedCadence = try #require(await iterator.next())
        
        // 60 Hz = 3600 RPM (since 1 Hz = 60 RPM)
        #expect(convertedCadence.unit == .revolutionsPerMinute)
        #expect(abs(convertedCadence.value - 3600.0) <= 0.1)
    }
    
    @Test("Updates UnitFrequency measurements when units change")
    func testFrequencyConversionUpdates() async throws {
        let cadence = CurrentValueSubject<Measurement<UnitFrequency>, Never>(
            Measurement(value: 90, unit: .revolutionsPerMinute)
        )
        let units = CurrentValueSubject<UnitFrequency, Never>(.hertz)
        
        let cadenceInUnits = cadence.inUnits(units)
        var iterator = cadenceInUnits.values.makeAsyncIterator()
        
        // Get initial conversion: 90 RPM = 1.5 Hz
        let firstValue = try #require(await iterator.next())
        #expect(firstValue.unit == .hertz)
        #expect(abs(firstValue.value - 1.5) <= 0.01)
        
        // Change back to RPM
        units.send(.revolutionsPerMinute)
        
        let secondValue = try #require(await iterator.next())
        #expect(secondValue.unit == .revolutionsPerMinute)
        #expect(abs(secondValue.value - 90.0) <= 0.1)
    }
    
    @Test("Updates UnitSpeed when source measurement changes")
    func testSpeedMeasurementUpdate() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 10, unit: .kilometersPerHour)
        )
        let units = CurrentValueSubject<UnitSpeed, Never>(.milesPerHour)
        
        let speedInUnits = speed.inUnits(units)
        var iterator = speedInUnits.values.makeAsyncIterator()
        
        // Get initial conversion: 10 km/h ≈ 6.21371 mph
        let firstValue = try #require(await iterator.next())
        #expect(abs(firstValue.value - 6.21371) <= 0.01)
        
        // Change the source speed to 20 km/h ≈ 12.4274 mph
        speed.send(Measurement(value: 20, unit: .kilometersPerHour))
        
        let secondValue = try #require(await iterator.next())
        #expect(abs(secondValue.value - 12.4274) <= 0.01)
    }
    
    @Test("Updates UnitLength when source measurement changes")
    func testLengthMeasurementUpdate() async throws {
        let distance = CurrentValueSubject<Measurement<UnitLength>, Never>(
            Measurement(value: 5, unit: .kilometers)
        )
        let units = CurrentValueSubject<UnitLength, Never>(.miles)
        
        let distanceInUnits = distance.inUnits(units)
        var iterator = distanceInUnits.values.makeAsyncIterator()
        
        // Get initial conversion: 5 km ≈ 3.10686 miles
        let firstValue = try #require(await iterator.next())
        #expect(abs(firstValue.value - 3.10686) <= 0.01)
        
        // Change the source distance to 10 km ≈ 6.21371 miles
        distance.send(Measurement(value: 10, unit: .kilometers))
        
        let secondValue = try #require(await iterator.next())
        #expect(abs(secondValue.value - 6.21371) <= 0.01)
    }
    
    @Test("Updates UnitFrequency when source measurement changes")
    func testFrequencyMeasurementUpdate() async throws {
        let cadence = CurrentValueSubject<Measurement<UnitFrequency>, Never>(
            Measurement(value: 60, unit: .revolutionsPerMinute)
        )
        let units = CurrentValueSubject<UnitFrequency, Never>(.hertz)
        
        let cadenceInUnits = cadence.inUnits(units)
        var iterator = cadenceInUnits.values.makeAsyncIterator()
        
        // Get initial conversion: 60 RPM = 1.0 Hz
        let firstValue = try #require(await iterator.next())
        #expect(abs(firstValue.value - 1.0) <= 0.01)
        
        // Change the source cadence to 120 RPM = 2.0 Hz
        cadence.send(Measurement(value: 120, unit: .revolutionsPerMinute))
        
        let secondValue = try #require(await iterator.next())
        #expect(abs(secondValue.value - 2.0) <= 0.01)
    }
    
    @Test("Works with Just publisher for units")
    func testWithJustPublisher() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 50, unit: .kilometersPerHour)
        )
        let units = Just<UnitSpeed>(.milesPerHour)
        
        let speedInUnits = speed.inUnits(units)
        var iterator = speedInUnits.values.makeAsyncIterator()
        
        let convertedSpeed = try #require(await iterator.next())
        
        // 50 km/h ≈ 31.0686 mph
        #expect(convertedSpeed.unit == .milesPerHour)
        #expect(abs(convertedSpeed.value - 31.0686) <= 0.1)
    }
}
