//
//  StatisticMetricTests.swift
//  CoreLogicTests
//

import Combine
import Foundation
import Testing

@testable import CoreLogic

@Suite("Statistic publisher extension")
struct StatisticPublisherExtensionTests {
    @Test("statistic with fixed initial zero matches sum while active")
    func statisticSumWhileActive() throws {
        let deltas = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activity = CurrentValueSubject<ActivityState, Never>(.active)
        let zero = Measurement<UnitLength>(value: 0, unit: .meters)
        let summed = deltas.statistic(whileActive: activity.eraseToAnyPublisher(), initial: zero) { $0 + $1 }

        var last: Measurement<UnitLength>?
        let sub = summed.sink { last = $0 }

        deltas.send(1.meters)
        #expect(last?.converted(to: .meters).value == 1)
        deltas.send(2.meters)
        #expect(last?.converted(to: .meters).value == 3)

        activity.send(.paused)
        deltas.send(100.meters)
        #expect(last?.converted(to: .meters).value == 3)

        activity.send(.active)
        deltas.send(4.meters)
        #expect(last?.converted(to: .meters).value == 7)

        _ = sub
    }

    @Test("statistic with nil initial tracks running maximum")
    func statisticMaxFirstSampleSeed() throws {
        let samples = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activity = CurrentValueSubject<ActivityState, Never>(.active)
        let maxed = samples.statistic(whileActive: activity.eraseToAnyPublisher(), initial: nil) { a, b in
            let x = a.converted(to: .meters).value
            let y = b.converted(to: .meters).value
            return x >= y ? a.converted(to: .meters) : b.converted(to: .meters)
        }

        var last: Measurement<UnitLength>?
        let sub = maxed.sink { last = $0 }

        samples.send(3.meters)
        #expect(last?.converted(to: .meters).value == 3)
        samples.send(10.meters)
        #expect(last?.converted(to: .meters).value == 10)
        samples.send(5.meters)
        #expect(last?.converted(to: .meters).value == 10)

        _ = sub
    }

    @Test("statistic with nil initial tracks running minimum")
    func statisticMinFirstSampleSeed() throws {
        let samples = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activity = CurrentValueSubject<ActivityState, Never>(.active)
        let mined = samples.statistic(whileActive: activity.eraseToAnyPublisher(), initial: nil) { a, b in
            let x = a.converted(to: .meters).value
            let y = b.converted(to: .meters).value
            return x <= y ? a.converted(to: .meters) : b.converted(to: .meters)
        }

        var last: Measurement<UnitLength>?
        let sub = mined.sink { last = $0 }

        samples.send(5.meters)
        #expect(last?.converted(to: .meters).value == 5)
        samples.send(2.meters)
        #expect(last?.converted(to: .meters).value == 2)
        samples.send(8.meters)
        #expect(last?.converted(to: .meters).value == 2)

        _ = sub
    }
}

@Suite("AccumulatingMetric")
struct AccumulatingMetricTests {
    @Test("sums deltas while active; context activity gates updates")
    func accumulatingMetricPauseResume() throws {
        let deltas = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activity = CurrentValueSubject<ActivityState, Never>(.active)
        let context = MetricContext(activityState: activity.eraseToAnyPublisher())
        let metric = AccumulatingMetric<UnitLength>(source: deltas, context: context)

        var last: Measurement<UnitLength>?
        let sub = metric.publisher.sink { last = $0 }

        deltas.send(1.meters)
        #expect(last?.converted(to: .meters).value == 1)

        activity.send(.paused)
        deltas.send(50.meters)
        #expect(last?.converted(to: .meters).value == 1)

        activity.send(.active)
        deltas.send(2.meters)
        #expect(last?.converted(to: .meters).value == 3)

        _ = sub
    }
}

@Suite("MaximumMetric")
struct MaximumMetricTests {
    @Test("tracks maximum while active; ignores samples while paused")
    func maximumWhileActive() throws {
        let samples = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let activity = CurrentValueSubject<ActivityState, Never>(.active)
        let context = MetricContext(activityState: activity.eraseToAnyPublisher())
        let metric = MaximumMetric<UnitSpeed>(source: samples, context: context)

        var last: Measurement<UnitSpeed>?
        let sub = metric.publisher.sink { last = $0 }

        samples.send(Measurement(value: 3, unit: .metersPerSecond))
        #expect(last?.converted(to: .metersPerSecond).value == 3)
        samples.send(Measurement(value: 8, unit: .metersPerSecond))
        #expect(last?.converted(to: .metersPerSecond).value == 8)

        activity.send(.paused)
        samples.send(Measurement(value: 20, unit: .metersPerSecond))
        #expect(last?.converted(to: .metersPerSecond).value == 8)

        activity.send(.active)
        samples.send(Measurement(value: 9, unit: .metersPerSecond))
        #expect(last?.converted(to: .metersPerSecond).value == 9)

        _ = sub
    }
}

@Suite("MinimumMetric")
struct MinimumMetricTests {
    @Test("tracks minimum while active; ignores samples while paused")
    func minimumWhileActive() throws {
        let samples = PassthroughSubject<Measurement<UnitLength>, Never>()
        let activity = CurrentValueSubject<ActivityState, Never>(.active)
        let context = MetricContext(activityState: activity.eraseToAnyPublisher())
        let metric = MinimumMetric<UnitLength>(source: samples, context: context)

        var last: Measurement<UnitLength>?
        let sub = metric.publisher.sink { last = $0 }

        samples.send(10.meters)
        #expect(last?.converted(to: .meters).value == 10)
        samples.send(4.meters)
        #expect(last?.converted(to: .meters).value == 4)

        activity.send(.paused)
        samples.send(1.meters)
        #expect(last?.converted(to: .meters).value == 4)

        activity.send(.active)
        samples.send(6.meters)
        #expect(last?.converted(to: .meters).value == 4)

        _ = sub
    }
}
