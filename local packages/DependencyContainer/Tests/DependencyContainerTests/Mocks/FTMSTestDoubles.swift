//
//  FTMSTestDoubles.swift
//  DependencyContainerTests
//

@preconcurrency import CoreBluetooth
import Foundation

@testable import FitnessMachineService

final class InMemoryFTMSPersistence: FTMSPersistence {
    private var storage: [String: Any] = [:]

    init() {}

    func get(forKey key: String) -> Any? { storage[key] }

    func set(value: Any?, forKey key: String) {
        if let value {
            storage[key] = value
        } else {
            storage.removeValue(forKey: key)
        }
    }
}

@MainActor
final class TestFakeFTMSCentral: FTMSCentralManaging {
    var state: CBManagerState
    var authorization: CBManagerAuthorization
    var isScanning: Bool = false
    var delegate: (any CBCentralManagerDelegate)?
    var peripheralsById: [UUID: any FTMSPeripheral] = [:]

    private(set) var scanForPeripheralsCallCount = 0
    private(set) var stopScanCallCount = 0
    private(set) var connectCallCount = 0
    private(set) var cancelPeripheralConnectionCallCount = 0
    var lastConnectPeripheral: (any FTMSPeripheral)?

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

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any FTMSPeripheral] {
        identifiers.compactMap { peripheralsById[$0] }
    }

    func connect(_ peripheral: any FTMSPeripheral, options _: [String: Any]?) {
        connectCallCount += 1
        lastConnectPeripheral = peripheral
    }

    func cancelPeripheralConnection(_ peripheral: any FTMSPeripheral) {
        cancelPeripheralConnectionCallCount += 1
        (peripheral as? TestFakeFTMSPeripheral)?.state = .disconnected
    }
}

@MainActor
final class TestFakeFTMSPeripheral: FTMSPeripheral {
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
