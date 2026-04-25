//
//  IntegrationFakes.swift
//  DependencyContainerIntegrationTests
//

@preconcurrency import CoreBluetooth
import Combine
import Foundation
import HeartRateService
import SettingsVM

import FitnessMachineService

@testable import CyclingSpeedAndCadenceService
@testable import DependencyContainer

@MainActor
final class InMemoryCSCIntegrationPersistence: CSCKnownSensorPersistence {
    private var records: [CSCKnownSensorRecord] = []
    func loadRecords() -> [CSCKnownSensorRecord] { records }
    func saveRecords(_ records: [CSCKnownSensorRecord]) { self.records = records }
}

final class InMemoryFTMSIntegrationPersistence: FTMSPersistence {
    private var storage: [String: Any] = [:]
    func get(forKey key: String) -> Any? { storage[key] }
    func set(value: Any?, forKey key: String) {
        if let value { storage[key] = value } else { storage.removeValue(forKey: key) }
    }
}

final class InMemoryHRIntegrationPersistence: HRPersistence {
    private var storage: [String: Any] = [:]
    func get(forKey key: String) -> Any? { storage[key] }
    func set(value: Any?, forKey key: String) {
        if let value { storage[key] = value } else { storage.removeValue(forKey: key) }
    }
}

@MainActor
final class IntegrationCSCCentral: CSCCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool = false
    var delegate: (any CBCentralManagerDelegate)?
    var peripheralsById: [UUID: any CSCPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0

    var onAuthorizationOrStateChange: (() -> Void)?

    init(
        state: CBManagerState = .poweredOn,
        authorization: CBManagerAuthorization = .allowedAlways
    ) {
        self.state = state
        self.authorization = authorization
    }

    func scanForPeripherals(withServices _: [CBUUID]?, options _: [String: Any]?) {
        scanForPeripheralsCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any CSCPeripheral] {
        identifiers.compactMap { peripheralsById[$0] }
    }

    func connect(_ peripheral: any CSCPeripheral, options _: [String: Any]?) {
        connectCallCount += 1
    }

    func cancelPeripheralConnection(_ peripheral: any CSCPeripheral) {
        (peripheral as? IntegrationCSCPeripheral)?.state = .disconnected
    }

    func simulate(authorization: CBManagerAuthorization, state: CBManagerState) {
        self.authorization = authorization
        self.state = state
        onAuthorizationOrStateChange?()
    }
}

@MainActor
final class IntegrationCSCPeripheral: CSCPeripheral {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState
    weak var delegate: (any CBPeripheralDelegate)?
    var services: [CBService]?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
        self.state = .disconnected
    }

    func discoverServices(_: [CBUUID]?) {}
    func discoverCharacteristics(_: [CBUUID]?, for _: CBService) {}
    func setNotifyValue(_: Bool, for _: CBCharacteristic) {}
}

@MainActor
final class IntegrationFTMSCentral: FTMSCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool = false
    var delegate: (any CBCentralManagerDelegate)?
    var peripheralsById: [UUID: any FTMSPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0

    var onAuthorizationOrStateChange: (() -> Void)?

    init(
        state: CBManagerState = .poweredOn,
        authorization: CBManagerAuthorization = .allowedAlways
    ) {
        self.state = state
        self.authorization = authorization
    }

    func scanForPeripherals(withServices _: [CBUUID]?, options _: [String: Any]?) {
        scanForPeripheralsCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any FTMSPeripheral] {
        identifiers.compactMap { peripheralsById[$0] }
    }

    func connect(_ peripheral: any FTMSPeripheral, options _: [String: Any]?) {
        connectCallCount += 1
    }

    func cancelPeripheralConnection(_ peripheral: any FTMSPeripheral) {
        (peripheral as? IntegrationFTMSPeripheral)?.state = .disconnected
    }

    func simulate(authorization: CBManagerAuthorization, state: CBManagerState) {
        self.authorization = authorization
        self.state = state
        onAuthorizationOrStateChange?()
    }
}

@MainActor
final class IntegrationFTMSPeripheral: FTMSPeripheral {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState
    weak var delegate: (any CBPeripheralDelegate)?
    var services: [CBService]?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
        self.state = .disconnected
    }

    func discoverServices(_: [CBUUID]?) {}
    func discoverCharacteristics(_: [CBUUID]?, for _: CBService) {}
    func setNotifyValue(_: Bool, for _: CBCharacteristic) {}
}

@MainActor
final class IntegrationHRCentral: HRCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool = false
    var delegate: (any CBCentralManagerDelegate)?
    var peripheralsById: [UUID: any HRPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0

    var onAuthorizationOrStateChange: (() -> Void)?

    init(
        state: CBManagerState = .poweredOn,
        authorization: CBManagerAuthorization = .allowedAlways
    ) {
        self.state = state
        self.authorization = authorization
    }

    func scanForPeripherals(withServices _: [CBUUID]?, options _: [String: Any]?) {
        scanForPeripheralsCallCount += 1
    }

    func stopScan() {
        stopScanCallCount += 1
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any HRPeripheral] {
        identifiers.compactMap { peripheralsById[$0] }
    }

    func connect(_ peripheral: any HRPeripheral, options _: [String: Any]?) {
        connectCallCount += 1
    }

    func cancelPeripheralConnection(_ peripheral: any HRPeripheral) {
        (peripheral as? IntegrationHRPeripheral)?.state = .disconnected
    }

    func simulate(authorization: CBManagerAuthorization, state: CBManagerState) {
        self.authorization = authorization
        self.state = state
        onAuthorizationOrStateChange?()
    }
}

@MainActor
final class IntegrationHRPeripheral: HRPeripheral {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState
    weak var delegate: (any CBPeripheralDelegate)?
    var services: [CBService]?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
        self.state = .disconnected
    }

    func discoverServices(_: [CBUUID]?) {}
    func discoverCharacteristics(_: [CBUUID]?, for _: CBService) {}
    func setNotifyValue(_: Bool, for _: CBCharacteristic) {}
}

// MARK: - Integration test timing

/// `manager.sensors` is observed with `receive(on: .main)` in Lex, so rebind is often one run-loop turn
/// after `_test_registerSensor`. Drain nested main work (same idea as `flushMetricDeliveries`) before
/// `_test_ingest*`; integration metric tests also inject fake centrals to avoid `CBCentralManager` flakiness.
func integrationYieldForLexWiring() async {
    await MainActor.run { }
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                cont.resume()
            }
        }
    }
    for _ in 0..<4 {
        await Task.yield()
    }
}

/// First emission from `availability` (Combine may deliver asynchronously after `sink`).
@MainActor
func integrationFirstSensorAvailability(
    _ publisher: AnyPublisher<SensorAvailability, Never>
) async -> SensorAvailability {
    await withCheckedContinuation { (cont: CheckedContinuation<SensorAvailability, Never>) in
        var token: AnyCancellable?
        token = publisher.sink { value in
            cont.resume(returning: value)
            token?.cancel()
        }
    }
}
