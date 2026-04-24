//
//  CSCPeripheralLexMetrics.swift
//  DependencyContainer
//
//  Per-peripheral CSC metric selection: lexicographic `UUID.uuidString` tie-break (ADR-0006);
//  cadence prefers ``CyclingSpeedAndCadenceSensorManager/dualCapableSensor`` when it has data (SEN-TYP-5).
//

import Combine
import CoreLogic
import CyclingSpeedAndCadenceService
import Foundation

/// Retains Combine subscriptions for lex-first CSC speed, cadence, and distance-delta metrics.
@MainActor
final class CSCPeripheralLexMetrics {
    private var cancellables = Set<AnyCancellable>()
    private var perSensorCancellables = Set<AnyCancellable>()

    private var currentSensors: [CyclingSpeedAndCadenceSensor] = []
    private var speedSnap: [UUID: (Bool, Double?)] = [:]
    private var cadenceSnap: [UUID: (Bool, Double?)] = [:]
    private var distanceSnap: [UUID: (Bool, Double?)] = [:]
    /// ``CyclingSpeedAndCadenceSensorManager/dualCapableSensor`` — preferred source for CSC speed, cadence, and wheel distance when it has data (SEN-TYP-5).
    private var preferredDualSensorID: UUID?

    private let speedOut = PassthroughSubject<Measurement<UnitSpeed>, Never>()
    private let speedAvail = CurrentValueSubject<Bool, Never>(false)
    private let cadenceOut = PassthroughSubject<Measurement<UnitFrequency>, Never>()
    private let cadenceAvail = CurrentValueSubject<Bool, Never>(false)
    private let distanceOut = PassthroughSubject<Measurement<UnitLength>, Never>()
    private let distanceAvail = CurrentValueSubject<Bool, Never>(false)

    let speed: AnyMetric<UnitSpeed>
    let cadence: AnyMetric<UnitFrequency>
    let distanceDelta: AnyMetric<UnitLength>

    init(manager: CyclingSpeedAndCadenceSensorManager) {
        self.speed = AnyMetric(publisher: speedOut, isAvailable: speedAvail)
        self.cadence = AnyMetric(publisher: cadenceOut, isAvailable: cadenceAvail)
        self.distanceDelta = AnyMetric(publisher: distanceOut, isAvailable: distanceAvail)

        manager.dualCapableSensor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                self?.preferredDualSensorID = id
                self?.emitSpeed()
                self?.emitCadence()
                self?.emitDistance()
            }
            .store(in: &cancellables)

        manager.sensors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.rebindSensors(list)
            }
            .store(in: &cancellables)
    }

    private func rebindSensors(_ list: [CyclingSpeedAndCadenceSensor]) {
        perSensorCancellables.removeAll()
        currentSensors = list
        let ids = list.map(\.id)
        speedSnap = Dictionary(uniqueKeysWithValues: ids.map { ($0, (false, nil)) })
        cadenceSnap = speedSnap
        distanceSnap = speedSnap

        for s in list {
            let id = s.id
            Publishers.CombineLatest(
                s.connectionState.map { $0 == .connected }.removeDuplicates(),
                s.speed
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] c, v in
                self?.speedSnap[id] = (c, v)
                self?.emitSpeed()
            }
            .store(in: &perSensorCancellables)

            Publishers.CombineLatest(
                s.connectionState.map { $0 == .connected }.removeDuplicates(),
                s.cadence
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] c, v in
                self?.cadenceSnap[id] = (c, v)
                self?.emitCadence()
            }
            .store(in: &perSensorCancellables)

            Publishers.CombineLatest(
                s.connectionState.map { $0 == .connected }.removeDuplicates(),
                s.distanceDelta
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] c, v in
                self?.distanceSnap[id] = (c, v)
                self?.emitDistance()
            }
            .store(in: &perSensorCancellables)
        }
        emitSpeed()
        emitCadence()
        emitDistance()
    }

    private func emitSpeed() {
        let any = Self.anyConnectedNonNil(currentSensors, snap: speedSnap)
        speedAvail.send(any)
        if let v = Self.pickPreferredOrLexScalar(sensors: currentSensors, snap: speedSnap, preferred: preferredDualSensorID) {
            speedOut.send(Measurement(value: v, unit: .metersPerSecond))
        }
    }

    private func emitCadence() {
        let any = Self.anyConnectedNonNil(currentSensors, snap: cadenceSnap)
        cadenceAvail.send(any)
        if let v = Self.pickPreferredOrLexScalar(sensors: currentSensors, snap: cadenceSnap, preferred: preferredDualSensorID) {
            cadenceOut.send(Measurement(value: v, unit: .revolutionsPerMinute))
        }
    }

    private func emitDistance() {
        let any = Self.anyConnectedNonNil(currentSensors, snap: distanceSnap)
        distanceAvail.send(any)
        if let v = Self.pickPreferredOrLexScalar(sensors: currentSensors, snap: distanceSnap, preferred: preferredDualSensorID) {
            distanceOut.send(Measurement(value: v, unit: .meters))
        }
    }

    private static func sortedIds(_ sensors: [CyclingSpeedAndCadenceSensor]) -> [UUID] {
        sensors.map(\.id).sorted { $0.uuidString < $1.uuidString }
    }

    private static func anyConnectedNonNil(
        _ sensors: [CyclingSpeedAndCadenceSensor],
        snap: [UUID: (Bool, Double?)]
    ) -> Bool {
        sortedIds(sensors).contains { id in
            guard let t = snap[id] else { return false }
            return t.0 && t.1 != nil
        }
    }

    private static func pickLexScalar(
        sensors: [CyclingSpeedAndCadenceSensor],
        snap: [UUID: (Bool, Double?)]
    ) -> Double? {
        for id in sortedIds(sensors) {
            guard let t = snap[id], t.0, let v = t.1 else { continue }
            return v
        }
        return nil
    }

    private static func pickPreferredOrLexScalar(
        sensors: [CyclingSpeedAndCadenceSensor],
        snap: [UUID: (Bool, Double?)],
        preferred: UUID?
    ) -> Double? {
        if let p = preferred, let t = snap[p], t.0, let v = t.1 {
            return v
        }
        return pickLexScalar(sensors: sensors, snap: snap)
    }
}
