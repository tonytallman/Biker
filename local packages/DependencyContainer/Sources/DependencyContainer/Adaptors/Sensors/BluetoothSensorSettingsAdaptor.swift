//
//  BluetoothSensorSettingsAdaptor.swift
//  DependencyContainer
//

import Combine
import CyclingSpeedAndCadenceService
import Foundation
import SettingsModel

@MainActor
final class BluetoothSensorSettingsAdaptor: SensorSettings {
    private let manager: BluetoothSensorManager
    private let appStorage: AppStorage
    private var cancellables = Set<AnyCancellable>()
    private var lastPersistedSensorIDs: Set<UUID>

    private static let knownSensorsKey = "knownSensors"

    var sensors: AnyPublisher<[ConnectedSensorInfo], Never> {
        manager.knownSensors
            .map { sensors in sensors.map(Self.mapToConnectedSensorInfo) }
            .eraseToAnyPublisher()
    }

    var discoveredSensors: AnyPublisher<[DiscoveredSensorInfo], Never> {
        manager.discoveredSensors
            .map { list in
                list.map {
                    DiscoveredSensorInfo(id: $0.id, name: $0.name, rssi: $0.rssi)
                }
            }
            .eraseToAnyPublisher()
    }

    init(manager: BluetoothSensorManager, appStorage: AppStorage) {
        self.manager = manager
        self.appStorage = appStorage
        self.lastPersistedSensorIDs = Self.loadPersistedKnownSensors(manager: manager, appStorage: appStorage)
        manager.reconnectDisconnectedKnownSensorsIfPoweredOn()

        manager.knownSensors
            .sink { [weak self] sensors in
                self?.persistKnownSensorsIfNeeded(sensors)
            }
            .store(in: &cancellables)
    }

    func scan() {
        manager.startScan()
    }

    func stopScan() {
        manager.stopScan()
    }

    func connect(sensorID: UUID) {
        manager.connect(to: sensorID)
    }

    func disconnect(sensorID: UUID) {
        manager.disconnect(peripheralID: sensorID)
    }

    func forget(sensorID: UUID) {
        manager.forget(peripheralID: sensorID)
    }

    private static func mapToConnectedSensorInfo(_ sensor: ConnectedSensor) -> ConnectedSensorInfo {
        let state: SensorConnectionState
        switch sensor.connectionState {
        case .disconnected:
            state = .disconnected
        case .connecting:
            state = .connecting
        case .connected:
            state = .connected
        }
        return ConnectedSensorInfo(id: sensor.id, name: sensor.name, connectionState: state)
    }

    private static func loadPersistedKnownSensors(
        manager: BluetoothSensorManager,
        appStorage: AppStorage
    ) -> Set<UUID> {
        guard let raw = appStorage.get(forKey: knownSensorsKey) as? [[String: Any]] else {
            return []
        }
        var ids = Set<UUID>()
        for dict in raw {
            guard let idStr = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let id = UUID(uuidString: idStr)
            else { continue }
            manager.seedKnownSensor(id: id, name: name)
            ids.insert(id)
        }
        return ids
    }

    private func persistKnownSensorsIfNeeded(_ sensors: [ConnectedSensor]) {
        let ids = Set(sensors.map(\.id))
        guard ids != lastPersistedSensorIDs else { return }
        lastPersistedSensorIDs = ids
        let payload: [[String: String]] = sensors.map { ["id": $0.id.uuidString, "name": $0.name] }
        appStorage.set(value: payload, forKey: Self.knownSensorsKey)
    }
}
