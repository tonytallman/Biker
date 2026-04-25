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
