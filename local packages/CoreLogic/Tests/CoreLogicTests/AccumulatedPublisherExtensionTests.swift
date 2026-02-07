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
    
    @Test("Accumulating can be chained with inUnits")
    func testAccumulatingWithInUnits() async throws {
        let deltas = CurrentValueSubject<Measurement<UnitLength>, Never>(1.kilometers)
        let units = CurrentValueSubject<UnitLength, Never>(.miles)
        
        let accumulatedInMiles = deltas.accumulating().inUnits(units)
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
    
    @Test("Accumulating pauses when activity state is paused")
    func testAccumulatingPausesWhenPaused() async throws {
        let deltas = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activityState = CurrentValueSubject<ActivityState, Never>(.active)
        
        let accumulated = deltas.accumulating(whileActive: activityState.eraseToAnyPublisher())
        var iterator = accumulated.values.makeAsyncIterator()
        
        // Send first delta while active - should accumulate
        let task1 = Task { await iterator.next() }
        deltas.send(1.meters)
        let first = try #require(await task1.value)
        #expect(first.value == 1.0)
        
        // Pause activity
        activityState.send(.paused)
        
        // Send delta while paused - should NOT accumulate
        let task2 = Task { await iterator.next() }
        deltas.send(2.meters)
        let second = try #require(await task2.value)
        // Should still be 1.0 (not 3.0)
        #expect(second.value == 1.0)
        
        // Resume activity
        activityState.send(.active)
        
        // Send delta while active again - should accumulate
        let task3 = Task { await iterator.next() }
        deltas.send(3.meters)
        let third = try #require(await task3.value)
        // Should be 4.0 (1 + 3, skipping the 2 that was sent while paused)
        #expect(third.value == 4.0)
    }
    
    @Test("Accumulating does not double-count on state changes")
    func testAccumulatingNoDoubleCount() async throws {
        let deltas = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activityState = CurrentValueSubject<ActivityState, Never>(.active)
        
        let accumulated = deltas.accumulating(whileActive: activityState.eraseToAnyPublisher())
        var iterator = accumulated.values.makeAsyncIterator()
        
        // Send delta while active
        let task1 = Task { await iterator.next() }
        deltas.send(1.meters)
        let first = try #require(await task1.value)
        #expect(first.value == 1.0)
        
        // Change state to paused (should not cause accumulation)
        activityState.send(.paused)
        // Wait a bit to ensure no extra emissions
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Change state back to active (should not cause accumulation of old value)
        activityState.send(.active)
        // Wait a bit to ensure no extra emissions
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Send new delta - should accumulate correctly
        let task2 = Task { await iterator.next() }
        deltas.send(2.meters)
        let second = try #require(await task2.value)
        // Should be 3.0 (1 + 2), not 4.0 or higher
        #expect(second.value == 3.0)
    }
    
    // MARK: - Helper
    
    private func verifyAccumulation<UnitType: Dimension>(
        input: [Measurement<UnitType>],
        expected: Measurement<UnitType>
    ) async throws {
        let deltas = PassthroughSubject<Measurement<UnitType>, Never>()
        let accumulated = deltas.accumulating()
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
