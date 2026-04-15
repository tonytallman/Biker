//
//  PrioritizedMetricSelectorTests.swift
//  CoreLogicTests
//

import Combine
import Foundation
import Testing

@testable import CoreLogic

@Suite("PrioritizedMetricSelector", .serialized)
struct PrioritizedMetricSelectorTests {
    @Test("Single always-available source forwards measurements")
    func singleSource() async throws {
        let speed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(
            Measurement(value: 10, unit: .milesPerHour)
        )
        let avail = CurrentValueSubject<Bool, Never>(true)
        let primary = AnyMetric<UnitSpeed>(publisher: speed, isAvailable: avail)
        let selector = PrioritizedMetricSelector(sources: [primary])

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        speed.send(Measurement(value: 18, unit: .milesPerHour))
        await flushMain()

        #expect(values.contains(18))
        _ = sub
    }

    @Test("Two sources: only primary when both available")
    func twoSourcesPrimaryWins() async throws {
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
        ])

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        await flushMain()
        #expect(values.last == 20)

        sSpeed.send(Measurement(value: 99, unit: .milesPerHour))
        await flushMain()
        #expect(values.last == 20)

        pSpeed.send(Measurement(value: 22, unit: .milesPerHour))
        await flushMain()
        #expect(values.last == 22)

        _ = sub
    }

    @Test("Falls back to secondary when primary unavailable")
    func fallbackToSecondary() async throws {
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
        ])

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        await flushMain()
        #expect(values.last == 20)

        pAvail.send(false)
        await flushMain()

        sSpeed.send(Measurement(value: 8, unit: .milesPerHour))
        await flushMain()
        #expect(values.last == 8)

        _ = sub
    }

    @Test("Returns to primary when it becomes available again")
    func recoveryToPrimary() async throws {
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
        ])

        var values: [Double] = []
        let sub = selector.publisher.sink { values.append($0.converted(to: .milesPerHour).value) }

        pAvail.send(false)
        await flushMain()
        sSpeed.send(Measurement(value: 9, unit: .milesPerHour))
        await flushMain()
        #expect(values.last == 9)

        pSpeed.send(Measurement(value: 25, unit: .milesPerHour))
        await flushMain()
        #expect(values.last == 9)

        pAvail.send(true)
        await flushMain()
        #expect(values.last == 25)

        _ = sub
    }

    @Test("No output while no source is available")
    func noSourceAvailableHoldsOutput() async throws {
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
        ])

        var count = 0
        let sub = selector.publisher.sink { _ in count += 1 }

        pSpeed.send(Measurement(value: 30, unit: .milesPerHour))
        sSpeed.send(Measurement(value: 40, unit: .milesPerHour))
        await flushMain()
        #expect(count == 0)

        pAvail.send(true)
        await flushMain()
        #expect(count == 1)

        _ = sub
    }

    @Test("activeSourceIndex tracks switches")
    func activeSourceIndex() async throws {
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
        ])

        var indices: [Int?] = []
        let sub = selector.activeSourceIndex.sink { indices.append($0) }

        await flushMain()
        #expect(indices.contains(0))

        pAvail.send(false)
        await flushMain()
        #expect(indices.last == 1)

        pAvail.send(true)
        await flushMain()
        #expect(indices.last == 0)

        _ = sub
    }

    @Test("selector isAvailable is true iff any child is available")
    func aggregateAvailability() async throws {
        let pAvail = CurrentValueSubject<Bool, Never>(false)
        let sAvail = CurrentValueSubject<Bool, Never>(false)
        let pSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(Measurement(value: 1, unit: .milesPerHour))
        let sSpeed = CurrentValueSubject<Measurement<UnitSpeed>, Never>(Measurement(value: 2, unit: .milesPerHour))

        let selector = PrioritizedMetricSelector(sources: [
            AnyMetric<UnitSpeed>(publisher: pSpeed, isAvailable: pAvail),
            AnyMetric<UnitSpeed>(publisher: sSpeed, isAvailable: sAvail),
        ])

        var flags: [Bool] = []
        let sub = selector.isAvailable.sink { flags.append($0) }

        await flushMain()
        #expect(flags.last == false)

        sAvail.send(true)
        await flushMain()
        #expect(flags.last == true)

        sAvail.send(false)
        await flushMain()
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

        await flushMain()
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

        await flushMain()
        #expect(availValues.first == true)
        #expect(lastSpeed == 5)

        speed.send(Measurement(value: 9, unit: .milesPerHour))
        await flushMain()
        #expect(lastSpeed == 9)

        _ = subA
        _ = subP
    }
}

/// `PrioritizedMetricSelector` delivers on the main queue.
private func flushMain() async {
    await MainActor.run { }
    // Allow `receive(on: DispatchQueue.main)` deliveries to run (iOS XCTest can be parallel / contended).
    try? await Task.sleep(nanoseconds: 200_000_000)
}
