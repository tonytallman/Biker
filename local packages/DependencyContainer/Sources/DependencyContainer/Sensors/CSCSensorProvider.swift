//
//  CSCSensorProvider.swift
//  DependencyContainer
//
//  Wraps `CyclingSpeedAndCadenceSensorManager` as a `SensorProvider` composed by `CompositeSensorProvider` (Phase 05).

import Combine
import CyclingSpeedAndCadenceService
import Foundation
import SettingsVM

@MainActor
final class CSCSensorProvider: SensorProvider {
    private let manager: CyclingSpeedAndCadenceSensorManager
    private var knownAdapters: [UUID: CyclingSpeedAndCadenceSensorAdapter] = [:]
    private var discoveredAdapters: [UUID: CyclingSpeedAndCadenceDiscoveredSensorAdapter] = [:]

    init(manager: CyclingSpeedAndCadenceSensorManager) {
        self.manager = manager
    }

    var knownSensors: AnyPublisher<[any Sensor], Never> {
        manager.knownSensors
            .map { [weak self] list -> [any Sensor] in
                self?.reconcileKnown(list) ?? []
            }
            .eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[any Sensor], Never> {
        manager.discoveredSensors
            .map { [weak self] list -> [any Sensor] in
                self?.reconcileDiscovered(list) ?? []
            }
            .eraseToAnyPublisher()
    }

    func scan() {
        manager.startScan()
    }

    func stopScan() {
        manager.stopScan()
    }

    private func reconcileKnown(_ list: [ConnectedSensor]) -> [any Sensor] {
        var seen = Set<UUID>()
        for s in list { seen.insert(s.id) }
        for id in knownAdapters.keys where !seen.contains(id) {
            knownAdapters.removeValue(forKey: id)
        }
        return list.map { s in
            let adapter: CyclingSpeedAndCadenceSensorAdapter
            if let existing = knownAdapters[s.id] {
                adapter = existing
            } else {
                let created = CyclingSpeedAndCadenceSensorAdapter(manager: manager, id: s.id)
                knownAdapters[s.id] = created
                adapter = created
            }
            adapter.update(from: s)
            return adapter
        }
    }

    private func reconcileDiscovered(_ list: [DiscoveredSensor]) -> [any Sensor] {
        var seen = Set<UUID>()
        for s in list { seen.insert(s.id) }
        for id in discoveredAdapters.keys where !seen.contains(id) {
            discoveredAdapters.removeValue(forKey: id)
        }
        return list.map { s in
            let adapter: CyclingSpeedAndCadenceDiscoveredSensorAdapter
            if let existing = discoveredAdapters[s.id] {
                adapter = existing
            } else {
                let created = CyclingSpeedAndCadenceDiscoveredSensorAdapter(manager: manager, id: s.id)
                discoveredAdapters[s.id] = created
                adapter = created
            }
            adapter.update(from: s)
            return adapter
        }
    }
}
