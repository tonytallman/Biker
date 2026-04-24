//
//  HeartRateSensorAdapter.swift
//  DependencyContainer
//

import Combine
import Foundation
import HeartRateService
import SettingsVM

@MainActor
final class HeartRateSensorAdapter: Sensor {
    private let manager: HeartRateSensorManager
    private(set) var id: UUID
    private var storedName: String
    private let connectionStateSubject: CurrentValueSubject<SensorConnectionState, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private var hrCancellables = Set<AnyCancellable>()

    var name: String { storedName }
    var type: SensorType { .heartRate }

    var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    init(manager: HeartRateSensorManager, id: UUID) {
        self.manager = manager
        self.id = id
        if let hr = manager.heartRateSensor(for: id) {
            self.storedName = hr.name
            self.connectionStateSubject = CurrentValueSubject(
                mapHRConnectionStateToSensorState(hr.connectedSensorSnapshot.connectionState)
            )
            self.isEnabledSubject = CurrentValueSubject(hr.isEnabledValue)
        } else {
            self.storedName = "Heart rate"
            self.connectionStateSubject = CurrentValueSubject(.disconnected)
            self.isEnabledSubject = CurrentValueSubject(true)
        }
        if let hr = manager.heartRateSensor(for: id) {
            hr.isEnabled
                .sink { [weak self] value in
                    self?.isEnabledSubject.send(value)
                }
                .store(in: &hrCancellables)
        }
    }

    func update(from sensor: ConnectedSensor) {
        id = sensor.id
        storedName = sensor.name
        connectionStateSubject.send(mapHRConnectionStateToSensorState(sensor.connectionState))
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
final class HeartRateDiscoveredSensorAdapter: SignalStrengthReporting {
    private let manager: HeartRateSensorManager
    private(set) var id: UUID
    private var storedName: String
    private let rssiSubject: CurrentValueSubject<Int, Never>
    private let connectionStateSubject = CurrentValueSubject<SensorConnectionState, Never>(.disconnected)
    private let isEnabledSubject = CurrentValueSubject<Bool, Never>(true)

    var name: String { storedName }
    var type: SensorType { .heartRate }

    var connectionState: AnyPublisher<SensorConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    var rssi: AnyPublisher<Int, Never> {
        rssiSubject.eraseToAnyPublisher()
    }

    init(manager: HeartRateSensorManager, id: UUID) {
        self.manager = manager
        self.id = id
        self.storedName = "Heart rate"
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

func mapHRConnectionStateToSensorState(_ s: ConnectionState) -> SensorConnectionState {
    switch s {
    case .disconnected: return .disconnected
    case .connecting: return .connecting
    case .connected: return .connected
    }
}
