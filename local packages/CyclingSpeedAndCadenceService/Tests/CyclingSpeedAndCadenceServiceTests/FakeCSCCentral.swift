//
//  FakeCSCCentral.swift
//  CyclingSpeedAndCadenceServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation

@testable import CyclingSpeedAndCadenceService

@MainActor
final class FakeCSCCentral: CSCCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool
    var delegate: (any CBCentralManagerDelegate)?

    var peripheralsById: [UUID: any CSCPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0
    private(set) var cancelPeripheralConnectionCallCount = 0
    var lastConnectPeripheral: (any CSCPeripheral)?

    func resetCallCounts() {
        scanForPeripheralsCallCount = 0
        stopScanCallCount = 0
        connectCallCount = 0
        cancelPeripheralConnectionCallCount = 0
        lastConnectPeripheral = nil
    }

    /// Fired after `state` / `authorization` change; wire to `manager.handleBluetoothStateChange()`.
    var onAuthorizationOrStateChange: (() -> Void)?

    init(
        state: CBManagerState = .unknown,
        authorization: CBManagerAuthorization = .allowedAlways,
        isScanning: Bool = false
    ) {
        self.state = state
        self.authorization = authorization
        self.isScanning = isScanning
        self.delegate = nil
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
        if let p = peripheral as? FakeCSCPeripheral {
            p.state = .disconnected
        }
    }

    /// Mutates `authorization` / `state` and notifies the manager under test.
    func simulate(authorization: CBManagerAuthorization, state: CBManagerState) {
        self.authorization = authorization
        self.state = state
        onAuthorizationOrStateChange?()
    }
}

@MainActor
final class FakeCSCPeripheral: CSCPeripheral {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState
    weak var delegate: (any CBPeripheralDelegate)?
    var services: [CBService]?
    var discoverServiceUUIDs: [CBUUID]?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier
        self.name = name
        self.state = .disconnected
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        discoverServiceUUIDs = serviceUUIDs
    }

    func discoverCharacteristics(_: [CBUUID]?, for _: CBService) {}

    func setNotifyValue(_: Bool, for _: CBCharacteristic) {}
}
