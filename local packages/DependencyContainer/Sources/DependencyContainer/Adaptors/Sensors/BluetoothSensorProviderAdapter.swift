//
//  BluetoothSensorProviderAdapter.swift
//  DependencyContainer
//
//  TODO(phase-05): Replaced by `CompositeSensorProvider` at the composition root.

import Combine
import CyclingSpeedAndCadenceService
import Foundation
import SettingsVM

@MainActor
final class BluetoothSensorProviderAdapter: SensorProvider {
    private let manager: CyclingSpeedAndCadenceSensorManager
    private let appStorage: AppStorage
    private var cancellables = Set<AnyCancellable>()
    private var lastPersistedSensorIDs: Set<UUID>

    private var knownAdapters: [UUID: CSCKnownSensorAdapter] = [:]
    private var discoveredAdapters: [UUID: CSCDiscoveredSensorAdapter] = [:]

    private static let knownSensorsKey = "knownSensors"

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

    var bluetoothAvailability: AnyPublisher<BluetoothAvailability, Never> {
        // TODO(phase-04): Map `CBCentralManager` / Core Bluetooth authorization to `BluetoothAvailability`.
        Just(BluetoothAvailability.poweredOn).eraseToAnyPublisher()
    }

    init(manager: CyclingSpeedAndCadenceSensorManager, appStorage: AppStorage) {
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

    private func reconcileKnown(_ list: [ConnectedSensor]) -> [any Sensor] {
        var seen = Set<UUID>()
        for s in list {
            seen.insert(s.id)
        }
        for id in knownAdapters.keys where !seen.contains(id) {
            knownAdapters.removeValue(forKey: id)
        }
        return list.map { s in
            let adapter: CSCKnownSensorAdapter
            if let existing = knownAdapters[s.id] {
                adapter = existing
            } else {
                let created = CSCKnownSensorAdapter(manager: manager, id: s.id)
                knownAdapters[s.id] = created
                adapter = created
            }
            adapter.update(from: s)
            return adapter
        }
    }

    private func reconcileDiscovered(_ list: [DiscoveredSensor]) -> [any Sensor] {
        var seen = Set<UUID>()
        for s in list {
            seen.insert(s.id)
        }
        for id in discoveredAdapters.keys where !seen.contains(id) {
            discoveredAdapters.removeValue(forKey: id)
        }
        return list.map { s in
            let adapter: CSCDiscoveredSensorAdapter
            if let existing = discoveredAdapters[s.id] {
                adapter = existing
            } else {
                let created = CSCDiscoveredSensorAdapter(manager: manager, id: s.id)
                discoveredAdapters[s.id] = created
                adapter = created
            }
            adapter.update(from: s)
            return adapter
        }
    }

    private static func loadPersistedKnownSensors(
        manager: CyclingSpeedAndCadenceSensorManager,
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

// MARK: - Known CSC sensor

@MainActor
private final class CSCKnownSensorAdapter: WheelDiameterAdjustable {
    private let manager: CyclingSpeedAndCadenceSensorManager
    private(set) var id: UUID
    private var storedName: String
    private let connectionStateSubject: CurrentValueSubject<SensorConnectionState, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private let wheelDiameterSubject: CurrentValueSubject<Measurement<UnitLength>, Never>

    var name: String { storedName }
    var type: SensorType { .cyclingSpeedAndCadence }

    var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var wheelDiameter: AnyPublisher<Measurement<UnitLength>, Never> {
        wheelDiameterSubject.eraseToAnyPublisher()
    }

    init(manager: CyclingSpeedAndCadenceSensorManager, id: UUID) {
        self.manager = manager
        self.id = id
        self.storedName = "Cycling sensor"
        self.connectionStateSubject = CurrentValueSubject(.disconnected)
        self.isEnabledSubject = CurrentValueSubject(true)
        self.wheelDiameterSubject = CurrentValueSubject(Measurement(value: 700, unit: .millimeters))
    }

    func update(from sensor: ConnectedSensor) {
        id = sensor.id
        storedName = sensor.name
        connectionStateSubject.send(mapConnectionState(sensor.connectionState))
    }

    func connect() {
        manager.connect(to: id)
    }

    func disconnect() {
        manager.disconnect(peripheralID: id)
    }

    func forget() {
        manager.forget(peripheralID: id)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabledSubject.send(enabled)
    }

    func setWheelDiameter(_ diameter: Measurement<UnitLength>) {
        wheelDiameterSubject.send(diameter)
    }

    private func mapConnectionState(_ s: ConnectionState) -> SensorConnectionState {
        switch s {
        case .disconnected:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        }
    }
}

// MARK: - Discovered CSC peripheral

@MainActor
private final class CSCDiscoveredSensorAdapter: SignalStrengthReporting {
    private let manager: CyclingSpeedAndCadenceSensorManager
    private(set) var id: UUID
    private var storedName: String
    private let rssiSubject: CurrentValueSubject<Int, Never>
    private let connectionStateSubject = CurrentValueSubject<SensorConnectionState, Never>(.disconnected)
    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(true)

    var name: String { storedName }
    var type: SensorType { .cyclingSpeedAndCadence }

    var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var rssi: AnyPublisher<Int, Never> {
        rssiSubject.eraseToAnyPublisher()
    }

    init(manager: CyclingSpeedAndCadenceSensorManager, id: UUID) {
        self.manager = manager
        self.id = id
        self.storedName = "Cycling sensor"
        self.rssiSubject = CurrentValueSubject(-100)
    }

    func update(from sensor: DiscoveredSensor) {
        id = sensor.id
        storedName = sensor.name
        rssiSubject.send(sensor.rssi)
    }

    func connect() {
        manager.connect(to: id)
    }

    func disconnect() {}

    func forget() {}

    func setEnabled(_ enabled: Bool) {
        isEnabledSubject.send(enabled)
    }
}
