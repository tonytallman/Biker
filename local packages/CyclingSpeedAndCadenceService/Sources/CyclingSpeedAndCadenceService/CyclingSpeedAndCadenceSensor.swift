//
//  CyclingSpeedAndCadenceSensor.swift
//  CyclingSpeedAndCadenceService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

@MainActor
public final class CyclingSpeedAndCadenceSensor: NSObject {
    public let id: UUID

    private static let cscServiceUUID = CBUUID(string: "1816")
    private static let cscMeasurementUUID = CBUUID(string: "2A5B")
    private static let cscFeatureUUID = CBUUID(string: "2A5C")

    private var storedName: String

    private var calculator: CSCDeltaCalculator
    private var peripheralRef: (any CSCPeripheral)?

    private let speedSubject = CurrentValueSubject<Double?, Never>(nil)
    private let cadenceSubject = CurrentValueSubject<Double?, Never>(nil)
    private let distanceDeltaSubject = CurrentValueSubject<Double?, Never>(nil)
    private let connectionStateSubject: CurrentValueSubject<ConnectionState, Never>
    private let wheelDiameterSubject: CurrentValueSubject<Measurement<UnitLength>, Never>
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private let derivedSubject = PassthroughSubject<CSCDerivedUpdate, Never>()
    private let featureSubject = CurrentValueSubject<CSCFeature?, Never>(nil)

    /// CSC Feature characteristic (0x2A5C), when read after connect. `nil` until read or if unavailable.
    public var feature: AnyPublisher<CSCFeature?, Never> {
        featureSubject.eraseToAnyPublisher()
    }

    /// Merged per-peripheral derived sample (consumed by the manager for the merged `derivedUpdates` stream).
    public var derivedUpdates: AnyPublisher<CSCDerivedUpdate, Never> {
        derivedSubject.eraseToAnyPublisher()
    }

    public var speed: AnyPublisher<Double?, Never> {
        speedSubject.eraseToAnyPublisher()
    }

    public var cadence: AnyPublisher<Double?, Never> {
        cadenceSubject.eraseToAnyPublisher()
    }

    public var distanceDelta: AnyPublisher<Double?, Never> {
        distanceDeltaSubject.eraseToAnyPublisher()
    }

    public var connectionState: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    public var wheelDiameter: AnyPublisher<Measurement<UnitLength>, Never> {
        wheelDiameterSubject.eraseToAnyPublisher()
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
        initialWheelDiameter: Measurement<UnitLength>? = nil,
        initialIsEnabled: Bool? = nil
    ) {
        self.id = id
        self.storedName = name
        self.connectionStateSubject = CurrentValueSubject(initialConnectionState)
        let defaultDiameter = Measurement(
            value: CSCKnownSensorDefaults.defaultWheelDiameterMeters,
            unit: UnitLength.meters
        )
        let wheel = initialWheelDiameter ?? defaultDiameter
        self.wheelDiameterSubject = CurrentValueSubject(wheel)
        self.isEnabledSubject = CurrentValueSubject(initialIsEnabled ?? true)
        self.calculator = CSCDeltaCalculator(
            wheelCircumferenceMeters: Self.circumferenceMeters(
                forWheelDiameter: wheel
            )
        )
        super.init()
    }

    /// Last published wheel diameter.
    public var currentWheelDiameter: Measurement<UnitLength> {
        wheelDiameterSubject.value
    }

    /// Whether CSC measurements are applied to the delta calculator and outputs.
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

    public func bind(peripheral: (any CSCPeripheral)?) {
        peripheralRef = peripheral
    }

    public func setWheelDiameter(_ value: Measurement<UnitLength>) {
        wheelDiameterSubject.send(value)
        calculator.wheelCircumferenceMeters = Self.circumferenceMeters(forWheelDiameter: value)
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
        peripheralRef?.discoverServices([Self.cscServiceUUID])
    }

    public func willEnterConnecting() {
        connectionStateSubject.send(.connecting)
    }

    public func didDisconnect() {
        connectionStateSubject.send(.disconnected)
        peripheralRef?.delegate = nil
        resetDerivedState()
    }

    /// When Bluetooth is unavailable (permission, power, reset), the UI and metrics must show disconnected
    /// without a peripheral disconnect callback (SEN-PERM-2 / SEN-PERS-4).
    public func markDisconnectedByBluetoothUnavailability() {
        didDisconnect()
    }

    /// Called when the user requests disconnect, before the central cancels the connection (matches legacy pre-clear of calculator).
    public func resetDerivedState() {
        calculator.reset()
        speedSubject.send(nil)
        cadenceSubject.send(nil)
        distanceDeltaSubject.send(nil)
        featureSubject.send(nil)
    }

    public func didFailToConnect() {
        connectionStateSubject.send(.disconnected)
    }

    // MARK: - Internals

    private static func circumferenceMeters(forWheelDiameter d: Measurement<UnitLength>) -> Double {
        d.converted(to: UnitLength.meters).value * .pi
    }

    private func processCSCData(_ data: Data) {
        guard isEnabledSubject.value else { return }
        guard case let .success(measurement) = CSCMeasurementParser.parse(data) else { return }
        guard let u = calculator.push(measurement) else { return }
        speedSubject.send(u.speedMetersPerSecond)
        cadenceSubject.send(u.cadenceRPM)
        distanceDeltaSubject.send(u.distanceDeltaMeters)
        derivedSubject.send(u)
    }
}

extension CyclingSpeedAndCadenceSensor: @MainActor CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.cscServiceUUID {
            peripheral.discoverCharacteristics([Self.cscMeasurementUUID, Self.cscFeatureUUID], for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case Self.cscMeasurementUUID:
                peripheral.setNotifyValue(true, for: characteristic)
            case Self.cscFeatureUUID:
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        switch characteristic.uuid {
        case Self.cscMeasurementUUID:
            processCSCData(data)
        case Self.cscFeatureUUID:
            featureSubject.send(CSCFeature.parse(data))
        default:
            break
        }
    }
}

// MARK: - Testable entry

extension CyclingSpeedAndCadenceSensor {
    /// Pushes raw CSC notification bytes (same path as `didUpdateValueFor`).
    internal func _test_ingestCSCMeasurementData(_ data: Data) {
        processCSCData(data)
    }

    /// Sets parsed CSC Feature (tests / composition root helpers).
    internal func _test_setFeature(_ feature: CSCFeature?) {
        featureSubject.send(feature)
    }

    internal var _test_featureSnapshot: CSCFeature? { featureSubject.value }

    internal var _test_connectionSnapshot: ConnectionState { connectionStateSubject.value }
}
