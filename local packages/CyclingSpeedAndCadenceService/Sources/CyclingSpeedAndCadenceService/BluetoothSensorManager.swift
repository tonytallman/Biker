//
//  BluetoothSensorManager.swift
//  CyclingSpeedAndCadenceService
//

import Combine
@preconcurrency import CoreBluetooth
import Foundation

/// Owns `CBCentralManager`, CSC scan/connect, and notification handling.
@MainActor
public final class BluetoothSensorManager: NSObject {
    private let central: CBCentralManager
    private let cscServiceUUID: CBUUID
    private let cscMeasurementUUID: CBUUID

    private let discoveredSubject = CurrentValueSubject<[DiscoveredSensor], Never>([])
    private let knownSensorsSubject = CurrentValueSubject<[ConnectedSensor], Never>([])
    private let derivedUpdateSubject = PassthroughSubject<CSCDerivedUpdate, Never>()

    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var calculatorsByID: [UUID: CSCDeltaCalculator] = [:]

    public override init() {
        self.cscServiceUUID = CBUUID(string: "1816")
        self.cscMeasurementUUID = CBUUID(string: "2A5B")
        self.central = CBCentralManager(delegate: nil, queue: .main)
        super.init()
        self.central.delegate = self
    }

    public var discoveredSensors: AnyPublisher<[DiscoveredSensor], Never> {
        discoveredSubject.eraseToAnyPublisher()
    }

    public var knownSensors: AnyPublisher<[ConnectedSensor], Never> {
        knownSensorsSubject.eraseToAnyPublisher()
    }

    /// Merged CSC-derived speed, cadence, and wheel distance deltas from all connected sensors (in arrival order).
    public var derivedUpdates: AnyPublisher<CSCDerivedUpdate, Never> {
        derivedUpdateSubject.eraseToAnyPublisher()
    }

