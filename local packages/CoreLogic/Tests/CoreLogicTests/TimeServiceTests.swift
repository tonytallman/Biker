//
//  TimeServiceTests.swift
//  CoreLogicTests
//
//  Created by Tony Tallman on 2/5/25.
//

import Combine
import CombineSchedulers
import Foundation
import Testing

@testable import CoreLogic

// MARK: - Tests

@Suite("TimeService Tests")
struct TimeServiceTests {
    
    @Test("After elapsed time, last emitted value is accumulated period", arguments: [
        (period: 1.seconds, elapsed: 0.5.seconds, expected: 0.seconds),
        (period: 1.seconds, elapsed: 1.5.seconds, expected: 1.seconds),
        (period: 1.seconds, elapsed: 2.5.seconds, expected: 2.seconds),
        (period: 1.seconds, elapsed: 5.5.seconds, expected: 5.seconds),
        (period: 2.seconds, elapsed: 5.5.seconds, expected: 4.seconds),
        (period: 0.5.seconds, elapsed: 2.25.seconds, expected: 2.seconds),
    ])
    func testTimeAccumulation(
        period: Measurement<UnitDuration>,
        elapsed: Measurement<UnitDuration>,
        expected: Measurement<UnitDuration>
    ) {
        let scheduler = DispatchQueue.test
        let service = TimeService(period: period, scheduler: scheduler.eraseToAnyScheduler())
        
        var lastValue: Measurement<UnitDuration>?
        let cancellable = service.time.sink { lastValue = $0 }
        
        let elapsedNanoseconds = Int(elapsed.converted(to: .nanoseconds).value)
        scheduler.advance(by: .nanoseconds(elapsedNanoseconds))
        
        if expected.value == 0 {
            #expect(lastValue == nil)
        } else {
            let expectedSeconds = expected.converted(to: .seconds).value
            let actualSeconds = lastValue?.converted(to: .seconds).value ?? 0
            #expect(abs(actualSeconds - expectedSeconds) < 0.01)
        }
        
        _ = cancellable  // Retain
    }
}
