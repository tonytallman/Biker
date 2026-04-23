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
    private var knownAdapters: [UUID: CSCKnownSensorAdapter] = [:]
    private var discoveredAdapters: [UUID: CSCDiscoveredSensorAdapter] = [:]

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

    init(manager: CyclingSpeedAndCadenceSensorManager) {
        self.manager = manager
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
    private var cscCancellables = Set<AnyCancellable>()

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
        if let csc = manager.cscSensor(for: id) {
            self.storedName = csc.name
            self.connectionStateSubject = CurrentValueSubject(
                mapConnectionStateToSensorState(csc.connectedSensorSnapshot.connectionState)
            )
            self.wheelDiameterSubject = CurrentValueSubject(csc.currentWheelDiameter)
            self.isEnabledSubject = CurrentValueSubject(csc.isEnabledValue)
        } else {
            self.storedName = "Cycling sensor"
            self.connectionStateSubject = CurrentValueSubject(.disconnected)
            self.wheelDiameterSubject = CurrentValueSubject(
                Measurement(
                    value: CSCKnownSensorDefaults.defaultWheelDiameterMeters,
                    unit: UnitLength.meters
                )
            )
            self.isEnabledSubject = CurrentValueSubject(true)
        }
        if let csc = manager.cscSensor(for: id) {
            csc.wheelDiameter
                .sink { [weak self] value in
                    self?.wheelDiameterSubject.send(value)
                }
                .store(in: &cscCancellables)
            csc.isEnabled
                .sink { [weak self] value in
                    self?.isEnabledSubject.send(value)
                }
                .store(in: &cscCancellables)
        }
    }

    func update(from sensor: ConnectedSensor) {
        id = sensor.id
        storedName = sensor.name
        connectionStateSubject.send(mapConnectionStateToSensorState(sensor.connectionState))
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
        manager.setEnabled(peripheralID: id, enabled)
    }

    func setWheelDiameter(_ diameter: Measurement<UnitLength>) {
        manager.setWheelDiameter(peripheralID: id, diameter)
    }
}

@MainActor
private func mapConnectionStateToSensorState(_ s: ConnectionState) -> SensorConnectionState {
    switch s {
    case .disconnected: return .disconnected
    case .connecting: return .connecting
    case .connected: return .connected
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
