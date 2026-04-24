//
//  HeartRateSensor.swift
//  HeartRateService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

@MainActor
public final class HeartRateSensor: NSObject {
    public let id: UUID

    private static let hrServiceUUID = CBUUID(string: "180D")
    private static let heartRateMeasurementUUID = CBUUID(string: "2A37")

    private var storedName: String
    private var peripheralRef: (any HRPeripheral)?

    private let bpmSubject = CurrentValueSubject<Measurement<UnitFrequency>?, Never>(nil)
    private let connectionStateSubject: CurrentValueSubject<ConnectionState, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>

    public var bpm: AnyPublisher<Measurement<UnitFrequency>, Never> {
        bpmSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var connectionState: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    public var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    public var name: String { storedName }

    public var connectedSensorSnapshot: ConnectedSensor {
        ConnectedSensor(id: id, name: storedName, connectionState: connectionStateSubject.value)
    }

    public init(
        id: UUID,
        name: String,
        initialConnectionState: ConnectionState,
        initialIsEnabled: Bool? = nil
    ) {
        self.id = id
        self.storedName = name
        self.connectionStateSubject = CurrentValueSubject(initialConnectionState)
        self.isEnabledSubject = CurrentValueSubject(initialIsEnabled ?? true)
        super.init()
    }

    public var isEnabledValue: Bool {
        isEnabledSubject.value
    }

    public func setConnectionState(_ state: ConnectionState) {
        connectionStateSubject.send(state)
    }

    public func setNameIfNeeded(_ name: String) {
        if !name.isEmpty { storedName = name }
    }

    public func updateName(_ name: String) {
        storedName = name
    }

    public func bind(peripheral: (any HRPeripheral)?) {
        peripheralRef = peripheral
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabledSubject.send(enabled)
    }

    public func didConnect() {
        connectionStateSubject.send(.connected)
        if let p = peripheralRef {
            p.delegate = self
            if let n = p.name, !n.isEmpty {
                updateName(n)
            }
        }
        peripheralRef?.discoverServices([Self.hrServiceUUID])
    }

    public func willEnterConnecting() {
        connectionStateSubject.send(.connecting)
    }

    public func didDisconnect() {
        connectionStateSubject.send(.disconnected)
        peripheralRef?.delegate = nil
        resetDerivedState()
    }

    public func markDisconnectedByBluetoothUnavailability() {
        didDisconnect()
    }

    public func resetDerivedState() {
        bpmSubject.send(nil)
    }

    public func didFailToConnect() {
        connectionStateSubject.send(.disconnected)
    }

    private func processHeartRateMeasurement(_ data: Data) {
        guard isEnabledSubject.value else { return }
        guard case let .success(parsed) = HeartRateMeasurementParser.parse(data) else { return }
        bpmSubject.send(Measurement(value: parsed.bpm, unit: UnitFrequency.beatsPerMinute))
    }
}

extension HeartRateSensor: @MainActor CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.hrServiceUUID {
            peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Self.heartRateMeasurementUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.heartRateMeasurementUUID,
              let data = characteristic.value
        else { return }
        processHeartRateMeasurement(data)
    }
}

extension HeartRateSensor {
    internal func _test_ingestHeartRateMeasurement(_ data: Data) {
        processHeartRateMeasurement(data)
    }
}
