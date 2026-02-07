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

// MARK: - Tests

@Suite("Accumulating PublisherExtension Tests")
struct AccumulatedPublisherExtensionTests {
    
    // MARK: - Test Cases
    
    static let durationTestCases: [([Measurement<UnitDuration>], Measurement<UnitDuration>)] = [
        ([1.seconds, 1.seconds], 2.seconds),
        ([1.minutes, 1.seconds], 61.seconds),
        ([30.seconds, 1.minutes, 15.seconds], 105.seconds),
        ([1.hours, 30.minutes], 5400.seconds),
    ]
    
    static let lengthTestCases: [([Measurement<UnitLength>], Measurement<UnitLength>)] = [
        ([1.kilometers, 1.kilometers], 2000.meters),
        ([5.kilometers, 3.kilometers, 2000.meters], 10000.meters),
        ([1.miles, 2.kilometers], 3609.34.meters),
        ([1.meters, 2.meters, 3.meters, 4.meters, 5.meters], 15.meters),
    ]
    
    // MARK: - Tests
    
    @Test("Accumulates duration measurements", arguments: durationTestCases)
    func testDurationAccumulation(input: [Measurement<UnitDuration>], expected: Measurement<UnitDuration>) throws {
        try verifyAccumulation(input: input, expected: expected)
    }
    
    @Test("Accumulates length measurements", arguments: lengthTestCases)
    func testLengthAccumulation(input: [Measurement<UnitLength>], expected: Measurement<UnitLength>) throws {
        try verifyAccumulation(input: input, expected: expected)
    }
    
    @Test("Accumulating can be chained with inUnits")
    func testAccumulatingWithInUnits() throws {
        let deltas = CurrentValueSubject<Measurement<UnitLength>, Never>(1.kilometers)
        let units = CurrentValueSubject<UnitLength, Never>(.miles)
        
        let accumulatedInMiles = deltas.accumulating().inUnits(units)
        var values: [Measurement<UnitLength>] = []
        let subscription = accumulatedInMiles.sink { values.append($0) }
        
        // 1 km ≈ 0.621371 miles
        let first = try #require(values.last)
        #expect(first.unit == .miles)
        #expect(abs(first.value - 0.621371) <= 0.01)
        
        deltas.send(1.kilometers)
        // 2 km ≈ 1.242742 miles
        let second = try #require(values.last)
        #expect(second.unit == .miles)
        #expect(abs(second.value - 1.242742) <= 0.01)
        
        _ = subscription
    }
    
    @Test("Accumulating pauses when activity state is paused")
    func testAccumulatingPausesWhenPaused() throws {
        let deltas = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activityState = CurrentValueSubject<ActivityState, Never>(.active)
        
        let accumulated = deltas.accumulating(whileActive: activityState.eraseToAnyPublisher())
        var values: [Measurement<UnitLength>] = []
        let subscription = accumulated.sink { values.append($0) }
        
        // Send first delta while active - should accumulate
        deltas.send(1.meters)
        let first = try #require(values.last)
        #expect(first.value == 1.0)
        
        // Pause activity
        activityState.send(.paused)
        
        // Send delta while paused - should NOT accumulate
        deltas.send(2.meters)
        let second = try #require(values.last)
        // Should still be 1.0 (not 3.0)
        #expect(second.value == 1.0)
        
        // Resume activity
        activityState.send(.active)
        
        // Send delta while active again - should accumulate
        deltas.send(3.meters)
        let third = try #require(values.last)
        // Should be 4.0 (1 + 3, skipping the 2 that was sent while paused)
        #expect(third.value == 4.0)
        
        _ = subscription
    }
    
    @Test("Accumulating does not double-count on state changes")
    func testAccumulatingNoDoubleCount() throws {
        let deltas = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activityState = CurrentValueSubject<ActivityState, Never>(.active)
        
        let accumulated = deltas.accumulating(whileActive: activityState.eraseToAnyPublisher())
        var values: [Measurement<UnitLength>] = []
        let subscription = accumulated.sink { values.append($0) }
        
        // Send delta while active
        deltas.send(1.meters)
        let first = try #require(values.last)
        #expect(first.value == 1.0)
        
        // Change state to paused (should not cause accumulation)
        activityState.send(.paused)
        
        // Change state back to active (should not cause accumulation of old value)
        activityState.send(.active)
        
        // Send new delta - should accumulate correctly
        deltas.send(2.meters)
        let second = try #require(values.last)
        // Should be 3.0 (1 + 2), not 4.0 or higher
        #expect(second.value == 3.0)
        
        _ = subscription
    }
    
    // MARK: - Helper
    
    private func verifyAccumulation<UnitType: Dimension>(
        input: [Measurement<UnitType>],
        expected: Measurement<UnitType>
    ) throws {
        let deltas = PassthroughSubject<Measurement<UnitType>, Never>()
        let accumulated = deltas.accumulating()
        
        var lastValue: Measurement<UnitType>?
        let subscription = accumulated.sink { lastValue = $0 }
        
        for measurement in input {
            deltas.send(measurement)
        }
        
        let result = try #require(lastValue)
        let expectedInBaseUnit = expected.converted(to: UnitType.baseUnit())
        #expect(result.unit == UnitType.baseUnit())
        #expect(abs(result.value - expectedInBaseUnit.value) <= 0.1)
        
        _ = subscription
    }
}