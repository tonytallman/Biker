//
//  FTMSPeripheralLexMetrics.swift
//  DependencyContainer
//
//  Per-peripheral FTMS metric selection: lexicographic `UUID.uuidString` among connected sensors (ADR-0006).
//

import Combine
import CoreLogic
import FitnessMachineService
import Foundation

@MainActor
final class FTMSPeripheralLexMetrics {
    private var cancellables = Set<AnyCancellable>()
    private var perSensorCancellables = Set<AnyCancellable>()

    private var currentSensors: [FitnessMachineSensor] = []
    private var speedSnap: [UUID: (Bool, Measurement<UnitSpeed>?)] = [:]
    private var cadenceSnap: [UUID: (Bool, Measurement<UnitFrequency>?)] = [:]
    private var distanceSnap: [UUID: (Bool, Double?)] = [:]

    private let speedOut = PassthroughSubject<Measurement<UnitSpeed>, Never>()
    private let speedAvail = CurrentValueSubject<Bool, Never>(false)
    private let cadenceOut = PassthroughSubject<Measurement<UnitFrequency>, Never>()
    private let cadenceAvail = CurrentValueSubject<Bool, Never>(false)
    private let distanceOut = PassthroughSubject<Measurement<UnitLength>, Never>()
    private let distanceAvail = CurrentValueSubject<Bool, Never>(false)

    let speed: AnyMetric<UnitSpeed>
    let cadence: AnyMetric<UnitFrequency>
    let distanceDelta: AnyMetric<UnitLength>

    init(manager: FitnessMachineSensorManager) {
        self.speed = AnyMetric(publisher: speedOut, isAvailable: speedAvail)
        self.cadence = AnyMetric(publisher: cadenceOut, isAvailable: cadenceAvail)
        self.distanceDelta = AnyMetric(publisher: distanceOut, isAvailable: distanceAvail)

        // `rebindSensors` is `@MainActor`. Combine may deliver `sensors` off the main queue; without
        // `receive(on:)` the hop is async and test/app code can `ingest` before per-sensor hooks exist.
        manager.sensors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.rebindSensors(list)
            }
            .store(in: &cancellables)
    }

    private func rebindSensors(_ list: [FitnessMachineSensor]) {
        perSensorCancellables.removeAll()
        currentSensors = list
        let ids = list.map(\.id)
        speedSnap = Dictionary(uniqueKeysWithValues: ids.map { ($0, (false, nil)) })
        cadenceSnap = Dictionary(uniqueKeysWithValues: ids.map { ($0, (false, nil)) })
        distanceSnap = Dictionary(uniqueKeysWithValues: ids.map { ($0, (false, nil)) })

        for s in list {
            let id = s.id
            Publishers.CombineLatest(
                s.connectionState.map { $0 == .connected }.removeDuplicates(),
                s.speedOptional
            )
            .sink { [weak self] c, v in
                self?.speedSnap[id] = (c, v)
                self?.emitSpeed()
            }
            .store(in: &perSensorCancellables)

            Publishers.CombineLatest(
                s.connectionState.map { $0 == .connected }.removeDuplicates(),
                s.cadenceOptional
            )
            .sink { [weak self] c, v in
                self?.cadenceSnap[id] = (c, v)
                self?.emitCadence()
            }
            .store(in: &perSensorCancellables)

            Publishers.CombineLatest(
                s.connectionState.map { $0 == .connected }.removeDuplicates(),
                s.distanceDelta
            )
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
        speedAvail.send(Self.anyConnectedNonNilSpeed(currentSensors, snap: speedSnap))
        if let m = Self.pickLexSpeed(sensors: currentSensors, snap: speedSnap) {
            speedOut.send(m)
        }
    }

    private func emitCadence() {
        cadenceAvail.send(Self.anyConnectedNonNilCadence(currentSensors, snap: cadenceSnap))
        if let m = Self.pickLexCadence(sensors: currentSensors, snap: cadenceSnap) {
            cadenceOut.send(m)
        }
    }

    private func emitDistance() {
        distanceAvail.send(Self.anyConnectedNonNilDistance(currentSensors, snap: distanceSnap))
        if let v = Self.pickLexDistanceScalar(sensors: currentSensors, snap: distanceSnap) {
            distanceOut.send(Measurement(value: v, unit: .meters))
        }
    }

    private static func sortedIds(_ sensors: [FitnessMachineSensor]) -> [UUID] {
        sensors.map(\.id).sorted { $0.uuidString < $1.uuidString }
    }

    private static func anyConnectedNonNilSpeed(
        _ sensors: [FitnessMachineSensor],
        snap: [UUID: (Bool, Measurement<UnitSpeed>?)]
    ) -> Bool {
        sortedIds(sensors).contains { id in
            guard let t = snap[id] else { return false }
            return t.0 && t.1 != nil
        }
    }

    private static func anyConnectedNonNilCadence(
        _ sensors: [FitnessMachineSensor],
        snap: [UUID: (Bool, Measurement<UnitFrequency>?)]
    ) -> Bool {
        sortedIds(sensors).contains { id in
            guard let t = snap[id] else { return false }
            return t.0 && t.1 != nil
        }
    }

    private static func anyConnectedNonNilDistance(
        _ sensors: [FitnessMachineSensor],
        snap: [UUID: (Bool, Double?)]
    ) -> Bool {
        sortedIds(sensors).contains { id in
            guard let t = snap[id] else { return false }
            return t.0 && t.1 != nil
        }
    }

    private static func pickLexSpeed(
        sensors: [FitnessMachineSensor],
        snap: [UUID: (Bool, Measurement<UnitSpeed>?)]
    ) -> Measurement<UnitSpeed>? {
        for id in sortedIds(sensors) {
            guard let t = snap[id], t.0, let m = t.1 else { continue }
            return m
        }
        return nil
    }

    private static func pickLexCadence(
        sensors: [FitnessMachineSensor],
        snap: [UUID: (Bool, Measurement<UnitFrequency>?)]
    ) -> Measurement<UnitFrequency>? {
        for id in sortedIds(sensors) {
            guard let t = snap[id], t.0, let m = t.1 else { continue }
            return m
        }
        return nil
    }

    private static func pickLexDistanceScalar(
        sensors: [FitnessMachineSensor],
        snap: [UUID: (Bool, Double?)]
    ) -> Double? {
        for id in sortedIds(sensors) {
            guard let t = snap[id], t.0, let v = t.1 else { continue }
            return v
        }
        return nil
    }
}
