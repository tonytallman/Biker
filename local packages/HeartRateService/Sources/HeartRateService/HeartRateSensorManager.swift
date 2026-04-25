//
//  HeartRateSensorManager.swift
//  HeartRateService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

/// Owns a `CBCentralManager` (or test double) through `HRCentralManaging`, HR scan, connect, and a registry of
/// per-peripheral `HeartRateSensor` instances.
@MainActor
public final class HeartRateSensorManager: NSObject {
    private let central: any HRCentralManaging
    private let hrServiceUUID: CBUUID
    private let store: HRKnownSensorStore

    private let discoveredSubject = CurrentValueSubject<[DiscoveredSensor], Never>([])
    private let knownSensorsSubject = CurrentValueSubject<[ConnectedSensor], Never>([])
    private let sensorsListSubject = CurrentValueSubject<[HeartRateSensor], Never>([])
    private let availabilitySubject: CurrentValueSubject<HRBluetoothAvailability, Never>

    private let mergedHeartRateSubject = PassthroughSubject<Measurement<UnitFrequency>, Never>()
    private var heartRateMergeCancellable: AnyCancellable?

    private var sensorsByID: [UUID: HeartRateSensor] = [:]
    private var peripheralsByID: [UUID: any HRPeripheral] = [:]
    private var storeValueCancellables = Set<AnyCancellable>()

