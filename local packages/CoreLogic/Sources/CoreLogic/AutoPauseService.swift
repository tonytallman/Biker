//
//  AutoPauseService.swift
//  CoreLogic
//
//  Created by Tony Tallman on 2/6/25.
//

import Combine
import Foundation

/// Service that monitors speed against a threshold and publishes activity state.
/// When speed falls below the threshold, activity state becomes `.paused`.
/// When speed is at or above the threshold, activity state becomes `.active`.
public final class AutoPauseService {
    /// Publisher that emits the current activity state.
    public let activityState: AnyPublisher<ActivityState, Never>
    private var cancellable: AnyCancellable?

    /// Creates an auto-pause service that monitors speed against a threshold.
    /// - Parameters:
    ///   - speed: Publisher that emits current speed measurements.
    ///   - threshold: Publisher that emits the speed threshold below which activity should pause.
    public init(
        speed: some Publisher<Measurement<UnitSpeed>, Never>,
        threshold: some Publisher<Measurement<UnitSpeed>, Never>
    ) {
        let subject = CurrentValueSubject<ActivityState, Never>(.paused)
        self.activityState = subject.removeDuplicates().eraseToAnyPublisher()
        self.cancellable = Publishers.CombineLatest(speed, threshold)
            .map { speed, threshold in speed >= threshold ? .active : .paused }
            .removeDuplicates()
            .sink { subject.send($0) }
    }
}
