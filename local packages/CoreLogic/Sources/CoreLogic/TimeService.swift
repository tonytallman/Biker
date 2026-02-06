//
//  TimeService.swift
//  CoreLogic
//
//  Created by Tony Tallman on 2/5/25.
//

import Combine
import CombineSchedulers
import Foundation

/// Service that provides time pulse and accumulated time publishers.
public final class TimeService {
    /// The raw pulse publisher that emits time deltas
    public let timePulse: AnyPublisher<Measurement<UnitDuration>, Never>
    
    /// Accumulated time from the pulse publisher
    public let time: AnyPublisher<Measurement<UnitDuration>, Never>
    
    /// Public initializer using the main scheduler
    /// - Parameter period: The time interval between pulses
    public convenience init(period: Measurement<UnitDuration>) {
        self.init(period: period, scheduler: .main)
    }
    
    /// Package-scoped initializer for testing with custom scheduler
    /// - Parameters:
    ///   - period: The time interval between pulses
    ///   - scheduler: The scheduler to use for the timer
    package init(
        period: Measurement<UnitDuration>,
        scheduler: AnySchedulerOf<DispatchQueue>
    ) {
        let interval = DispatchQueue.SchedulerTimeType.Stride(
            .nanoseconds(Int(period.converted(to: .nanoseconds).value))
        )
        
        self.timePulse = Publishers.Timer(every: interval, scheduler: scheduler)
            .autoconnect()
            .map { _ in period }
            .share()
            .eraseToAnyPublisher()
        
        self.time = self.timePulse.accumulated()
    }
}
