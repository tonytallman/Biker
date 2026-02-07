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
    func testActiveWhenSpeedAboveThreshold() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 5, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        // Speed 5 > threshold 3, should be active
        let state = try #require(values.last)
        #expect(state == .active)
        
        _ = subscription
    }
    
    @Test("Emits active when speed equals threshold")
    func testActiveWhenSpeedEqualsThreshold() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        // Speed 3 == threshold 3, should be active
        let state = try #require(values.last)
        #expect(state == .active)
        
        _ = subscription
    }
    
    @Test("Emits paused when speed is below threshold")
    func testPausedWhenSpeedBelowThreshold() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 2, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        let state = try #require(values.last)
        #expect(state == .paused)
        
        _ = subscription
    }
    
    @Test("Transitions from active to paused when speed drops")
    func testTransitionActiveToPaused() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 5, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        // Initial state should be .active (speed 5 > threshold 3)
        let initial = try #require(values.last)
        #expect(initial == .active)
        
        // Drop speed below threshold
        speed.send(.init(value: 2, unit: .milesPerHour))
        let updated = try #require(values.last)
        #expect(updated == .paused)
        
        _ = subscription
    }
    
    @Test("Transitions from paused to active when speed rises")
    func testTransitionPausedToActive() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 2, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        let first = try #require(values.last)
        #expect(first == .paused)
        
        // Raise speed above threshold
        speed.send(.init(value: 5, unit: .milesPerHour))
        let second = try #require(values.last)
        #expect(second == .active)
        
        _ = subscription
    }
    
    @Test("Handles threshold changes correctly")
    func testThresholdChanges() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 4, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        // Initial state should be .active (speed 4 > threshold 3)
        let initial = try #require(values.last)
        #expect(initial == .active)
        
        // Raise threshold above current speed
        threshold.send(.init(value: 5, unit: .milesPerHour))
        let second = try #require(values.last)
        #expect(second == .paused)
        
        // Lower threshold below current speed
        threshold.send(.init(value: 2, unit: .milesPerHour))
        let third = try #require(values.last)
        #expect(third == .active)
        
        _ = subscription
    }
    
    @Test("Works with different speed units")
    func testDifferentSpeedUnits() throws {
        // Speed in km/h, threshold in mph
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 10, unit: .kilometersPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        // 10 km/h ≈ 6.2 mph, which is > 3 mph, should be active
        let state = try #require(values.last)
        #expect(state == .active)
        
        _ = subscription
    }
    
    @Test("Does not emit duplicate states")
    func testNoDuplicateStates() throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 5, unit: .milesPerHour))
        let threshold = CurrentValueSubject<Measurement<UnitSpeed>, Never>(.init(value: 3, unit: .milesPerHour))
        
        let service = AutoPauseService(
            speed: speed.eraseToAnyPublisher(),
            threshold: threshold.eraseToAnyPublisher()
        )
        
        var values: [ActivityState] = []
        let subscription = service.activityState.sink { values.append($0) }
        
        // Should have received initial state (.active since speed 5 > threshold 3)
        let initialCount = values.count
        
        // Send same speed value multiple times (should not change state)
        speed.send(.init(value: 5, unit: .milesPerHour))
        speed.send(.init(value: 5, unit: .milesPerHour))
        speed.send(.init(value: 5, unit: .milesPerHour))
        
        // removeDuplicates() should prevent any additional emissions
        #expect(values.count == initialCount)
        
        _ = subscription
    }
}
