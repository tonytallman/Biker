//
//  CyclingSpeedAndCadenceSensorManager.swift
//  CyclingSpeedAndCadenceService
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation

/// Owns a `CBCentralManager` (or test double) through `CSCCentralManaging`, CSC scan, connect, and a registry of
/// per-peripheral `CyclingSpeedAndCadenceSensor` instances (CSC service/delegate and delta state).
@MainActor
public final class CyclingSpeedAndCadenceSensorManager: NSObject {
    private let central: any CSCCentralManaging
    private let cscServiceUUID: CBUUID
    private let store: CSCKnownSensorStore

    private let discoveredSubject = CurrentValueSubject<[DiscoveredSensor], Never>([])
    private let knownSensorsSubject = CurrentValueSubject<[ConnectedSensor], Never>([])
    private let derivedUpdateSubject = PassthroughSubject<CSCDerivedUpdate, Never>()
    private let sensorsListSubject = CurrentValueSubject<[CyclingSpeedAndCadenceSensor], Never>([])
    private let availabilitySubject: CurrentValueSubject<CSCBluetoothAvailability, Never>

    private var sensorsByID: [UUID: CyclingSpeedAndCadenceSensor] = [:]
    private var peripheralsByID: [UUID: any CSCPeripheral] = [:]
    private var mergeCancellable: AnyCancellable?
    private var storeValueCancellables = Set<AnyCancellable>()
    private let dualCapableSubject = CurrentValueSubject<UUID?, Never>(nil)
    private var dualCapableCancellables = Set<AnyCancellable>()
    /// User-initiated disconnect; avoids immediate auto-reconnect when `didDisconnectPeripheral` fires.
    private var suppressAutoReconnectPeripheralIDs: Set<UUID> = []

    /// Scan sheet vs background reconnect (`CompositeSensorProvider` calls both managers).
    private var userScanActive = false
    private var backgroundScanActive = false
    /// Skip immediate reconnect-from-discovery for this peripheral until another known peripheral advertises.
    private var skipAutoReconnectForPeripheralID: UUID?

    /// Production: persist known sensors via default JSON-backed `Storage` implementation in this module.
    public convenience init(storage: Storage) {
        let persistence = DefaultCSCKnownSensorPersistence(storage: storage)
        let core = CBCentralManager(delegate: nil, queue: .main)
        let central = RealCSCCentral(core: core)
        self.init(persistence: persistence, central: central)
    }

    /// Tests / previews: mock persistence with a real main-queue `CBCentralManager`.
    internal convenience init(persistence: any CSCKnownSensorPersistence) {
        let core = CBCentralManager(delegate: nil, queue: .main)
        let central = RealCSCCentral(core: core)
        self.init(persistence: persistence, central: central)
    }

