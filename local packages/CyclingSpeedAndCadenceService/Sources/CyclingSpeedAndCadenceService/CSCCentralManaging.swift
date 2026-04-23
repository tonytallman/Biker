//
//  CSCCentralManaging.swift
//  CyclingSpeedAndCadenceService
//
//  Abstraction over `CBCentralManager` for testability and availability reduction.
//

@preconcurrency import CoreBluetooth
import Foundation

/// Core Bluetooth central surface used by `CyclingSpeedAndCadenceSensorManager`.
@MainActor
public protocol CSCCentralManaging: AnyObject {
    var state: CBManagerState { get }
    var authorization: CBManagerAuthorization { get }
    var isScanning: Bool { get }
    var delegate: (any CBCentralManagerDelegate)? { get set }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any CSCPeripheral]
    func connect(_ peripheral: any CSCPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: any CSCPeripheral)
}

/// Production wrapper around `CBCentralManager` (avoids overload recursion vs `CSCCentralManaging.retrievePeripherals`).
@MainActor
public final class RealCSCCentral: CSCCentralManaging {
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

    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any CSCPeripheral] {
        core.retrievePeripherals(withIdentifiers: identifiers).map { $0 as any CSCPeripheral }
    }

    public func connect(_ peripheral: any CSCPeripheral, options: [String: Any]?) {
        guard let p = peripheral as? CBPeripheral else {
            assertionFailure("CBCentralManager.connect requires a CBPeripheral")
            return
        }
        core.connect(p, options: options)
    }

    public func cancelPeripheralConnection(_ peripheral: any CSCPeripheral) {
        guard let p = peripheral as? CBPeripheral else {
            assertionFailure("CBCentralManager.cancelPeripheralConnection requires a CBPeripheral")
            return
        }
        core.cancelPeripheralConnection(p)
    }
}
