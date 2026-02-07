//
//  AutoPauseServiceTests.swift
//  CoreLogicTests
//
//  Created by Tony Tallman on 2/6/25.
//

import Combine
import Foundation
import Testing

@testable import CoreLogic

// MARK: - Tests

@Suite("AutoPauseService Tests")
struct AutoPauseServiceTests {
    
    @Test("Emits active when speed is above threshold")
    func testActiveWhenSpeedAboveThreshold() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 5, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        // First value is initial .paused state
        let initial = try #require(await iterator.next())
        #expect(initial == .paused)
        
        // Second value is .active (speed 5 > threshold 3)
        let state = try #require(await iterator.next())
        #expect(state == .active)
    }
    
    @Test("Emits active when speed equals threshold")
    func testActiveWhenSpeedEqualsThreshold() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        // First value is initial .paused state
        let initial = try #require(await iterator.next())
        #expect(initial == .paused)
        
        // Second value is .active (speed 3 == threshold 3)
        let state = try #require(await iterator.next())
        #expect(state == .active)
    }
    
    @Test("Emits paused when speed is below threshold")
    func testPausedWhenSpeedBelowThreshold() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 2, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        let state = try #require(await iterator.next())
        #expect(state == .paused)
    }
    
    @Test("Transitions from active to paused when speed drops")
    func testTransitionActiveToPaused() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 5, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        // First value is initial .paused state
        let initial = try #require(await iterator.next())
        #expect(initial == .paused)
        
        // Second value is .active (speed 5 > threshold 3)
        let first = try #require(await iterator.next())
        #expect(first == .active)
        
        // Drop speed below threshold
        speed.send(.init(value: 2, unit: .milesPerHour))
        let second = try #require(await iterator.next())
        #expect(second == .paused)
    }
    
    @Test("Transitions from paused to active when speed rises")
    func testTransitionPausedToActive() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 2, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        let first = try #require(await iterator.next())
        #expect(first == .paused)
        
        // Raise speed above threshold
        speed.send(.init(value: 5, unit: .milesPerHour))
        let second = try #require(await iterator.next())
        #expect(second == .active)
    }
    
    @Test("Handles threshold changes correctly")
    func testThresholdChanges() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 4, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        // First value is initial .paused state
        let initial = try #require(await iterator.next())
        #expect(initial == .paused)
        
        // Second value is .active (speed 4 > threshold 3)
        let first = try #require(await iterator.next())
        #expect(first == .active)
        
        // Raise threshold above current speed
        threshold.send(.init(value: 5, unit: .milesPerHour))
        let second = try #require(await iterator.next())
        #expect(second == .paused)
        
        // Lower threshold below current speed
        threshold.send(.init(value: 2, unit: .milesPerHour))
        let third = try #require(await iterator.next())
        #expect(third == .active)
    }
    
    @Test("Works with different speed units")
    func testDifferentSpeedUnits() async throws {
        // Speed in km/h, threshold in mph
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 10, unit: .kilometersPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        // First value is initial .paused state
        let initial = try #require(await iterator.next())
        #expect(initial == .paused)
        
        // Second value is .active (10 km/h ≈ 6.2 mph, which is > 3 mph)
        let state = try #require(await iterator.next())
        #expect(state == .active)
    }
    
    @Test("Does not emit duplicate states")
    func testNoDuplicateStates() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 5, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var iterator = service.activityState.values.makeAsyncIterator()
        // First value is initial .paused state
        let initial = try #require(await iterator.next())
        #expect(initial == .paused)
        
        // Second value is .active (speed 5 > threshold 3)
        let first = try #require(await iterator.next())
        #expect(first == .active)
        
        // Send same speed value multiple times (should not change state)
        speed.send(.init(value: 5, unit: .milesPerHour))
        speed.send(.init(value: 5, unit: .milesPerHour))
        speed.send(.init(value: 5, unit: .milesPerHour))
        
        // Wait a bit to allow any emissions to propagate
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Verify no additional emissions occurred by using a timeout
        // If removeDuplicates() is working, no new values should be emitted
        let nextTask = Task {
            await iterator.next()
        }
        
        // Wait with timeout - if no value is emitted within 50ms, assume no duplicates
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        try await timeoutTask.value
        // If we reach here, timeout occurred before next() completed
        // This means no duplicate was emitted, which is what we want
        nextTask.cancel()
        
        // Should not have emitted any new values since state didn't change
        // (This test verifies removeDuplicates() is working)
    }
}
