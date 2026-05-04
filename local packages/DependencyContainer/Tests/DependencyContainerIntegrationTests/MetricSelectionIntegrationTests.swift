//
//  MetricSelectionIntegrationTests.swift
//  DependencyContainerIntegrationTests
//

import Combine
import CombineSchedulers
import CoreLogic
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService
@testable import DependencyContainer
@testable import FitnessMachineService
@testable import HeartRateService

private func metricTestScheduler() -> AnySchedulerOf<DispatchQueue> {
    DispatchQueue.main.eraseToAnyScheduler()
}

/// Aligns with `CoreLogicTests` / production wiring: `receive(on: .main)`.
private func flushMetricDeliveries() async {
    await MainActor.run { }
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                cont.resume()
            }
        }
    }
    try? await Task.sleep(nanoseconds: 200_000_000)
}

/// Avoid real `CBCentralManager` in these tests: delegate/XPC can reorder delivery vs. Lex rebind/ingest.
@MainActor
private func makeCSCManagerForMetrics() -> CyclingSpeedAndCadenceSensorManager {
    CyclingSpeedAndCadenceSensorManager(
        persistence: InMemoryCSCIntegrationPersistence(),
        central: IntegrationCSCCentral()
    )
}

@MainActor
private func makeFTMSManagerForMetrics() -> FitnessMachineSensorManager {
    FitnessMachineSensorManager(
        persistence: InMemoryFTMSIntegrationPersistence(),
        central: IntegrationFTMSCentral()
    )
}

