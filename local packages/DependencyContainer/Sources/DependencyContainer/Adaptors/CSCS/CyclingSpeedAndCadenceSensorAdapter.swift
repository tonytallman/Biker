//
//  CyclingSpeedAndCadenceSensorAdapter.swift
//  DependencyContainer
//
//  Maps `CyclingSpeedAndCadenceSensorManager` + CSC types to `SettingsVM` sensor protocols.

import Combine
import CyclingSpeedAndCadenceService
import Foundation
import SettingsVM

@MainActor
final class CyclingSpeedAndCadenceSensorAdapter: WheelDiameterAdjustable {
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
                mapCSCConnectionStateToSensorState(csc.connectedSensorSnapshot.connectionState)
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
        connectionStateSubject.send(mapCSCConnectionStateToSensorState(sensor.connectionState))
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

// MARK: - Discovered (scan) row

@MainActor
final class CyclingSpeedAndCadenceDiscoveredSensorAdapter: SignalStrengthReporting {
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

func mapCSCConnectionStateToSensorState(_ s: ConnectionState) -> SensorConnectionState {
    switch s {
    case .disconnected: return .disconnected
    case .connecting: return .connecting
    case .connected: return .connected
    }
}
