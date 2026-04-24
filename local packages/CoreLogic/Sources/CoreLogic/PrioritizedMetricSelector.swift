//
//  PrioritizedMetricSelector.swift
//  CoreLogic
//

import Combine
import CombineSchedulers
import Foundation

/// Picks the highest-priority ``AnyMetric`` that is currently available; falls back when that source stalls or disconnects.
///
/// When initialized with a ``tick`` publisher (e.g. ``TimeService/timePulse`` mapped to `Void`), the selector re-emits the
/// latest measurement for the active source on each tick while that source is available and has produced at least one value.
/// This satisfies **MET-GEN-3** (≥1 Hz while a source is active). Values are replayed verbatim; a future staleness timeout is out of scope here.
public final class PrioritizedMetricSelector<U: Dimension>: Metric, @unchecked Sendable {
    public typealias UnitType = U

    public let publisher: AnyPublisher<Measurement<U>, Never>
    public let isAvailable: AnyPublisher<Bool, Never>
    /// Index into the source array passed to ``init(sources:)``, or `nil` when no source is available.
    public let activeSourceIndex: AnyPublisher<Int?, Never>

    private let state: SelectorState<U>?
    private var cancellables = Set<AnyCancellable>()

    /// - Parameters:
    ///   - sources: Highest priority first.
    ///   - scheduler: Queue used for child metric streams and tick delivery (default main queue for UI).
    public init(sources: [AnyMetric<U>], scheduler: AnySchedulerOf<DispatchQueue> = .main) {
        guard !sources.isEmpty else {
            state = nil
            publisher = Empty<Measurement<U>, Never>().eraseToAnyPublisher()
            isAvailable = Just(false).eraseToAnyPublisher()
            activeSourceIndex = Just(nil).eraseToAnyPublisher()
            return
        }

        let st = SelectorState<U>(sourceCount: sources.count)
        state = st
        publisher = st.output.eraseToAnyPublisher()
        isAvailable = st.anySourceAvailable.removeDuplicates().eraseToAnyPublisher()
        activeSourceIndex = st.activeIndex.removeDuplicates().eraseToAnyPublisher()

        wireChildSources(st, sources: sources, scheduler: scheduler)
    }

    /// - Parameters:
    ///   - sources: Highest priority first.
    ///   - tick: Pulse used to re-emit the active source’s latest value (**MET-GEN-3**).
    ///   - scheduler: Queue used for child metric streams and tick delivery (default main queue for UI).
    public init(
        sources: [AnyMetric<U>],
        tick: AnyPublisher<Void, Never>,
        scheduler: AnySchedulerOf<DispatchQueue> = .main
    ) {
        guard !sources.isEmpty else {
            state = nil
            publisher = Empty<Measurement<U>, Never>().eraseToAnyPublisher()
            isAvailable = Just(false).eraseToAnyPublisher()
            activeSourceIndex = Just(nil).eraseToAnyPublisher()
            return
        }

        let st = SelectorState<U>(sourceCount: sources.count)
        state = st
        publisher = st.output.eraseToAnyPublisher()
        isAvailable = st.anySourceAvailable.removeDuplicates().eraseToAnyPublisher()
        activeSourceIndex = st.activeIndex.removeDuplicates().eraseToAnyPublisher()

        wireChildSources(st, sources: sources, scheduler: scheduler)

        // Ticks are not routed through `scheduler`: they only read/write `SelectorState` under `NSLock`
        // and must not reorder ahead of initial `receive(on:)` deliveries from child metrics (which would
        // emit before the dashboard `sink` attaches and drop samples on this `PassthroughSubject`).
        tick
            .sink { [st] in
                st.receiveTick()
            }
            .store(in: &cancellables)
    }

    /// Subscriptions live on ``PrioritizedMetricSelector`` (not ``SelectorState``) so sinks can retain
    /// ``SelectorState`` strongly without a retain cycle (`SelectorState` no longer owns the cancellables bag).
    private func wireChildSources(
        _ st: SelectorState<U>,
        sources: [AnyMetric<U>],
        scheduler: AnySchedulerOf<DispatchQueue>
    ) {
        for (index, source) in sources.enumerated() {
            source.publisher
                .receive(on: scheduler)
                .sink { [st] measurement in
                    st.receiveMeasurement(index: index, value: measurement)
                }
                .store(in: &cancellables)

            source.isAvailable
                .receive(on: scheduler)
                .sink { [st] available in
                    st.receiveAvailability(index: index, available: available)
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - Mutable wiring (retained by `PrioritizedMetricSelector.state`)

private final class SelectorState<U: Dimension>: @unchecked Sendable {
    private let lock = NSLock()

    private var latestValues: [Measurement<U>?]
    private var availabilities: [Bool]
    private var currentActiveIndex: Int?

    let output = PassthroughSubject<Measurement<U>, Never>()
    let activeIndex = CurrentValueSubject<Int?, Never>(nil)
    let anySourceAvailable = CurrentValueSubject<Bool, Never>(false)

    init(sourceCount: Int) {
        latestValues = Array(repeating: nil, count: sourceCount)
        availabilities = Array(repeating: false, count: sourceCount)
        currentActiveIndex = nil
    }

    func receiveMeasurement(index: Int, value: Measurement<U>) {
        lock.lock()
        latestValues[index] = value
        let active = currentActiveIndex
        lock.unlock()

        if index == active {
            output.send(value)
        }
    }

    func receiveAvailability(index: Int, available: Bool) {
        lock.lock()
        availabilities[index] = available
        let any = availabilities.contains(true)
        let newActive = availabilities.firstIndex(where: { $0 })
        let activeChanged = newActive != currentActiveIndex
        var cachedAfterSwitch: Measurement<U>?
        if activeChanged {
            currentActiveIndex = newActive
            if let idx = newActive {
                cachedAfterSwitch = latestValues[idx]
            }
        }
        lock.unlock()

        anySourceAvailable.send(any)

        guard activeChanged else { return }
        activeIndex.send(newActive)
        if let cached = cachedAfterSwitch {
            output.send(cached)
        }
    }

    func receiveTick() {
        lock.lock()
        let idx = currentActiveIndex
        let cached = idx.flatMap { latestValues[$0] }
        lock.unlock()
        guard let measurement = cached else { return }
        output.send(measurement)
    }
}