    /// True when at least one known sensor is actively connected (BLE notifications may arrive).
    public var hasConnectedSensor: AnyPublisher<Bool, Never> {
        knownSensorsSubject
            .map { sensors in sensors.contains { $0.connectionState == .connected } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func startScan() {
        discoveredSubject.send([])

        guard central.state == .poweredOn else { return }

        central.scanForPeripherals(
            withServices: [cscServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    public func stopScan() {
        central.stopScan()
    }

    /// Restores a known sensor from persistence without connecting (disconnected until user connects or auto-reconnect runs).
    public func seedKnownSensor(id: UUID, name: String) {
        guard !knownSensorsSubject.value.contains(where: { $0.id == id }) else { return }
        updateKnownState(id: id, name: name, state: .disconnected)
    }

    /// Connects to a peripheral previously seen during scan, retrieved via Core Bluetooth, or seeded from persistence.
    public func connect(to peripheralID: UUID) {
        guard central.state == .poweredOn else { return }
        guard let peripheral = resolvePeripheral(peripheralID: peripheralID) else { return }
        let name = peripheral.name ?? knownSensorsSubject.value.first(where: { $0.id == peripheralID })?.name ?? "Cycling sensor"
        updateKnownState(id: peripheralID, name: name, state: .connecting)
        central.connect(peripheral, options: nil)
    }

    public func disconnect(peripheralID: UUID) {
        calculatorsByID[peripheralID] = nil
        guard let peripheral = resolvePeripheral(peripheralID: peripheralID) else { return }
        guard peripheral.state == .connected || peripheral.state == .connecting else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    public func forget(peripheralID: UUID) {
        if let peripheral = resolvePeripheral(peripheralID: peripheralID) {
            if peripheral.state == .connected || peripheral.state == .connecting {
                central.cancelPeripheralConnection(peripheral)
            }
        }
        peripheralsByID[peripheralID] = nil
        calculatorsByID[peripheralID] = nil
        removeKnown(id: peripheralID)
    }

    /// Call after restoring known sensors from persistence if `central` may already be `.poweredOn` before seeding.
    public func reconnectDisconnectedKnownSensorsIfPoweredOn() {
        guard central.state == .poweredOn else { return }
        reconnectKnownDisconnectedSensors(central: central)
    }

    private func resolvePeripheral(peripheralID: UUID) -> CBPeripheral? {
        if let existing = peripheralsByID[peripheralID] {
            return existing
        }
        let retrieved = central.retrievePeripherals(withIdentifiers: [peripheralID])
        guard let peripheral = retrieved.first else { return nil }
        peripheralsByID[peripheralID] = peripheral
        return peripheral
    }

    private func upsertDiscovered(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let id = peripheral.identifier
        peripheralsByID[id] = peripheral
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Cycling sensor"
        let rssiValue = rssi.intValue
        var list = discoveredSubject.value
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx] = DiscoveredSensor(id: id, name: name, rssi: rssiValue)
        } else {
            list.append(DiscoveredSensor(id: id, name: name, rssi: rssiValue))
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        discoveredSubject.send(list)
    }

    private func updateKnownState(id: UUID, name: String, state: ConnectionState) {
        var list = knownSensorsSubject.value
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx] = ConnectedSensor(id: id, name: name, connectionState: state)
        } else {
            list.append(ConnectedSensor(id: id, name: name, connectionState: state))
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        knownSensorsSubject.send(list)
    }

    private func removeKnown(id: UUID) {
        var list = knownSensorsSubject.value
        list.removeAll { $0.id == id }
        knownSensorsSubject.send(list)
    }

    private func reconnectKnownDisconnectedSensors(central: CBCentralManager) {
        let disconnected = knownSensorsSubject.value.filter { $0.connectionState == .disconnected }
        guard !disconnected.isEmpty else { return }
        for sensor in disconnected {
            let retrieved = central.retrievePeripherals(withIdentifiers: [sensor.id])
            guard let peripheral = retrieved.first else { continue }
            peripheralsByID[peripheral.identifier] = peripheral
            let name = peripheral.name ?? sensor.name
            updateKnownState(id: peripheral.identifier, name: name, state: .connecting)
            central.connect(peripheral, options: nil)
        }
    }

    private func ensureCalculator(for id: UUID) -> CSCDeltaCalculator {
        if let existing = calculatorsByID[id] { return existing }
        let calc = CSCDeltaCalculator()
        calculatorsByID[id] = calc
        return calc
    }

    private func handleCSCMeasurementData(_ data: Data, peripheralID: UUID) {
        guard case let .success(measurement) = CSCMeasurementParser.parse(data) else { return }
        var calculator = ensureCalculator(for: peripheralID)
        let update = calculator.push(measurement)
        calculatorsByID[peripheralID] = calculator
        if let update {
            derivedUpdateSubject.send(update)
        }
    }
}

extension BluetoothSensorManager: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            reconnectKnownDisconnectedSensors(central: central)
        } else {
            stopScan()
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        upsertDiscovered(peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheralsByID[peripheral.identifier] = peripheral
        peripheral.delegate = self
        let name = peripheral.name ?? knownSensorsSubject.value.first(where: { $0.id == peripheral.identifier })?.name ?? "Cycling sensor"
        updateKnownState(id: peripheral.identifier, name: name, state: .connected)
        peripheral.discoverServices([cscServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? knownSensorsSubject.value.first(where: { $0.id == peripheral.identifier })?.name ?? "Cycling sensor"
        updateKnownState(
            id: peripheral.identifier,
            name: name,
            state: .disconnected
        )
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? knownSensorsSubject.value.first(where: { $0.id == peripheral.identifier })?.name ?? "Cycling sensor"
        updateKnownState(id: peripheral.identifier, name: name, state: .disconnected)
        calculatorsByID[peripheral.identifier] = nil
    }
}

extension BluetoothSensorManager: @MainActor CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == cscServiceUUID {
            peripheral.discoverCharacteristics([cscMeasurementUUID], for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == cscMeasurementUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, characteristic.uuid == cscMeasurementUUID, let data = characteristic.value else { return }
        handleCSCMeasurementData(data, peripheralID: peripheral.identifier)
    }
}
