//
//  CSCTestDoubles.swift
//  DependencyContainerTests
//
//  Minimal copies of `CyclingSpeedAndCadenceService` test fakes (package tests cannot import the other test target).

@preconcurrency import CoreBluetooth
import Foundation

@testable import CyclingSpeedAndCadenceService

@MainActor
final class InMemoryCSCPersistence: CSCKnownSensorPersistence {
    private var records: [CSCKnownSensorRecord] = []

    func loadRecords() -> [CSCKnownSensorRecord] { records }
    func saveRecords(_ records: [CSCKnownSensorRecord]) { self.records = records }
}

@MainActor
final class TestFakeCSCCentral: CSCCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool = false
    var delegate: (any CBCentralManagerDelegate)?
    var peripheralsById: [UUID: any CSCPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0
    private(set) var cancelPeripheralConnectionCallCount = 0
    var lastConnectPeripheral: (any CSCPeripheral)?

    init(
        state: CBManagerState = .poweredOn,
        authorization: CBManagerAuthorization = .allowedAlways
    ) {
        self.state = state
        self.authorization = authorization
    }

    func scanForPeripherals(withServices _: [CBUUID]?, options _: [String: Any]?) {
        scanForPeripheralsCallCount += 1
        isScanning = true
    }

    func stopScan() {
        stopScanCallCount += 1
        isScanning = false
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any CSCPeripheral] {
        identifiers.compactMap { peripheralsById[$0] }
    }

    func connect(_ peripheral: any CSCPeripheral, options _: [String: Any]?) {
        connectCallCount += 1
        lastConnectPeripheral = peripheral
    }

    func cancelPeripheralConnection(_ peripheral: any CSCPeripheral) {
        cancelPeripheralConnectionCallCount += 1
        (peripheral as? TestFakeCSCPeripheral)?.state = .disconnected
    }
}

@MainActor
final class TestFakeCSCPeripheral: CSCPeripheral {
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
