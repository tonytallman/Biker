//
//  CSCPeripheral.swift
//  CyclingSpeedAndCadenceService
//
//  Protocol to abstract `CBPeripheral` for tests (fake peripherals) and keep Core
//  Bluetooth use `@preconcurrency` in one place.
//

@preconcurrency import CoreBluetooth
import Foundation

/// Minimal surface of `CBPeripheral` used by the CSC stack.
@MainActor
public protocol CSCPeripheral: AnyObject {
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
extension CBPeripheral: CSCPeripheral {}
