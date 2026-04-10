//
//  MetricContext.swift
//  CoreLogic
//

import Combine
import Foundation

/// Shared scope for metrics that respond to ride activity (e.g. auto-pause).
/// Multiple contexts can coexist (e.g. current ride vs. all-time totals); each metric is created with the context it should use.
public final class MetricContext {
    /// When ``ActivityState/paused``, statistic metrics hold their value and ignore new source samples.
    public let activityState: AnyPublisher<ActivityState, Never>

    /// Creates a context driven by the given auto-pause service.
    public init(autoPauseService: AutoPauseService) {
        self.activityState = autoPauseService.activityState
    }

    /// Creates a context with an explicit activity stream (e.g. for tests or custom orchestration).
    public init(activityState: some Publisher<ActivityState, Never>) {
        self.activityState = activityState.eraseToAnyPublisher()
    }
}