@MainActor
@Suite("MetricSelection (integration)", .serialized)
struct MetricSelectionIntegrationTests {
    @Test func oneSource_onlyFtmsSpeed_emitsAfterIngest() async throws {
        let ftmsM = makeFTMSManagerForMetrics()
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [ftmsLex.speed],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .metersPerSecond).value) }
        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()
        ft._test_ingestIndoorBikeData(Data([0x00, 0x00, 0x10, 0x0E]))
        await flushMetricDeliveries()
        guard let v = values.last else {
            Issue.record("expected FTMS when selector has only one source")
            return
        }
        #expect(abs(v - 10.0) < 0.2)
        _ = sub
    }

    @Test func speed_selectsCscOverFtmsWhenCscBecomesAvailable() async throws {
        let cscM = makeCSCManagerForMetrics()
        let ftmsM = makeFTMSManagerForMetrics()
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gps = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let gpsMetric = AnyMetric<UnitSpeed>(publisher: gps, isAvailable: Just(false))
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.speed, ftmsLex.speed, gpsMetric],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .metersPerSecond).value) }

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()
        ft._test_ingestIndoorBikeData(ftmsSpeedTenMetersPerSecond)
        await flushMetricDeliveries()

        guard let ftmsSpeed = values.last else {
            Issue.record("Expected FTMS speed sample")
            return
        }
        #expect(abs(ftmsSpeed - 10.0) < 0.2)

        let csc = makeCSCSensor(id: UUID(), name: "Wheel", connected: true)
        cscM._test_registerSensor(csc)
        await integrationYieldForLexWiring()
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 0, time1024: 0))
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 10, time1024: 1024))
        await flushMetricDeliveries()

        guard let cscSpeed = values.last else {
            Issue.record("Expected CSC speed sample")
            return
        }
        #expect(cscSpeed > 15)
        _ = sub
    }

    @Test func speed_fallsBackToGpsWhenCscAndFtmsLackSpeed() async throws {
        let cscM = makeCSCManagerForMetrics()
        let ftmsM = makeFTMSManagerForMetrics()
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gps = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let gpsMetric = AnyMetric<UnitSpeed>(publisher: gps, isAvailable: Just(true))
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.speed, ftmsLex.speed, gpsMetric],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .metersPerSecond).value) }
        gps.send(Measurement(value: 4.5, unit: .metersPerSecond))
        await flushMetricDeliveries()
        guard let v = values.last else {
            Issue.record("Expected GPS speed")
            return
        }
        #expect(abs(v - 4.5) < 0.0001)
        _ = sub
    }

    @Test func cadence_selectsCscOverFtmsWhenBothConnected() async throws {
        let cscM = makeCSCManagerForMetrics()
        let ftmsM = makeFTMSManagerForMetrics()
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.cadence, ftmsLex.cadence],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var values: [Double] = []
        // Cadence metrics are emitted in rpm; avoid `.revolutionsPerMinute` ambiguity (CoreLogic vs FitnessMachineService extensions).
        let sub = sel.publisher.sink { values.append($0.value) }

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()
        ft._test_ingestIndoorBikeData(ftmsCadenceOnlyHundredRpm)
        await flushMetricDeliveries()

        guard let ftmsCad = values.last else {
            Issue.record("Expected FTMS cadence")
            return
        }
        #expect(abs(ftmsCad - 100.0) < 0.0001)

        let csc = makeCSCSensor(id: UUID(), name: "Crank", connected: true)
        cscM._test_registerSensor(csc)
        await integrationYieldForLexWiring()
        csc._test_ingestCSCMeasurementData(crankSample(revolutions: 10, time1024: 0))
        csc._test_ingestCSCMeasurementData(crankSample(revolutions: 20, time1024: 6144))
        await flushMetricDeliveries()

        guard let cscCad = values.last else {
            Issue.record("Expected CSC cadence")
            return
        }
        #expect(abs(cscCad - 100.0) < 0.001)
        _ = sub
    }

    @Test func distance_selectsFtmsOverCscWhenBothConnected() async throws {
        let cscM = makeCSCManagerForMetrics()
        let ftmsM = makeFTMSManagerForMetrics()
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gps = PassthroughSubject<Measurement<UnitLength>, Never>()
        let gpsMetric = AnyMetric<UnitLength>(publisher: gps, isAvailable: Just(false))
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [ftmsLex.distanceDelta, cscLex.distanceDelta, gpsMetric],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .meters).value) }

        let csc = makeCSCSensor(id: UUID(), name: "Wheel", connected: true)
        cscM._test_registerSensor(csc)
        await integrationYieldForLexWiring()
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 0, time1024: 0))
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 50, time1024: 1024))
        await flushMetricDeliveries()

        guard let cscDelta = values.last else {
            Issue.record("expected CSC distance")
            return
        }
        #expect(cscDelta > 0.01)

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()
        ft._test_ingestIndoorBikeData(ftmsTotalDistanceZero)
        await flushMetricDeliveries()
        ft._test_ingestIndoorBikeData(ftmsTotalDistanceHundred)
        await flushMetricDeliveries()

        guard let ftmsDelta = values.last else {
            Issue.record("expected FTMS distance")
            return
        }
        #expect(abs(ftmsDelta - 100.0) < 0.0001)

        let countAfterFtms = values.count
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 100, time1024: 2048))
        await flushMetricDeliveries()
        #expect(values.count == countAfterFtms)
        #expect(values.last == ftmsDelta)
        _ = sub
    }

    @Test func distance_prefersFtmsTotalOverLocalAccumulator_thenRevertsOnDisconnect() async throws {
        let cscM = makeCSCManagerForMetrics()
        let ftmsM = makeFTMSManagerForMetrics()
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gpsDistPulse = PassthroughSubject<Measurement<UnitLength>, Never>()
        let gpsDistMetric = AnyMetric<UnitLength>(publisher: gpsDistPulse, isAvailable: Just(true))
        let tick = PassthroughSubject<Void, Never>()
        let distSel = PrioritizedMetricSelector(
            sources: [ftmsLex.distanceDelta, cscLex.distanceDelta, gpsDistMetric],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        let context = MetricContext(activityState: Just(.active).eraseToAnyPublisher())
        let accum = AccumulatingMetric<UnitLength>(source: distSel.publisher, context: context)
        let localRideDist = AnyMetric<UnitLength>(publisher: accum.publisher)
        let totalDistSel = PrioritizedMetricSelector(
            sources: [ftmsLex.totalDistance, localRideDist],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )

        var meters: [Double] = []
        let sub = totalDistSel.publisher.sink { meters.append($0.converted(to: .meters).value) }

        for _ in 0..<3 {
            gpsDistPulse.send(Measurement(value: 1.0, unit: .meters))
        }
        tick.send(())
        await flushMetricDeliveries()

        guard let afterGpsOnly = meters.last else {
            Issue.record("expected GPS-fed accumulator distance")
            return
        }
        #expect(abs(afterGpsOnly - 3.0) < 0.08)

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()

        ft._test_ingestIndoorBikeData(ftmsTotalDistanceFiveHundred)
        tick.send(())
        await flushMetricDeliveries()

        guard let ftmsAbs = meters.last else {
            Issue.record("expected FTMS total distance")
            return
        }
        #expect(abs(ftmsAbs - 500.0) < 0.08)

        ft.setConnectionState(.disconnected)
        tick.send(())
        await flushMetricDeliveries()

        guard let fallback = meters.last else {
            Issue.record("expected fallback to local accumulator")
            return
        }
        #expect(abs(fallback - afterGpsOnly) < 0.15)

        sub.cancel()
    }

    @Test func heartRate_prioritizedSelector_emitsFromSingleHrSource() async throws {
        let hrM = HeartRateSensorManager(
            persistence: InMemoryHRIntegrationPersistence(),
            central: IntegrationHRCentral()
        )
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [HRMetricAdaptors.heartRate(manager: hrM)],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var last: Double?
        let sub = sel.publisher.sink { last = $0.converted(to: .beatsPerMinute).value }
        let s = makeHRSensor(id: UUID(), name: "H", connected: true)
        hrM._test_registerSensor(s)
        s._test_ingestHeartRateMeasurement(Data([0x00, 118]))
        await flushMetricDeliveries()
        #expect(last == 118)
        _ = sub
    }

    @Test func heartRate_prioritizesHrStrapOverFtmsAndFallsBack() async throws {
        let hrM = HeartRateSensorManager(
            persistence: InMemoryHRIntegrationPersistence(),
            central: IntegrationHRCentral()
        )
        let ftmsM = makeFTMSManagerForMetrics()
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [
                HRMetricAdaptors.heartRate(manager: hrM),
                ftmsLex.heartRate,
            ],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var last: Double?
        var avail = false
        let sub = sel.publisher.sink { last = $0.converted(to: .beatsPerMinute).value }
        let availSub = sel.isAvailable.sink { avail = $0 }

        let hrs = makeHRSensor(id: UUID(), name: "HRS", connected: true)
        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        hrM._test_registerSensor(hrs)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()

        ft._test_ingestIndoorBikeData(Data([0x01, 0x02, 171]))
        hrs._test_ingestHeartRateMeasurement(Data([0x00, 118]))
        await flushMetricDeliveries()
        tick.send(())
        await flushMetricDeliveries()
        #expect(last == 118)
        #expect(avail)

        hrs.setConnectionState(.disconnected)
        tick.send(())
        await flushMetricDeliveries()
        #expect(abs((last ?? 0) - 171.0) < 0.001)
        #expect(avail)

        ft.setConnectionState(.disconnected)
        tick.send(())
        await flushMetricDeliveries()
        #expect(!avail)

        sub.cancel()
        availSub.cancel()
    }

    @Test func elapsedTime_prefersFtmsOverLocalRideAccumulator_thenRevertsOnDisconnect() async throws {
        let ftmsM = makeFTMSManagerForMetrics()
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let tick = PassthroughSubject<Void, Never>()
        let pulse = PassthroughSubject<Measurement<UnitDuration>, Never>()
        let context = MetricContext(activityState: Just(.active).eraseToAnyPublisher())
        let accumulator = AccumulatingMetric<UnitDuration>(source: pulse.eraseToAnyPublisher(), context: context)
        let localRideTime = AnyMetric<UnitDuration>(publisher: accumulator.publisher)

        let sel = PrioritizedMetricSelector(
            sources: [ftmsLex.elapsedTime, localRideTime],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )

        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .seconds).value) }

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        await integrationYieldForLexWiring()

        for _ in 0..<3 {
            pulse.send(Measurement(value: 1.0, unit: .seconds))
        }
        tick.send(())
        await flushMetricDeliveries()
        guard let afterLocal = values.last else {
            Issue.record("expected local accumulation")
            return
        }
        #expect(abs(afterLocal - 3.0) < 0.02)

        ft._test_ingestIndoorBikeData(Data([0x01, 0x08, 0xE8, 0x03]))
        tick.send(())
        await flushMetricDeliveries()
        guard let ftmsChosen = values.last else {
            Issue.record("expected FTMS elapsed seconds")
            return
        }
        #expect(abs(ftmsChosen - 1000.0) < 0.02)

        ft.setConnectionState(.disconnected)
        tick.send(())
        await flushMetricDeliveries()
        guard let afterDisc = values.last else {
            Issue.record("expected accumulator after disconnect")
            return
        }
        #expect(abs(afterDisc - 3.0) < 0.03)

        sub.cancel()
    }

    @Test func metGen3_tickRepeatsCurrentSpeedAtLeastOncePerTickWhileActive() async throws {
        let cscM = makeCSCManagerForMetrics()
        let ftmsM = makeFTMSManagerForMetrics()
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gps = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let gpsMetric = AnyMetric<UnitSpeed>(publisher: gps, isAvailable: Just(true))
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.speed, ftmsLex.speed, gpsMetric],
            tick: tick.eraseToAnyPublisher(),
            scheduler: metricTestScheduler()
        )
        var emissions: [Double] = []
        let sub = sel.publisher.sink { emissions.append($0.converted(to: .metersPerSecond).value) }
        gps.send(Measurement(value: 3.0, unit: .metersPerSecond))
        await flushMetricDeliveries()
        for _ in 0..<3 {
            tick.send(())
        }
        await flushMetricDeliveries()
        #expect(emissions.count >= 4)
        for e in emissions {
            #expect(abs(e - 3.0) < 0.0001)
        }
        _ = sub
    }

    // MARK: - CSC dual preference (SEN-TYP-5)

    @Test func prefersDualCapableForSpeedAndCadenceOverLexFirstWheelOnly() async throws {
        let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let m = makeCSCManagerForMetrics()
        let lex = CSCPeripheralLexMetrics(manager: m)
        var speeds: [Double] = []
        var cadences: [Double] = []
        var lexCancellables = Set<AnyCancellable>()
        lex.speed.publisher
            .sink { speeds.append($0.converted(to: .metersPerSecond).value) }
            .store(in: &lexCancellables)
        lex.cadence.publisher
            .sink { cadences.append($0.value) }
            .store(in: &lexCancellables)
        let a = makeCSCSensor(id: idA, name: "LexFirst", connected: true)
        let b = makeCSCSensor(id: idB, name: "Dual", connected: true)
        a._test_setFeature(CSCFeature(supportsWheel: true, supportsCrank: false))
        b._test_setFeature(CSCFeature(supportsWheel: true, supportsCrank: true))
        m._test_registerSensor(a)
        m._test_registerSensor(b)
        await integrationYieldForLexWiring()

        a._test_ingestCSCMeasurementData(wheelSample(revolutions: 0, time1024: 0))
        a._test_ingestCSCMeasurementData(wheelSample(revolutions: 10, time1024: 1024))

        b._test_ingestCSCMeasurementData(combinedWheelCrank(
            wheelRevs: 0,
            wheelTime: 0,
            crankRevs: 10,
            crankTime: 0
        ))
        b._test_ingestCSCMeasurementData(combinedWheelCrank(
            wheelRevs: 1,
            wheelTime: 1024,
            crankRevs: 20,
            crankTime: 6144
        ))
        await flushMetricDeliveries()

        guard let s = speeds.last, let c = cadences.last else {
            Issue.record("Expected speed and cadence")
            return
        }
        #expect(s < 10)
        #expect(s > 1)
        #expect(abs(c - 100.0) < 0.001)
        _ = lexCancellables
    }

    // MARK: - Helpers

    private var ftmsSpeedTenMetersPerSecond: Data { Data([0x00, 0x00, 0x10, 0x0E]) }

    private var ftmsCadenceOnlyHundredRpm: Data { Data([0x05, 0x00, 0xC8, 0x00]) }

    /// Indoor Bike Data: More Data + Total Distance, 24-bit total 0 m / 100 m.
    private var ftmsTotalDistanceZero: Data { Data([0x11, 0x00, 0x00, 0x00, 0x00]) }

    private var ftmsTotalDistanceHundred: Data { Data([0x11, 0x00, 0x64, 0x00, 0x00]) }

    private var ftmsTotalDistanceFiveHundred: Data { Data([0x11, 0x00, 0xF4, 0x01, 0x00]) }

    private func wheelSample(revolutions: UInt32, time1024: UInt16) -> Data {
        var d = Data([0x01])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }

    private func crankSample(revolutions: UInt16, time1024: UInt16) -> Data {
        var d = Data([0x02])
        d.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: time1024.littleEndian) { Data($0) })
        return d
    }

    private func combinedWheelCrank(
        wheelRevs: UInt32,
        wheelTime: UInt16,
        crankRevs: UInt16,
        crankTime: UInt16
    ) -> Data {
        var d = Data([0x03])
        d.append(contentsOf: withUnsafeBytes(of: wheelRevs.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: wheelTime.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: crankRevs.littleEndian) { Data($0) })
        d.append(contentsOf: withUnsafeBytes(of: crankTime.littleEndian) { Data($0) })
        return d
    }

    private func makeCSCSensor(id: UUID, name: String, connected: Bool) -> CyclingSpeedAndCadenceSensor {
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: name,
            initialConnectionState: connected ? .connected : .disconnected
        )
        s.setConnectionState(connected ? .connected : .disconnected)
        return s
    }

    private func makeFTMSSensor(id: UUID, name: String, connected: Bool) -> FitnessMachineSensor {
        FitnessMachineSensor(
            id: id,
            name: name,
            initialConnectionState: connected ? .connected : .disconnected
        )
    }

    private func makeHRSensor(id: UUID, name: String, connected: Bool) -> HeartRateSensor {
        HeartRateSensor(
            id: id,
            name: name,
            initialConnectionState: connected ? .connected : .disconnected
        )
    }
}
