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
    private let connectedSubject = CurrentValueSubject<[ConnectedSensor], Never>([])

    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var calculatorsByID: [UUID: CSCDeltaCalculator] = [:]
    private var scanSessionEndTask: Task<Void, Never>?

    /// After this delay from `startScan()`, connects to the discovered peripheral with the strongest RSSI (if any), then stops scanning.
    public var autoConnectDelayNanoseconds: UInt64 = 3_000_000_000

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

    public var connectedSensors: AnyPublisher<[ConnectedSensor], Never> {
        connectedSubject.eraseToAnyPublisher()
    }

    /// Merged display list: discovered peripherals plus any connected entries not already in discovery (by id).
    public var knownSensorNamesPublisher: AnyPublisher<[String], Never> {
        Publishers.CombineLatest(discoveredSubject, connectedSubject)
            .map { discovered, connected in Self.mergedSensorTitles(discovered: discovered, connected: connected) }
            .eraseToAnyPublisher()
    }

    public func startScan() {
        scanSessionEndTask?.cancel()
        discoveredSubject.send([])

        guard central.state == .poweredOn else { return }

        central.scanForPeripherals(
            withServices: [cscServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        let delay = autoConnectDelayNanoseconds
        scanSessionEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            self?.finishScanSessionAndAutoConnect()
        }
    }

    public func stopScan() {
        scanSessionEndTask?.cancel()
        scanSessionEndTask = nil
        central.stopScan()
    }

    /// Connects to a peripheral previously seen during scan (or any retained peripheral).
    public func connect(to peripheralID: UUID) {
        guard let peripheral = peripheralsByID[peripheralID] else { return }
        guard central.state == .poweredOn else { return }
        updateConnectedState(id: peripheralID, name: peripheral.name ?? "Sensor", state: .connecting)
        central.connect(peripheral, options: nil)
    }

    private func finishScanSessionAndAutoConnect() {
        stopScan()
        let discovered = discoveredSubject.value
        guard let best = discovered.max(by: { $0.rssi < $1.rssi }) else { return }
        connect(to: best.id)
    }

    private static func mergedSensorTitles(
        discovered: [DiscoveredSensor],
        connected: [ConnectedSensor]
    ) -> [String] {
        var byID: [UUID: String] = [:]
        for d in discovered {
            byID[d.id] = d.name
        }
        for c in connected {
            byID[c.id] = c.name
        }
        return byID.values.sorted()
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

    private func updateConnectedState(id: UUID, name: String, state: ConnectionState) {
        var list = connectedSubject.value
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx] = ConnectedSensor(id: id, name: name, connectionState: state)
        } else {
            list.append(ConnectedSensor(id: id, name: name, connectionState: state))
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        connectedSubject.send(list)
    }

    private func removeConnected(id: UUID) {
        var list = connectedSubject.value
        list.removeAll { $0.id == id }
        connectedSubject.send(list)
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
            _ = update
            // Phase 2+ will bridge these into dashboard metrics; keep hook for future wiring.
        }
    }
}

extension BluetoothSensorManager: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Ready; scan is typically started from UI.
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
        peripheral.delegate = self
        let name = peripheral.name ?? "Cycling sensor"
        updateConnectedState(id: peripheral.identifier, name: name, state: .connected)
        peripheral.discoverServices([cscServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        updateConnectedState(
            id: peripheral.identifier,
            name: peripheral.name ?? "Cycling sensor",
            state: .disconnected
        )
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        removeConnected(id: peripheral.identifier)
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