    /// Designated internal: inject `CSCKnownSensorPersistence` and `CSCCentralManaging` (e.g. `FakeCSCCentral` in tests).
    internal init(persistence: any CSCKnownSensorPersistence, central: any CSCCentralManaging) {
        self.cscServiceUUID = CBUUID(string: "1816")
        self.central = central
        self.store = CSCKnownSensorStore(persistence: persistence)
        self.availabilitySubject = CurrentValueSubject(
            CSCBluetoothAvailabilityReducer.reduce(authorization: central.authorization, state: central.state)
        )
        super.init()
        for record in self.store.loadAll() {
            installSensorFromLoadedRecord(record)
        }
        if let c = (self.central as? RealCSCCentral)?.core {
            c.delegate = self
        }
        rebindDerivedMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
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

    /// Among connected sensors whose CSC Feature reports both wheel and crank support, the lexicographically
    /// smallest `UUID.uuidString` (ADR-0006 / SEN-TYP-5). `nil` if none or until Feature is read.
    public var dualCapableSensor: AnyPublisher<UUID?, Never> {
        dualCapableSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public var bluetoothAvailability: AnyPublisher<CSCBluetoothAvailability, Never> {
        availabilitySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    // MARK: - Public bridge for the composition root

    public func cscSensor(for id: UUID) -> CyclingSpeedAndCadenceSensor? {
        sensorsByID[id]
    }

    public func setWheelDiameter(peripheralID: UUID, _ value: Measurement<UnitLength>) {
        sensorsByID[peripheralID]?.setWheelDiameter(value)
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
            withServices: [cscServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func stopCentralScanIfIdle() {
        guard !userScanActive && !backgroundScanActive else { return }
        central.stopScan()
    }

    /// Connects to a peripheral previously seen during scan, retrieved via Core Bluetooth, or known from the store.
    public func connect(to peripheralID: UUID) {
        suppressAutoReconnectPeripheralIDs.remove(peripheralID)
        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        guard let peripheral = resolvePeripheral(peripheralID: peripheralID) else { return }
        let name = peripheral.name
            ?? knownSensorsSubject.value.first(where: { $0.id == peripheralID })?.name
            ?? "Cycling sensor"
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
        rebindDerivedMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    /// Call after restoring known sensors from persistence if `central` may already be `.poweredOn` before the first delegate callback.
    public func reconnectDisconnectedKnownSensorsIfPoweredOn() {
        guard availabilitySubject.value == .poweredOn, central.state == .poweredOn else { return }
        reconnectKnownDisconnectedSensors()
        rebuildAndPublish()
    }

    // MARK: - Bluetooth state (tests + `CBCentralManagerDelegate`)

    /// Recomputes `bluetoothAvailability` and applies scan / disconnect / auto-reconnect policy (SEN-PERM-2, SEN-PERS-3/4/5).
    internal func handleBluetoothStateChange() {
        let newAvailability = CSCBluetoothAvailabilityReducer.reduce(
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

    // MARK: - Internals

    private func makeRecord(from sensor: CyclingSpeedAndCadenceSensor) -> CSCKnownSensorRecord {
        CSCKnownSensorRecord(
            id: sensor.id,
            name: sensor.name,
            sensorType: CSCKnownSensorType.cyclingSpeedAndCadence.rawValue,
            isEnabled: sensor.isEnabledValue,
            wheelDiameterMeters: sensor.currentWheelDiameter.converted(to: UnitLength.meters).value
        )
    }

    private func installSensorFromLoadedRecord(_ record: CSCKnownSensorRecord) {
        guard sensorsByID[record.id] == nil else { return }
        let wheel = Measurement(value: record.wheelDiameterMeters, unit: UnitLength.meters)
        let s = CyclingSpeedAndCadenceSensor(
            id: record.id,
            name: record.name,
            initialConnectionState: .disconnected,
            initialWheelDiameter: wheel,
            initialIsEnabled: record.isEnabled
        )
        sensorsByID[record.id] = s
        if let retrieved = central.retrievePeripherals(withIdentifiers: [record.id]).first {
            peripheralsByID[record.id] = retrieved
            s.bind(peripheral: retrieved)
        }
    }

    private func resolvePeripheral(peripheralID: UUID) -> (any CSCPeripheral)? {
        if let existing = peripheralsByID[peripheralID] {
            return existing
        }
        let retrieved = central.retrievePeripherals(withIdentifiers: [peripheralID])
        guard let peripheral = retrieved.first else { return nil }
        peripheralsByID[peripheralID] = peripheral
        return peripheral
    }

    private func ensureSensor(id: UUID, name: String, persistIfNew: Bool) -> CyclingSpeedAndCadenceSensor {
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
            ?? "Cycling sensor"
        publishDiscoveredRow(id: id, name: name, rssi: rssi.intValue)
        attemptAutoConnectFromDiscovery(peripheral: peripheral as any CSCPeripheral)
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

    private func attemptAutoConnectFromDiscovery(peripheral: any CSCPeripheral) {
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
        rebindDualCapableSubscriptions()
    }

    private func rebindDerivedMerge() {
        mergeCancellable?.cancel()
        let sensors = Array(sensorsByID.values)
        guard !sensors.isEmpty else {
            mergeCancellable = nil
            return
        }
        mergeCancellable = Publishers.MergeMany(sensors.map { $0.derivedUpdates })
            .sink { [weak self] update in
                self?.derivedUpdateSubject.send(update)
            }
    }

    private func rebindDualCapableSubscriptions() {
        dualCapableCancellables.removeAll()
        for s in sensorsByID.values {
            Publishers.CombineLatest(s.connectionState, s.feature)
                .sink { [weak self] _, _ in
                    self?.publishDualCapableSensor()
                }
                .store(in: &dualCapableCancellables)
        }
        publishDualCapableSensor()
    }

    private func publishDualCapableSensor() {
        let candidates = sensorsByID.values.filter { sensor in
            sensor._test_connectionSnapshot == .connected
                && sensor._test_featureSnapshot?.isDualCapable == true
        }
        let sorted = candidates.map(\.id).sorted { $0.uuidString < $1.uuidString }
        dualCapableSubject.send(sorted.first)
    }

    private func rebindStoreSubscriptions() {
        storeValueCancellables = []
        for (id, s) in sensorsByID {
            s.wheelDiameter
                .combineLatest(s.isEnabled)
                .dropFirst(1)
                .sink { [weak self] _, _ in
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

extension CyclingSpeedAndCadenceSensorManager: @MainActor CBCentralManagerDelegate {
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
                ?? "Cycling sensor",
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

// MARK: - Test hooks

extension CyclingSpeedAndCadenceSensorManager {
    /// Binds a sensor for merge/known list tests (no `CBCentralManager`).
    internal func _test_registerSensor(_ sensor: CyclingSpeedAndCadenceSensor) {
        sensorsByID[sensor.id] = sensor
        rebindDerivedMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

    internal func _test_forgetWithoutCancel(peripheralID: UUID) {
        store.remove(id: peripheralID)
        peripheralsByID[peripheralID] = nil
        sensorsByID[peripheralID] = nil
        rebindDerivedMerge()
        rebindStoreSubscriptions()
        rebuildAndPublish()
    }

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
        let peripheral: any CSCPeripheral
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
