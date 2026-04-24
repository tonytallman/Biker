//
//  HRCentralManaging.swift
//  HeartRateService
//

@preconcurrency import CoreBluetooth
import Foundation

/// Core Bluetooth central surface used by `HeartRateSensorManager`.
@MainActor
public protocol HRCentralManaging: AnyObject {
    var state: CBManagerState { get }
    var authorization: CBManagerAuthorization { get }
    var isScanning: Bool { get }
    var delegate: (any CBCentralManagerDelegate)? { get set }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any HRPeripheral]
    func connect(_ peripheral: any HRPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: any HRPeripheral)
}

/// Production wrapper around `CBCentralManager`.
@MainActor
public final class RealHRCentral: HRCentralManaging {
    public let core: CBCentralManager

    public init(core: CBCentralManager) {
        self.core = core
    }

    public var state: CBManagerState { core.state }
    public var authorization: CBManagerAuthorization { type(of: core).authorization }
    public var isScanning: Bool { core.isScanning }
    public var delegate: (any CBCentralManagerDelegate)? {
        get { core.delegate }
        set { core.delegate = newValue }
    }

    public func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        core.scanForPeripherals(withServices: serviceUUIDs, options: options)
    }

    public func stopScan() {
        core.stopScan()
    }

    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any HRPeripheral] {
        core.retrievePeripherals(withIdentifiers: identifiers).map { $0 as any HRPeripheral }
    }

    public func connect(_ peripheral: any HRPeripheral, options: [String: Any]?) {
        guard let p = peripheral as? CBPeripheral else {
            assertionFailure("CBCentralManager.connect requires a CBPeripheral")
            return
        }
        core.connect(p, options: options)
    }

    public func cancelPeripheralConnection(_ peripheral: any HRPeripheral) {
        guard let p = peripheral as? CBPeripheral else {
            assertionFailure("CBCentralManager.cancelPeripheralConnection requires a CBPeripheral")
            return
        }
        core.cancelPeripheralConnection(p)
    }
}
