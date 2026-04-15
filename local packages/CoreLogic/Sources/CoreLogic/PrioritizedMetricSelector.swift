//
//  PrioritizedMetricSelector.swift
//  CoreLogic
//

import Combine
import Foundation

/// Picks the highest-priority ``AnyMetric`` that is currently available; falls back when that source stalls or disconnects.
public final class PrioritizedMetricSelector<U: Dimension>: Metric, @unchecked Sendable {
    public typealias UnitType = U

    public let publisher: AnyPublisher<Measurement<U>, Never>
    public let isAvailable: AnyPublisher<Bool, Never>
    /// Index into the source array passed to ``init(sources:)``, or `nil` when no source is available.
    public let activeSourceIndex: AnyPublisher<Int?, Never>

    private let state: SelectorState<U>?

    /// - Parameter sources: Highest priority first.
    public init(sources: [AnyMetric<U>]) {
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

        for (index, source) in sources.enumerated() {
            source.publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak st] measurement in
                    st?.receiveMeasurement(index: index, value: measurement)
                }
                .store(in: &st.cancellables)

            source.isAvailable
                .receive(on: DispatchQueue.main)
                .sink { [weak st] available in
                    st?.receiveAvailability(index: index, available: available)
                }
                .store(in: &st.cancellables)
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

    var cancellables = Set<AnyCancellable>()

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
}
