//
//  FitnessMachineSensorManager.swift
//  FitnessMachineService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

/// Owns a `CBCentralManager` (or test double) through `FTMSCentralManaging`, FTMS scan, connect, and a registry of
/// per-peripheral `FitnessMachineSensor` instances.
@MainActor
public final class FitnessMachineSensorManager: NSObject {
    private let central: any FTMSCentralManaging
    private let ftmsServiceUUID: CBUUID
    private let store: FTMSKnownSensorStore

    private let discoveredSubject = CurrentValueSubject<[DiscoveredSensor], Never>([])
    private let knownSensorsSubject = CurrentValueSubject<[ConnectedSensor], Never>([])
    private let sensorsListSubject = CurrentValueSubject<[FitnessMachineSensor], Never>([])
    private let availabilitySubject: CurrentValueSubject<FTMSBluetoothAvailability, Never>

    private let mergedSpeedSubject = PassthroughSubject<Measurement<UnitSpeed>, Never>()
    private let mergedCadenceSubject = PassthroughSubject<Measurement<UnitFrequency>, Never>()
    private var speedMergeCancellable: AnyCancellable?
    private var cadenceMergeCancellable: AnyCancellable?

    private var sensorsByID: [UUID: FitnessMachineSensor] = [:]
    private var peripheralsByID: [UUID: any FTMSPeripheral] = [:]
    private var storeValueCancellables = Set<AnyCancellable>()

    public init(persistence: any FTMSPersistence) {
        self.ftmsServiceUUID = CBUUID(string: "1826")
        let core = CBCentralManager(delegate: nil, queue: .main)
        self.central = RealFTMSCentral(core: core)
        self.store = FTMSKnownSensorStore(persistence: persistence)
        self.availabilitySubject = CurrentValueSubject(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: type(of: core).authorization, state: core.state)
        )
        super.init()
        if let c = (self.central as? RealFTMSCentral)?.core {
            c.delegate = self
        } else {
            assertionFailure("Expected RealFTMSCentral in production init")
        }
        for record in self.store.loadAll() {
            installSensorFromLoadedRecord(record)
        }
        rebindMetricMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    public init(persistence: any FTMSPersistence, central: any FTMSCentralManaging) {
        self.ftmsServiceUUID = CBUUID(string: "1826")
        self.central = central
        self.store = FTMSKnownSensorStore(persistence: persistence)
        self.availabilitySubject = CurrentValueSubject(
            FTMSBluetoothAvailabilityReducer.reduce(authorization: central.authorization, state: central.state)
        )
        super.init()
        for record in self.store.loadAll() {
            installSensorFromLoadedRecord(record)
        }
        if let c = (self.central as? RealFTMSCentral)?.core {
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

    public var speed: AnyPublisher<Measurement<UnitSpeed>, Never> {
        mergedSpeedSubject.eraseToAnyPublisher()
    }

    public var cadence: AnyPublisher<Measurement<UnitFrequency>, Never> {
        mergedCadenceSubject.eraseToAnyPublisher()
    }

    public var hasConnectedSensor: AnyPublisher<Bool, Never> {
        knownSensorsSubject
            .map { sensors in sensors.contains { $0.connectionState == .connected } }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var sensors: AnyPublisher<[FitnessMachineSensor], Never> {
        sensorsListSubject.eraseToAnyPublisher()
    }

    public var bluetoothAvailability: AnyPublisher<FTMSBluetoothAvailability, Never> {
        availabilitySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func ftmsSensor(for id: UUID) -> FitnessMachineSensor? {
        sensorsByID[id]
    }

    public func setEnabled(peripheralID: UUID, _ enabled: Bool) {
        sensorsByID[peripheralID]?.setEnabled(enabled)
    }

    public func startScan() {
        discoveredSubject.send([])

        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }

        central.scanForPeripherals(
            withServices: [ftmsServiceUUID],
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
            ?? "Fitness machine"
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
        let newAvailability = FTMSBluetoothAvailabilityReducer.reduce(
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

    private func makeRecord(from sensor: FitnessMachineSensor) -> FTMSKnownSensorRecord {
        FTMSKnownSensorRecord(
            id: sensor.id,
            name: sensor.name,
            sensorType: FTMSKnownSensorType.fitnessMachine.rawValue,
            isEnabled: sensor.isEnabledValue
        )
    }

    private func installSensorFromLoadedRecord(_ record: FTMSKnownSensorRecord) {
        guard sensorsByID[record.id] == nil else { return }
        let s = FitnessMachineSensor(
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

    private func resolvePeripheral(peripheralID: UUID) -> (any FTMSPeripheral)? {
        if let existing = peripheralsByID[peripheralID] {
            return existing
        }
        let retrieved = central.retrievePeripherals(withIdentifiers: [peripheralID])
        guard let peripheral = retrieved.first else { return nil }
        peripheralsByID[peripheralID] = peripheral
        return peripheral
    }

    private func ensureSensor(id: UUID, name: String, persistIfNew: Bool) -> FitnessMachineSensor {
        if let s = sensorsByID[id] {
            s.setNameIfNeeded(name)
            return s
        }
        let s = FitnessMachineSensor(
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
            ?? "Fitness machine"
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
        speedMergeCancellable?.cancel()
        cadenceMergeCancellable?.cancel()
        let sensors = Array(sensorsByID.values)
        guard !sensors.isEmpty else {
            speedMergeCancellable = nil
            cadenceMergeCancellable = nil
            return
        }
        speedMergeCancellable = Publishers.MergeMany(sensors.map { $0.speed })
            .sink { [weak self] value in
                self?.mergedSpeedSubject.send(value)
            }
        cadenceMergeCancellable = Publishers.MergeMany(sensors.map { $0.cadence })
            .sink { [weak self] value in
                self?.mergedCadenceSubject.send(value)
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

extension FitnessMachineSensorManager: @MainActor CBCentralManagerDelegate {
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
                ?? "Fitness machine",
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

extension FitnessMachineSensorManager {
    internal func _test_registerSensor(_ sensor: FitnessMachineSensor) {
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
