//
//  PrioritizedMetricSelectorTests.swift
//  CoreLogicTests
//

import Combine
import CombineSchedulers
import Foundation
import Testing

@testable import CoreLogic

/// Use the main queue as the Combine scheduler so `receive(on:)` matches how production `DependencyContainer` wires selectors.
private func metricTestScheduler() -> AnySchedulerOf<DispatchQueue> {
    DispatchQueue.main.eraseToAnyScheduler()
}

private func flushMetricDeliveries() async {
    await MainActor.run { }
    // Drain nested main work (parallel suites schedule on the main queue too).
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                cont.resume()
            }
        }
    }
    try? await Task.sleep(nanoseconds: 400_000_000)
}

@Suite("PrioritizedMetricSelector", .serialized)
@MainActor
struct PrioritizedMetricSelectorTests {
    @Test("Single always-available source forwards measurements")
    func singleSource() async throws {
        let sch = metricTestScheduler()
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 10, unit: .milesPerHour)
        )
        let avail = CurrentValueSubject<Bool, Never>(true)
        let primary = AnyMetric<UnitSpeed>(publisher: speed, isAvailable: avail)
        let selector = PrioritizedMetricSelector(sources: [primary], scheduler: sch)

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        speed.send(Measurement(value: 18, unit: .milesPerHour))
        await flushMetricDeliveries()

        #expect(values.contains(18))
        _ = sub
    }

    @Test("Two sources: only primary when both available")
    func twoSourcesPrimaryWins() async throws {
        let sch = metricTestScheduler()
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 20, unit: .milesPerHour)
        )
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 5, unit: .milesPerHour)
        )
        let pAvail = CurrentValueSubject<Bool, Never>(true)
        let sAvail = CurrentValueSubject<Bool, Never>(true)

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ], scheduler: sch)

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        await flushMetricDeliveries()
        #expect(values.last == 20)

        sSpeed.send(Measurement(value: 99, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 20)

        pSpeed.send(Measurement(value: 22, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 22)

        _ = sub
    }

    @Test("Falls back to secondary when primary unavailable")
    func fallbackToSecondary() async throws {
        let sch = metricTestScheduler()
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 20, unit: .milesPerHour)
        )
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 7, unit: .milesPerHour)
        )
        let pAvail = CurrentValueSubject<Bool, Never>(true)
        let sAvail = CurrentValueSubject<Bool, Never>(true)

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ], scheduler: sch)

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        await flushMetricDeliveries()
        #expect(values.last == 20)

        pAvail.send(false)
        await flushMetricDeliveries()

        sSpeed.send(Measurement(value: 8, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 8)

        _ = sub
    }

    @Test("Returns to primary when it becomes available again")
    func recoveryToPrimary() async throws {
        let sch = metricTestScheduler()
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 20, unit: .milesPerHour)
        )
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 7, unit: .milesPerHour)
        )
        let pAvail = CurrentValueSubject<Bool, Never>(true)
        let sAvail = CurrentValueSubject<Bool, Never>(true)

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ], scheduler: sch)

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        pAvail.send(false)
        await flushMetricDeliveries()
        sSpeed.send(Measurement(value: 9, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 9)

        pSpeed.send(Measurement(value: 25, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 9)

        pAvail.send(true)
        await flushMetricDeliveries()
        #expect(values.last == 25)

        _ = sub
    }

    @Test("No output while no source is available")
    func noSourceAvailableHoldsOutput() async throws {
        let sch = metricTestScheduler()
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 20, unit: .milesPerHour)
        )
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 7, unit: .milesPerHour)
        )
        let pAvail = CurrentValueSubject<Bool, Never>(false)
        let sAvail = CurrentValueSubject<Bool, Never>(false)

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ], scheduler: sch)

        var count = 0
        let sub = selector.publisher.sink { _ in count += 1 }

        pSpeed.send(Measurement(value: 30, unit: .milesPerHour))
        sSpeed.send(Measurement(value: 40, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(count == 0)

        pAvail.send(true)
        await flushMetricDeliveries()
        #expect(count == 1)

        _ = sub
    }

    @Test("activeSourceIndex tracks switches")
    func activeSourceIndex() async throws {
        let sch = metricTestScheduler()
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 1, unit: .milesPerHour)
        )
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 2, unit: .milesPerHour)
        )
        let pAvail = CurrentValueSubject<Bool, Never>(true)
        let sAvail = CurrentValueSubject<Bool, Never>(true)

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ], scheduler: sch)

        var indices: [Int?] = []
        let sub = selector.activeSourceIndex.sink { indices.append($0) }

        await flushMetricDeliveries()
        #expect(indices.contains(0))

        pAvail.send(false)
        await flushMetricDeliveries()
        #expect(indices.last == 1)

        pAvail.send(true)
        await flushMetricDeliveries()
        #expect(indices.last == 0)

        _ = sub
    }

    @Test("selector isAvailable is true iff any child is available")
    func aggregateAvailability() async throws {
        let sch = metricTestScheduler()
        let pAvail = CurrentValueSubject<Bool, Never>(false)
        let sAvail = CurrentValueSubject<Bool, Never>(false)
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(Measurement(value: 1, unit: .milesPerHour))
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(Measurement(value: 2, unit: .milesPerHour))

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ], scheduler: sch)

        var flags: [Bool] = []
        let sub = selector.isAvailable.sink { flags.append($0) }

        await flushMetricDeliveries()
        #expect(flags.last == false)

        sAvail.send(true)
        await flushMetricDeliveries()
        #expect(flags.last == true)

        sAvail.send(false)
        await flushMetricDeliveries()
        #expect(flags.last == false)

        _ = sub
    }

    @Test("Empty sources: no measurements, not available, nil active index")
    func emptySources() async throws {
        let selector = PrioritizedMetricSelector<UnitSpeed>(sources: [])

        var measurementCount = 0
        let sub = selector.publisher.sink { _ in measurementCount += 1 }

        var lastAvail: Bool?
        let sub2 = selector.isAvailable.sink { lastAvail = $0 }

        var lastIndex: Int? = -1
        let sub3 = selector.activeSourceIndex.sink { lastIndex = $0 }

        await Task.yield()
        #expect(measurementCount == 0)
        #expect(lastAvail == false)
        #expect(lastIndex == nil)

        _ = sub
        _ = sub2
        _ = sub3
    }

    @Test("AnyMetric init(from:) forwards nested publisher and availability")
    func anyMetricWrapsBuiltInMetric() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 5, unit: .milesPerHour)
        )
        let avail = CurrentValueSubject<Bool, Never>(true)
        let inner = AnyMetric<UnitSpeed>(publisher: speed, isAvailable: avail)
        let wrapped = AnyMetric(inner)

        var availValues: [Bool] = []
        let subA = wrapped.isAvailable.sink { availValues.append($0) }

        var lastSpeed: Double?
        let subP = wrapped.publisher.sink { lastSpeed = $0.converted(to: .milesPerHour).value }

        await Task.yield()
        #expect(availValues.first == true)
        #expect(lastSpeed == 5)

        speed.send(Measurement(value: 9, unit: .milesPerHour))
        await Task.yield()
        #expect(lastSpeed == 9)

        _ = subA
        _ = subP
    }

    @Test("Tick re-emits last active value while available (MET-GEN-3)")
    func tickReEmitsWhileAvailable() async throws {
        let sch = metricTestScheduler()
        let tick = PassthroughSubject<Void, Never>()
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 10, unit: .milesPerHour)
        )
        let avail = CurrentValueSubject<Bool, Never>(true)
        let selector = PrioritizedMetricSelector(
            sources: [AnyMetric<UnitSpeed>(publisher: speed, isAvailable: avail)],
            tick: tick.eraseToAnyPublisher(),
            scheduler: sch
        )

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        await flushMetricDeliveries()
        #expect(values.last == 10)

        tick.send(())
        await flushMetricDeliveries()
        #expect(values.last == 10)
        #expect(values.count >= 2)

        speed.send(Measurement(value: 15, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 15)

        tick.send(())
        await flushMetricDeliveries()
        #expect(values.last == 15)

        _ = sub
    }

    @Test("Tick does not emit when no source is available")
    func tickSuppressedWhenUnavailable() async throws {
        let sch = metricTestScheduler()
        let tick = PassthroughSubject<Void, Never>()
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 10, unit: .milesPerHour)
        )
        let avail = CurrentValueSubject<Bool, Never>(false)
        let selector = PrioritizedMetricSelector(
            sources: [AnyMetric<UnitSpeed>(publisher: speed, isAvailable: avail)],
            tick: tick.eraseToAnyPublisher(),
            scheduler: sch
        )

        var count = 0
        let sub = selector.publisher.sink { _ in count += 1 }

        tick.send(())
        await flushMetricDeliveries()
        #expect(count == 0)

        _ = sub
    }

    @Test("Tick does not emit before first measurement while available")
    func tickSuppressedBeforeFirstValue() async throws {
        let sch = metricTestScheduler()
        let tick = PassthroughSubject<Void, Never>()
        let speed = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let avail = CurrentValueSubject<Bool, Never>(true)
        let selector = PrioritizedMetricSelector(
            sources: [AnyMetric<UnitSpeed>(publisher: speed, isAvailable: avail)],
            tick: tick.eraseToAnyPublisher(),
            scheduler: sch
        )

        var count = 0
        let sub = selector.publisher.sink { _ in count += 1 }

        tick.send(())
        await flushMetricDeliveries()
        #expect(count == 0)

        speed.send(Measurement(value: 12, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(count == 1)

        tick.send(())
        await flushMetricDeliveries()
        #expect(count == 2)

        _ = sub
    }

    @Test("After fallback, tick replays secondary’s last value")
    func tickSwitchesValueAfterFallback() async throws {
        let sch = metricTestScheduler()
        let tick = PassthroughSubject<Void, Never>()
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 20, unit: .milesPerHour)
        )
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 7, unit: .milesPerHour)
        )
        let pAvail = CurrentValueSubject<Bool, Never>(true)
        let sAvail = CurrentValueSubject<Bool, Never>(true)

        let selector = PrioritizedMetricSelector(
            sources: [
                AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
                AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
            ],
            tick: tick.eraseToAnyPublisher(),
            scheduler: sch
        )

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        await flushMetricDeliveries()
        #expect(values.last == 20)

        pAvail.send(false)
        await flushMetricDeliveries()
        sSpeed.send(Measurement(value: 8, unit: .milesPerHour))
        await flushMetricDeliveries()
        #expect(values.last == 8)

        tick.send(())
        await flushMetricDeliveries()
        #expect(values.last == 8)

        _ = sub
    }
}
