//
//  CyclingSpeedAndCadenceSensorManager.swift
//  CyclingSpeedAndCadenceService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

/// Owns `CBCentralManager`, CSC scan, connect, and a registry of
/// per-peripheral `CyclingSpeedAndCadenceSensor` instances (CSC service/delegate and delta state).
@MainActor
public final class CyclingSpeedAndCadenceSensorManager: NSObject {
    private let central: CBCentralManager
    private let cscServiceUUID: CBUUID

    private let discoveredSubject = CurrentValueSubject<[DiscoveredSensor], Never>([])
    private let knownSensorsSubject = CurrentValueSubject<[ConnectedSensor], Never>([])
    private let derivedUpdateSubject = PassthroughSubject<CSCDerivedUpdate, Never>()
    private let sensorsListSubject = CurrentValueSubject<[CyclingSpeedAndCadenceSensor], Never>([])

    private var sensorsByID: [UUID: CyclingSpeedAndCadenceSensor] = [:]
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var mergeCancellable: AnyCancellable?

    public override init() {
        self.cscServiceUUID = CBUUID(string: "1816")
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

    /// All per-peripheral sensor instances (for composition root / future `CompositeSensorProvider`).
    public var sensors: AnyPublisher<[CyclingSpeedAndCadenceSensor], Never> {
        sensorsListSubject.eraseToAnyPublisher()
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
        guard sensorsByID[id] == nil else { return }
        let _ = ensureSensor(id: id, name: name)
        if let retrieved = central.retrievePeripherals(withIdentifiers: [id]).first {
            peripheralsByID[id] = retrieved
            sensorsByID[id]?.bind(peripheral: retrieved)
        }
        rebuildAndPublish()
    }

    /// Connects to a peripheral previously seen during scan, retrieved via Core Bluetooth, or seeded from persistence.
    public func connect(to peripheralID: UUID) {
        guard central.state == .poweredOn else { return }
        guard let peripheral = resolvePeripheral(peripheralID: peripheralID) else { return }
        let name = peripheral.name
            ?? knownSensorsSubject.value.first(where: { $0.id == peripheralID })?.name
            ?? "Cycling sensor"
        let sensor = ensureSensor(id: peripheralID, name: name)
        if let n = peripheral.name, !n.isEmpty {
            sensor.updateName(n)
        } else {
            sensor.setNameIfNeeded(name)
        }
        sensor.bind(peripheral: peripheral)
        sensor.willEnterConnecting()
        central.connect(peripheral, options: nil)
        rebuildAndPublish()
    }

    public func disconnect(peripheralID: UUID) {
        if let s = sensorsByID[peripheralID] {
            s.resetDerivedState()
        }
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
        sensorsByID[peripheralID] = nil
        rebindDerivedMerge()
        rebuildAndPublish()
    }

    /// Call after restoring known sensors from persistence if `central` may already be `.poweredOn` before seeding.
    public func reconnectDisconnectedKnownSensorsIfPoweredOn() {
        guard central.state == .poweredOn else { return }
        reconnectKnownDisconnectedSensors(central: central)
    }

    // MARK: - Internals

    private func resolvePeripheral(peripheralID: UUID) -> CBPeripheral? {
        if let existing = peripheralsByID[peripheralID] {
            return existing
        }
        let retrieved = central.retrievePeripherals(withIdentifiers: [peripheralID])
        guard let peripheral = retrieved.first else { return nil }
        peripheralsByID[peripheralID] = peripheral
        return peripheral
    }

    private func ensureSensor(id: UUID, name: String) -> CyclingSpeedAndCadenceSensor {
        if let s = sensorsByID[id] {
            s.setNameIfNeeded(name)
            return s
        }
        let s = CyclingSpeedAndCadenceSensor(
            id: id,
            name: name,
            initialConnectionState: .disconnected
        )
        sensorsByID[id] = s
        rebindDerivedMerge()
        return s
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

    private func rebuildAndPublish() {
        let list = Array(sensorsByID.values)
            .map(\.connectedSensorSnapshot)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        knownSensorsSubject.send(list)
        let sensorsSorted = list.compactMap { s in sensorsByID[s.id] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sensorsListSubject.send(sensorsSorted)
    }

    private func rebindDerivedMerge() {
        mergeCancellable?.cancel()
        let sensors = Array(sensorsByID.values)
        guard !sensors.isEmpty else { return }
        mergeCancellable = Publishers.MergeMany(sensors.map { $0.derivedUpdates })
            .sink { [weak self] update in
                self?.derivedUpdateSubject.send(update)
            }
    }

    private func reconnectKnownDisconnectedSensors(central: CBCentralManager) {
        let disconnected = knownSensorsSubject.value.filter { $0.connectionState == .disconnected }
        guard !disconnected.isEmpty else { return }
        for known in disconnected {
            let retrieved = central.retrievePeripherals(withIdentifiers: [known.id])
            guard let peripheral = retrieved.first else { continue }
            peripheralsByID[peripheral.identifier] = peripheral
            let name = peripheral.name ?? known.name
            let csc = sensorsByID[peripheral.identifier] ?? ensureSensor(id: known.id, name: name)
            csc.updateName(name)
            csc.bind(peripheral: peripheral)
            csc.willEnterConnecting()
            central.connect(peripheral, options: nil)
        }
        rebuildAndPublish()
    }
}

extension CyclingSpeedAndCadenceSensorManager: @MainActor CBCentralManagerDelegate {
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
        let s = ensureSensor(
            id: peripheral.identifier,
            name: peripheral.name
                ?? knownSensorsSubject.value.first(where: { $0.id == peripheral.identifier })?.name
                ?? "Cycling sensor"
        )
        if let n = peripheral.name, !n.isEmpty {
            s.updateName(n)
        }
        s.bind(peripheral: peripheral)
        peripheral.delegate = s
        s.didConnect()
        rebuildAndPublish()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        sensorsByID[peripheral.identifier]?.didFailToConnect()
        rebuildAndPublish()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        sensorsByID[peripheral.identifier]?.didDisconnect()
        rebuildAndPublish()
    }
}

// MARK: - Test hooks

extension CyclingSpeedAndCadenceSensorManager {
    /// Binds a sensor for merge/known list tests (no `CBCentralManager`).
    internal func _test_registerSensor(_ sensor: CyclingSpeedAndCadenceSensor) {
        sensorsByID[sensor.id] = sensor
        rebindDerivedMerge()
        rebuildAndPublish()
    }

    internal func _test_forgetWithoutCancel(peripheralID: UUID) {
        peripheralsByID[peripheralID] = nil
        sensorsByID[peripheralID] = nil
        rebindDerivedMerge()
        rebuildAndPublish()
    }
}
