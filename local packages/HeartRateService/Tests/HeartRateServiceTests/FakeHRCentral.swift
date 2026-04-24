//
//  FakeHRCentral.swift
//  HeartRateServiceTests
//

@preconcurrency import CoreBluetooth
import Foundation

@testable import HeartRateService

@MainActor
final class FakeHRCentral: HRCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool
    var delegate: (any CBCentralManagerDelegate)?

    var peripheralsById: [UUID: any HRPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0
    private(set) var cancelPeripheralConnectionCallCount = 0
    var lastConnectPeripheral: (any HRPeripheral)?

    func resetCallCounts() {
        scanForPeripheralsCallCount = 0
        stopScanCallCount = 0
        connectCallCount = 0
        cancelPeripheralConnectionCallCount = 0
        lastConnectPeripheral = nil
    }

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

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any HRPeripheral] {
        identifiers.compactMap { peripheralsById[$0] }
    }

    func connect(_ peripheral: any HRPeripheral, options _: [String: Any]?) {
        connectCallCount += 1
        lastConnectPeripheral = peripheral
    }

    func cancelPeripheralConnection(_ peripheral: any HRPeripheral) {
        cancelPeripheralConnectionCallCount += 1
        if let p = peripheral as? FakeHRPeripheral {
            p.state = .disconnected
        }
    }

    func simulate(authorization: CBManagerAuthorization, state: CBManagerState) {
        self.authorization = authorization
        self.state = state
        onAuthorizationOrStateChange?()
    }
}

@MainActor
final class FakeHRPeripheral: HRPeripheral {
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
