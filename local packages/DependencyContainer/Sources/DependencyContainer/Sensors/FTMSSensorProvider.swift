//
//  FTMSSensorProvider.swift
//  DependencyContainer
//

import Combine
import FitnessMachineService
import Foundation
import SettingsVM

@MainActor
final class FTMSSensorProvider: SensorProvider {
    private let manager: FitnessMachineSensorManager
    private var knownAdapters: [UUID: FitnessMachineSensorAdapter] = [:]
    private var discoveredAdapters: [UUID: FitnessMachineDiscoveredSensorAdapter] = [:]

    init(manager: FitnessMachineSensorManager) {
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
            let adapter: FitnessMachineSensorAdapter
            if let existing = knownAdapters[s.id] {
                adapter = existing
            } else {
                let created = FitnessMachineSensorAdapter(manager: manager, id: s.id)
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
            let adapter: FitnessMachineDiscoveredSensorAdapter
            if let existing = discoveredAdapters[s.id] {
                adapter = existing
            } else {
                let created = FitnessMachineDiscoveredSensorAdapter(manager: manager, id: s.id)
                discoveredAdapters[s.id] = created
                adapter = created
            }
            adapter.update(from: s)
            return adapter
        }
    }
}
