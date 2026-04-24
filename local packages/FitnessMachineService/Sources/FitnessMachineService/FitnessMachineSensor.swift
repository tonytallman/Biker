//
//  FitnessMachineSensor.swift
//  FitnessMachineService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

@MainActor
public final class FitnessMachineSensor: NSObject {
    public let id: UUID

    private static let ftmsServiceUUID = CBUUID(string: "1826")
    private static let indoorBikeDataUUID = CBUUID(string: "2AD2")

    private var storedName: String
    private var peripheralRef: (any FTMSPeripheral)?

    private let speedSubject = CurrentValueSubject<Measurement<UnitSpeed>?, Never>(nil)
    private let cadenceSubject = CurrentValueSubject<Measurement<UnitFrequency>?, Never>(nil)
    private let connectionStateSubject: CurrentValueSubject<ConnectionState, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private let derivedSubject = PassthroughSubject<IndoorBikeData, Never>()

    public var derivedUpdates: AnyPublisher<IndoorBikeData, Never> {
        derivedSubject.eraseToAnyPublisher()
    }

    public var speed: AnyPublisher<Measurement<UnitSpeed>, Never> {
        speedSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var cadence: AnyPublisher<Measurement<UnitFrequency>, Never> {
        cadenceSubject.compactMap { $0 }.eraseToAnyPublisher()
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

    public func bind(peripheral: (any FTMSPeripheral)?) {
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
        peripheralRef?.discoverServices([Self.ftmsServiceUUID])
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
        speedSubject.send(nil)
        cadenceSubject.send(nil)
    }

    public func didFailToConnect() {
        connectionStateSubject.send(.disconnected)
    }

    private func processIndoorBikeData(_ data: Data) {
        guard isEnabledSubject.value else { return }
        guard case let .success(parsed) = IndoorBikeDataParser.parse(data) else { return }
        derivedSubject.send(parsed)
        if let v = parsed.speedMetersPerSecond {
            speedSubject.send(Measurement(value: v, unit: UnitSpeed.metersPerSecond))
        }
        if let v = parsed.cadenceRPM {
            cadenceSubject.send(Measurement(value: v, unit: UnitFrequency.revolutionsPerMinute))
        }
    }
}

extension FitnessMachineSensor: @MainActor CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.ftmsServiceUUID {
            peripheral.discoverCharacteristics([Self.indoorBikeDataUUID], for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == Self.indoorBikeDataUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, characteristic.uuid == Self.indoorBikeDataUUID, let data = characteristic.value else { return }
        processIndoorBikeData(data)
    }
}

extension FitnessMachineSensor {
    internal func _test_ingestIndoorBikeData(_ data: Data) {
        processIndoorBikeData(data)
    }
}
