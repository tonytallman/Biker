//
//  HRPeripheral.swift
//  HeartRateService
//

@preconcurrency import CoreBluetooth
import Foundation

/// Minimal surface of `CBPeripheral` used by the Heart Rate stack.
@MainActor
public protocol HRPeripheral: AnyObject {
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
extension CBPeripheral: HRPeripheral {}
