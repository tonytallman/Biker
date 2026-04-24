//
//  FTMSPeripheral.swift
//  FitnessMachineService
//

@preconcurrency import CoreBluetooth
import Foundation

/// Minimal surface of `CBPeripheral` used by the FTMS stack.
@MainActor
public protocol FTMSPeripheral: AnyObject {
    var identifier: UUID { get }
    var name: String? { get }
    var state: CBPeripheralState { get }
    var delegate: (any CBPeripheralDelegate)? { get set }
    var services: [CBService]? { get }
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService)
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
}

@MainActor
extension CBPeripheral: FTMSPeripheral {}
