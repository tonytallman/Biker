//
//  FitnessMachineSensorAdapter.swift
//  DependencyContainer
//

import Combine
import FitnessMachineService
import Foundation
import SettingsVM

@MainActor
final class FitnessMachineSensorAdapter: Sensor {
    private let manager: FitnessMachineSensorManager
    private(set) var id: UUID
    private var storedName: String
    private let connectionStateSubject: CurrentValueSubject<SensorConnectionState, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private var ftmsCancellables = Set<AnyCancellable>()

    var name: String { storedName }
    var type: SensorType { .fitnessMachine }

    var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    init(manager: FitnessMachineSensorManager, id: UUID) {
        self.manager = manager
        self.id = id
        if let ftms = manager.ftmsSensor(for: id) {
            self.storedName = ftms.name
            self.connectionStateSubject = CurrentValueSubject(
                mapFTMSConnectionStateToSensorState(ftms.connectedSensorSnapshot.connectionState)
            )
            self.isEnabledSubject = CurrentValueSubject(ftms.isEnabledValue)
        } else {
            self.storedName = "Fitness machine"
            self.connectionStateSubject = CurrentValueSubject(.disconnected)
            self.isEnabledSubject = CurrentValueSubject(true)
        }
        if let ftms = manager.ftmsSensor(for: id) {
            ftms.isEnabled
                .sink { [weak self] value in
                    self?.isEnabledSubject.send(value)
                }
                .store(in: &ftmsCancellables)
        }
    }

    func update(from sensor: ConnectedSensor) {
        id = sensor.id
        storedName = sensor.name
        connectionStateSubject.send(mapFTMSConnectionStateToSensorState(sensor.connectionState))
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
}

@MainActor
final class FitnessMachineDiscoveredSensorAdapter: SignalStrengthReporting {
    private let manager: FitnessMachineSensorManager
    private(set) var id: UUID
    private var storedName: String
    private let rssiSubject: CurrentValueSubject<Int, Never>
    private let connectionStateSubject = CurrentValueSubject<SensorConnectionState, Never>(.disconnected)
    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(true)

    var name: String { storedName }
    var type: SensorType { .fitnessMachine }

    var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var rssi: AnyPublisher<Int, Never> {
        rssiSubject.eraseToAnyPublisher()
    }

    init(manager: FitnessMachineSensorManager, id: UUID) {
        self.manager = manager
        self.id = id
        self.storedName = "Fitness machine"
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

func mapFTMSConnectionStateToSensorState(_ s: ConnectionState) -> SensorConnectionState {
    switch s {
    case .disconnected: return .disconnected
    case .connecting: return .connecting
    case .connected: return .connected
    }
}
