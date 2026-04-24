//
//  CrossFamilyMetricSelectionTests.swift
//  DependencyContainerTests
//

import Combine
import CoreLogic
import Foundation
import Testing

@testable import CyclingSpeedAndCadenceService
@testable import DependencyContainer
@testable import FitnessMachineService
@testable import HeartRateService

@MainActor
@Suite("CrossFamilyMetricSelection")
struct CrossFamilyMetricSelectionTests {
    @Test func speed_selectsCscOverFtmsWhenCscBecomesAvailable() {
        let cscM = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        let ftmsM = FitnessMachineSensorManager(persistence: InMemoryFTMSPersistence())
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gps = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let gpsMetric = AnyMetric<UnitSpeed>(publisher: gps, isAvailable: Just(false))
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.speed, ftmsLex.speed, gpsMetric],
            tick: tick.eraseToAnyPublisher()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .metersPerSecond).value) }

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        ft._test_ingestIndoorBikeData(ftmsSpeedTenMetersPerSecond)

        guard let ftmsSpeed = values.last else {
            Issue.record("Expected FTMS speed sample")
            return
        }
        #expect(abs(ftmsSpeed - 10.0) < 0.2)

        let csc = makeCSCSensor(id: UUID(), name: "Wheel", connected: true)
        cscM._test_registerSensor(csc)
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 0, time1024: 0))
        csc._test_ingestCSCMeasurementData(wheelSample(revolutions: 10, time1024: 1024))

        guard let cscSpeed = values.last else {
            Issue.record("Expected CSC speed sample")
            return
        }
        #expect(cscSpeed > 15)
        _ = sub
    }

    @Test func speed_fallsBackToGpsWhenCscAndFtmsLackSpeed() {
        let cscM = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        let ftmsM = FitnessMachineSensorManager(persistence: InMemoryFTMSPersistence())
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let gps = PassthroughSubject<Measurement<UnitSpeed>, Never>()
        let gpsMetric = AnyMetric<UnitSpeed>(publisher: gps, isAvailable: Just(true))
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.speed, ftmsLex.speed, gpsMetric],
            tick: tick.eraseToAnyPublisher()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .metersPerSecond).value) }
        gps.send(Measurement(value: 4.5, unit: .metersPerSecond))
        guard let v = values.last else {
            Issue.record("Expected GPS speed")
            return
        }
        #expect(abs(v - 4.5) < 0.0001)
        _ = sub
    }

    @Test func cadence_selectsCscOverFtmsWhenBothConnected() {
        let cscM = CyclingSpeedAndCadenceSensorManager(persistence: InMemoryCSCPersistence())
        let ftmsM = FitnessMachineSensorManager(persistence: InMemoryFTMSPersistence())
        let cscLex = CSCPeripheralLexMetrics(manager: cscM)
        let ftmsLex = FTMSPeripheralLexMetrics(manager: ftmsM)
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [cscLex.cadence, ftmsLex.cadence],
            tick: tick.eraseToAnyPublisher()
        )
        var values: [Double] = []
        let sub = sel.publisher.sink { values.append($0.converted(to: .revolutionsPerMinute).value) }

        let ft = makeFTMSSensor(id: UUID(), name: "Trainer", connected: true)
        ftmsM._test_registerSensor(ft)
        ft._test_ingestIndoorBikeData(ftmsCadenceOnlyHundredRpm)

        guard let ftmsCad = values.last else {
            Issue.record("Expected FTMS cadence")
            return
        }
        #expect(abs(ftmsCad - 100.0) < 0.0001)

        let csc = makeCSCSensor(id: UUID(), name: "Crank", connected: true)
        cscM._test_registerSensor(csc)
        csc._test_ingestCSCMeasurementData(crankSample(revolutions: 10, time1024: 0))
        csc._test_ingestCSCMeasurementData(crankSample(revolutions: 20, time1024: 6144))

        guard let cscCad = values.last else {
            Issue.record("Expected CSC cadence")
            return
        }
        #expect(abs(cscCad - 100.0) < 0.001)
        _ = sub
    }

    @Test func heartRate_prioritizedSelector_emitsFromSingleHrSource() {
        let hrM = HeartRateSensorManager(persistence: InMemoryHRPersistence(), central: TestFakeHRCentral())
        let tick = PassthroughSubject<Void, Never>()
        let sel = PrioritizedMetricSelector(
            sources: [HRMetricAdaptors.heartRate(manager: hrM)],
            tick: tick.eraseToAnyPublisher()
        )
        var last: Double?
        let sub = sel.publisher.sink { last = $0.converted(to: .beatsPerMinute).value }
        let s = makeHRSensor(id: UUID(), name: "H", connected: true)
        hrM._test_registerSensor(s)
        s._test_ingestHeartRateMeasurement(Data([0x00, 118]))
        #expect(last == 118)
        _ = sub
    }

    private var ftmsSpeedTenMetersPerSecond: Data { Data([0x00, 0x00, 0x10, 0x0E]) }

    /// More Data + instantaneous cadence; 100 rpm → raw 200.
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
