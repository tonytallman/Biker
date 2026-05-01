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
    private var suppressAutoReconnectPeripheralIDs: Set<UUID> = []
    private var userScanActive = false
    private var backgroundScanActive = false
    private var skipAutoReconnectForPeripheralID: UUID?

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
        if enabled {
            reconnectDisconnectedKnownSensorsIfPoweredOn()
        } else {
            disconnect(peripheralID: peripheralID)
        }
    }

    public func startScan() {
        discoveredSubject.send([])

        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        userScanActive = true
        startCentralScanIfNeeded()
    }

    public func stopScan() {
        userScanActive = false
        stopCentralScanIfIdle()
    }

    private func startCentralScanIfNeeded() {
        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        guard userScanActive || backgroundScanActive else { return }
        central.scanForPeripherals(
            withServices: [hrServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func stopCentralScanIfIdle() {
        guard !userScanActive && !backgroundScanActive else { return }
        central.stopScan()
    }

    public func connect(to peripheralID: UUID) {
        suppressAutoReconnectPeripheralIDs.remove(peripheralID)
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
        suppressAutoReconnectPeripheralIDs.insert(peripheralID)
        if let s = sensorsByID[peripheralID] {
            s.resetDerivedState()
        }
        guard let peripheral = resolvePeripheral(peripheralID: peripheralID) else {
            suppressAutoReconnectPeripheralIDs.remove(peripheralID)
            return
        }
        guard peripheral.state == .connected || peripheral.state == .connecting else {
            suppressAutoReconnectPeripheralIDs.remove(peripheralID)
            return
        }
        central.cancelPeripheralConnection(peripheral)
    }

    public func forget(peripheralID: UUID) {
        suppressAutoReconnectPeripheralIDs.remove(peripheralID)
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
            userScanActive = false
            backgroundScanActive = false
            skipAutoReconnectForPeripheralID = nil
            central.stopScan()
            discoveredSubject.send([])
            markAllKnownSensorsDisconnectedByPolicy()
            rebuildAndPublish()
        } else if previous != .poweredOn {
            reconnectDisconnectedKnownSensorsIfPoweredOn()
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
        publishDiscoveredRow(id: id, name: name, rssi: rssi.intValue)
        attemptAutoConnectFromDiscovery(peripheral: peripheral as any HRPeripheral)
    }

    private func publishDiscoveredRow(id: UUID, name: String, rssi: Int) {
        var list = discoveredSubject.value
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx] = DiscoveredSensor(id: id, name: name, rssi: rssi)
        } else {
            list.append(DiscoveredSensor(id: id, name: name, rssi: rssi))
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        discoveredSubject.send(list)
    }

    private func attemptAutoConnectFromDiscovery(peripheral: any HRPeripheral) {
        guard backgroundScanActive else { return }
        guard !hasAnySensorConnectingOrConnected else {
            backgroundScanActive = false
            stopCentralScanIfIdle()
            return
        }
        let id = peripheral.identifier

        if let skip = skipAutoReconnectForPeripheralID {
            if skip == id { return }
            if sensorsByID[id] != nil {
                skipAutoReconnectForPeripheralID = nil
            }
        }

        guard let sensor = sensorsByID[id], sensor.isEnabledValue,
              sensor.connectedSensorSnapshot.connectionState == .disconnected else { return }

        if let n = peripheral.name, !n.isEmpty {
            sensor.updateName(n)
        }
        sensor.bind(peripheral: peripheral)
        sensor.willEnterConnecting()
        central.connect(peripheral, options: nil)

        backgroundScanActive = false
        stopCentralScanIfIdle()
        rebuildAndPublish()
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
        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        guard !hasAnySensorConnectingOrConnected else { return }

        let hasEligible = sensorsByID.values.contains {
            $0.connectedSensorSnapshot.connectionState == .disconnected && $0.isEnabledValue
        }
        guard hasEligible else { return }

        backgroundScanActive = true
        startCentralScanIfNeeded()
    }

    private var hasAnySensorConnectingOrConnected: Bool {
        sensorsByID.values.contains {
            switch $0.connectedSensorSnapshot.connectionState {
            case .connecting, .connected: true
            case .disconnected: false
            }
        }
    }

    private func resumeAutoReconnectUnlessUserDisconnected(peripheralID: UUID) {
        if suppressAutoReconnectPeripheralIDs.remove(peripheralID) != nil {
            return
        }
        reconnectDisconnectedKnownSensorsIfPoweredOn()
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
        skipAutoReconnectForPeripheralID = nil
        backgroundScanActive = false
        stopCentralScanIfIdle()
        rebuildAndPublish()
    }

    public func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        skipAutoReconnectForPeripheralID = peripheral.identifier
        sensorsByID[peripheral.identifier]?.didFailToConnect()
        rebuildAndPublish()
        reconnectDisconnectedKnownSensorsIfPoweredOn()
    }

    public func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let id = peripheral.identifier
        sensorsByID[id]?.didDisconnect()
        rebuildAndPublish()
        resumeAutoReconnectUnlessUserDisconnected(peripheralID: id)
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

    /// Mirrors `centralManager(_:didDisconnectPeripheral:error:)` without `CBPeripheral` (unit tests).
    internal func _test_simulateDidDisconnect(peripheralID: UUID) {
        sensorsByID[peripheralID]?.didDisconnect()
        rebuildAndPublish()
        resumeAutoReconnectUnlessUserDisconnected(peripheralID: peripheralID)
    }

    internal func _test_simulateDidFailToConnect(peripheralID: UUID) {
        skipAutoReconnectForPeripheralID = peripheralID
        sensorsByID[peripheralID]?.didFailToConnect()
        rebuildAndPublish()
        reconnectDisconnectedKnownSensorsIfPoweredOn()
    }

    internal func _test_simulateDidDiscover(peripheralID: UUID, name: String, rssi: Int = -50) {
        let peripheral: any HRPeripheral
        if let existing = peripheralsByID[peripheralID] {
            peripheral = existing
        } else if let resolved = resolvePeripheral(peripheralID: peripheralID) {
            peripheral = resolved
        } else {
            return
        }
        publishDiscoveredRow(id: peripheralID, name: name, rssi: rssi)
        attemptAutoConnectFromDiscovery(peripheral: peripheral)
    }

    /// Publishes a discovered row snapshot (e.g. DependencyContainer integration tests, no GATT).
    internal func _test_publishDiscovered(_ sensors: [DiscoveredSensor]) {
        discoveredSubject.send(sensors)
    }
}
