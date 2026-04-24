//
//  FTMSCentralManaging.swift
//  FitnessMachineService
//

@preconcurrency import CoreBluetooth
import Foundation

/// Core Bluetooth central surface used by `FitnessMachineSensorManager`.
@MainActor
public protocol FTMSCentralManaging: AnyObject {
    var state: CBManagerState { get }
    var authorization: CBManagerAuthorization { get }
    var isScanning: Bool { get }
    var delegate: (any CBCentralManagerDelegate)? { get set }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any FTMSPeripheral]
    func connect(_ peripheral: any FTMSPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: any FTMSPeripheral)
}

/// Production wrapper around `CBCentralManager`.
@MainActor
public final class RealFTMSCentral: FTMSCentralManaging {
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

    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [any FTMSPeripheral] {
        core.retrievePeripherals(withIdentifiers: identifiers).map { $0 as any FTMSPeripheral }
    }

    public func connect(_ peripheral: any FTMSPeripheral, options: [String: Any]?) {
        guard let p = peripheral as? CBPeripheral else {
            assertionFailure("CBCentralManager.connect requires a CBPeripheral")
            return
        }
        core.connect(p, options: options)
    }

    public func cancelPeripheralConnection(_ peripheral: any FTMSPeripheral) {
        guard let p = peripheral as? CBPeripheral else {
            assertionFailure("CBCentralManager.cancelPeripheralConnection requires a CBPeripheral")
            return
        }
        core.cancelPeripheralConnection(p)
    }
}
