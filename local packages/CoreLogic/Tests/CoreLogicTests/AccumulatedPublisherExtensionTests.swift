//
//  AccumulatedPublisherExtensionTests.swift
//  CoreLogicTests
//
//  Created by Tony Tallman on 1/20/25.
//

import Combine
import Foundation
import Testing

@testable import CoreLogic

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

// MARK: - Tests

@Suite("Accumulated PublisherExtension Tests")
struct AccumulatedPublisherExtensionTests {
    
    @Test("Accumulates duration measurements", arguments: [
        ([1.seconds, 1.seconds], 2.seconds),
        ([1.minutes, 1.seconds], 61.seconds),
        ([30.seconds, 1.minutes, 15.seconds], 105.seconds),
        ([1.hours, 30.minutes], 5400.seconds),
    ])
    func testDurationAccumulation(input: [Measurement<UnitDuration>], expected: Measurement<UnitDuration>) async throws {
        try await verifyAccumulation(input: input, expected: expected)
    }
    
    @Test("Accumulates length measurements", arguments: [
        ([1.kilometers, 1.kilometers], 2000.meters),
        ([5.kilometers, 3.kilometers, 2000.meters], 10000.meters),
        ([1.miles, 2.kilometers], 3609.34.meters),
        ([1.meters, 2.meters, 3.meters, 4.meters, 5.meters], 15.meters),
    ])
    func testLengthAccumulation(input: [Measurement<UnitLength>], expected: Measurement<UnitLength>) async throws {
        try await verifyAccumulation(input: input, expected: expected)
    }
    
    @Test("Accumulated can be chained with inUnits")
    func testAccumulatedWithInUnits() async throws {
        let deltas = CurrentValueSubject<Measurement<UnitLength>, Never>(1.kilometers)
        let units = CurrentValueSubject<UnitLength, Never>(.miles)
        
        let accumulatedInMiles = deltas.accumulated().inUnits(units)
        var iterator = accumulatedInMiles.values.makeAsyncIterator()
        
        let first = try #require(await iterator.next())
        // 1 km ≈ 0.621371 miles
        #expect(first.unit == .miles)
        #expect(abs(first.value - 0.621371) <= 0.01)
        
        deltas.send(1.kilometers)
        let second = try #require(await iterator.next())
        // 2 km ≈ 1.242742 miles
        #expect(second.unit == .miles)
        #expect(abs(second.value - 1.242742) <= 0.01)
    }
    
    // MARK: - Helper
    
    private func verifyAccumulation<UnitType: Dimension>(
        input: [Measurement<UnitType>],
        expected: Measurement<UnitType>
    ) async throws {
        let deltas = PassthroughSubject<Measurement<UnitType>, Never>()
        let accumulated = deltas.accumulated()
        var iterator = accumulated.values.makeAsyncIterator()
        
        var lastValue: Measurement<UnitType>?
        for measurement in input {
            let task = Task { await iterator.next() }
            deltas.send(measurement)
            lastValue = await task.value
        }
        
        let result = try #require(lastValue)
        let expectedInBaseUnit = expected.converted(to: UnitType.baseUnit())
        #expect(result.unit == UnitType.baseUnit())
        #expect(abs(result.value - expectedInBaseUnit.value) <= 0.1)
    }
}
