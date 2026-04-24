//
//  HRSensorProvider.swift
//  DependencyContainer
//

import Combine
import Foundation
import HeartRateService
import SettingsVM

@MainActor
final class HRSensorProvider: SensorProvider {
    private let manager: HeartRateSensorManager
    private var knownAdapters: [UUID: HeartRateSensorAdapter] = [:]
    private var discoveredAdapters: [UUID: HeartRateDiscoveredSensorAdapter] = [:]

    init(manager: HeartRateSensorManager) {
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
            let adapter: HeartRateSensorAdapter
            if let existing = knownAdapters[s.id] {
                adapter = existing
            } else {
                let created = HeartRateSensorAdapter(manager: manager, id: s.id)
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
            let adapter: HeartRateDiscoveredSensorAdapter
            if let existing = discoveredAdapters[s.id] {
                adapter = existing
            } else {
                let created = HeartRateDiscoveredSensorAdapter(manager: manager, id: s.id)
                discoveredAdapters[s.id] = created
                adapter = created
            }
            adapter.update(from: s)
            return adapter
        }
    }
}