    public init(persistence: any Storage) {
        self.hrServiceUUID = CBUUID(string: "180D")
        let core = CBCentralManager(delegate: nil, queue: .main)
        self.central = RealHRCentral(core: core)
        self.store = HRKnownSensorStore(persistence: persistence)
        self.availabilitySubject = CurrentValueSubject(
            HRBluetoothAvailabilityReducer.reduce(authorization: type(of: core).authorization, state: core.state)
        )
        super.init()
        if let c = (self.central as? RealHRCentral)?.core {
            c.delegate = self
        } else {
            assertionFailure("Expected RealHRCentral in production init")
        }
        for record in self.store.loadAll() {
            installSensorFromLoadedRecord(record)
        }
        rebindMetricMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    public init(persistence: any Storage, central: any HRCentralManaging) {
        self.hrServiceUUID = CBUUID(string: "180D")
        self.central = central
        self.store = HRKnownSensorStore(persistence: persistence)
        self.availabilitySubject = CurrentValueSubject(
            HRBluetoothAvailabilityReducer.reduce(authorization: central.authorization, state: central.state)
        )
        super.init()
        for record in self.store.loadAll() {
            installSensorFromLoadedRecord(record)
        }
        if let c = (self.central as? RealHRCentral)?.core {
            c.delegate = self
        }
        rebindMetricMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    public var discoveredSensors: AnyPublisher<[DiscoveredSensor], Never> {
        discoveredSubject.eraseToAnyPublisher()
    }

    public var knownSensors: AnyPublisher<[ConnectedSensor], Never> {
        knownSensorsSubject.eraseToAnyPublisher()
    }

    public var heartRate: AnyPublisher<Measurement<UnitFrequency>, Never> {
        mergedHeartRateSubject.eraseToAnyPublisher()
    }

    public var hasConnectedSensor: AnyPublisher<Bool, Never> {
        knownSensorsSubject
            .map { sensors in sensors.contains { $0.connectionState == .connected } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var sensors: AnyPublisher<[HeartRateSensor], Never> {
        sensorsListSubject.eraseToAnyPublisher()
    }

    public var bluetoothAvailability: AnyPublisher<HRBluetoothAvailability, Never> {
        availabilitySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func heartRateSensor(for id: UUID) -> HeartRateSensor? {
        sensorsByID[id]
    }

    public func setEnabled(peripheralID: UUID, _ enabled: Bool) {
        sensorsByID[peripheralID]?.setEnabled(enabled)
    }

    public func startScan() {
        discoveredSubject.send([])

        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }

        central.scanForPeripherals(
            withServices: [hrServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    public func stopScan() {
        central.stopScan()
    }

    public func connect(to peripheralID: UUID) {
        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        guard let peripheral = resolvePeripheral(peripheralID: peripheralID) else { return }
        let name = peripheral.name
            ?? knownSensorsSubject.value.first(where: { $0.id == peripheralID })?.name
            ?? "Heart rate"
        let sensor = ensureSensor(id: peripheralID, name: name, persistIfNew: true)
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
        store.remove(id: peripheralID)
        peripheralsByID[peripheralID] = nil
        sensorsByID[peripheralID] = nil
        rebindMetricMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    public func reconnectDisconnectedKnownSensorsIfPoweredOn() {
        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        reconnectKnownDisconnectedSensors()
        rebuildAndPublish()
    }

    internal func handleBluetoothStateChange() {
        let newAvailability = HRBluetoothAvailabilityReducer.reduce(
            authorization: central.authorization,
            state: central.state
        )
        let previous = availabilitySubject.value
        if newAvailability != previous {
            availabilitySubject.send(newAvailability)
        }

        if newAvailability != .poweredOn {
            stopScan()
            discoveredSubject.send([])
            markAllKnownSensorsDisconnectedByPolicy()
            rebuildAndPublish()
        } else if previous != .poweredOn {
            reconnectKnownDisconnectedSensors()
            rebuildAndPublish()
        }
    }

    private func markAllKnownSensorsDisconnectedByPolicy() {
        for s in sensorsByID.values {
            s.markDisconnectedByBluetoothUnavailability()
        }
    }

    private func makeRecord(from sensor: HeartRateSensor) -> HRKnownSensorRecord {
        HRKnownSensorRecord(
            id: sensor.id,
            name: sensor.name,
            sensorType: HRKnownSensorType.heartRate.rawValue,
            isEnabled: sensor.isEnabledValue
        )
    }

    private func installSensorFromLoadedRecord(_ record: HRKnownSensorRecord) {
        guard sensorsByID[record.id] == nil else { return }
        let s = HeartRateSensor(
            id: record.id,
            name: record.name,
            initialConnectionState: .disconnected,
            initialIsEnabled: record.isEnabled
        )
        sensorsByID[record.id] = s
        if let retrieved = central.retrievePeripherals(withIdentifiers: [record.id]).first {
            peripheralsByID[record.id] = retrieved
            s.bind(peripheral: retrieved)
        }
    }

    private func resolvePeripheral(peripheralID: UUID) -> (any HRPeripheral)? {
        if let existing = peripheralsByID[peripheralID] {
            return existing
        }
        let retrieved = central.retrievePeripherals(withIdentifiers: [peripheralID])
        guard let peripheral = retrieved.first else { return nil }
        peripheralsByID[peripheralID] = peripheral
        return peripheral
    }

    private func ensureSensor(id: UUID, name: String, persistIfNew: Bool) -> HeartRateSensor {
        if let s = sensorsByID[id] {
            s.setNameIfNeeded(name)
            return s
        }
        let s = HeartRateSensor(
            id: id,
            name: name,
            initialConnectionState: .disconnected
        )
        sensorsByID[id] = s
        rebindMetricMerge()
        rebindStoreSubscriptions()
        if persistIfNew {
            store.upsert(makeRecord(from: s))
        }
        return s
    }

    private func upsertDiscovered(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let id = peripheral.identifier
        peripheralsByID[id] = peripheral
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Heart rate"
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
        for s in sensorsByID.values {
            store.upsert(makeRecord(from: s))
        }
    }

    private func rebindMetricMerge() {
        heartRateMergeCancellable?.cancel()
        let sensors = Array(sensorsByID.values)
        guard !sensors.isEmpty else {
            heartRateMergeCancellable = nil
            return
        }
        heartRateMergeCancellable = Publishers.MergeMany(sensors.map { $0.bpm })
            .sink { [weak self] value in
                self?.mergedHeartRateSubject.send(value)
            }
    }

    private func rebindStoreSubscriptions() {
        storeValueCancellables = []
        for (id, s) in sensorsByID {
            s.isEnabled
                .dropFirst(1)
                .sink { [weak self] _ in
                    guard let self else { return }
                    guard let sensor = self.sensorsByID[id] else { return }
                    self.store.upsert(self.makeRecord(from: sensor))
                }
                .store(in: &storeValueCancellables)
        }
    }

    private func reconnectKnownDisconnectedSensors() {
        let known = knownSensorsSubject.value
        let toReconnect = known.filter { k in
            k.connectionState == .disconnected && (sensorsByID[k.id]?.isEnabledValue ?? true)
        }
        guard !toReconnect.isEmpty else { return }
        for known in toReconnect {
            let retrieved = central.retrievePeripherals(withIdentifiers: [known.id])
            guard let peripheral = retrieved.first else { continue }
            peripheralsByID[peripheral.identifier] = peripheral
            let name = peripheral.name ?? known.name
            let sensor = sensorsByID[peripheral.identifier] ?? ensureSensor(id: known.id, name: name, persistIfNew: true)
            sensor.updateName(name)
            sensor.bind(peripheral: peripheral)
            sensor.willEnterConnecting()
            central.connect(peripheral, options: nil)
        }
    }
}

extension HeartRateSensorManager: @MainActor CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_: CBCentralManager) {
        handleBluetoothStateChange()
    }

    public func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        upsertDiscovered(peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    public func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheralsByID[peripheral.identifier] = peripheral
        let s = ensureSensor(
            id: peripheral.identifier,
            name: peripheral.name
                ?? knownSensorsSubject.value.first(where: { $0.id == peripheral.identifier })?.name
                ?? "Heart rate",
            persistIfNew: true
        )
        if let n = peripheral.name, !n.isEmpty {
            s.updateName(n)
        }
        s.bind(peripheral: peripheral)
        peripheral.delegate = s
        s.didConnect()
        rebuildAndPublish()
    }

    public func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        sensorsByID[peripheral.identifier]?.didFailToConnect()
        rebuildAndPublish()
    }

    public func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        sensorsByID[peripheral.identifier]?.didDisconnect()
        rebuildAndPublish()
    }
}

extension HeartRateSensorManager {
    internal func _test_registerSensor(_ sensor: HeartRateSensor) {
        sensorsByID[sensor.id] = sensor
        rebindMetricMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    internal func _test_forgetWithoutCancel(peripheralID: UUID) {
        store.remove(id: peripheralID)
        peripheralsByID[peripheralID] = nil
        sensorsByID[peripheralID] = nil
        rebindMetricMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    /// Publishes a discovered row snapshot (e.g. DependencyContainer integration tests, no GATT).
    internal func _test_publishDiscovered(_ sensors: [DiscoveredSensor]) {
        discoveredSubject.send(sensors)
    }
}
