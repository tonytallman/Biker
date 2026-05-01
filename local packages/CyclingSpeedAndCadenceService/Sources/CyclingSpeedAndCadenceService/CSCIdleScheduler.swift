//
//  CSCIdleScheduler.swift
//  CyclingSpeedAndCadenceService
//

import Combine
import Foundation

/// Schedules work after a delay; production uses main-queue `asyncAfter`, tests use a manual scheduler.
@MainActor
protocol CSCIdleScheduler {
    /// Returns a cancellable that invalidates the scheduled work before it runs.
    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) -> AnyCancellable
}

/// Default: `DispatchQueue.main.asyncAfter`.
@MainActor
struct DispatchQueueIdleScheduler: CSCIdleScheduler {
    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) -> AnyCancellable {
        let item = DispatchWorkItem {
            Task { @MainActor in
                work()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        return AnyCancellable {
            item.cancel()
        }
    }
}
