//
//  SensorTests+GATTHarness.swift
//  SensorsTests
//

import AsyncCoreBluetooth
import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Sensors
import Testing

extension SensorTests {
    /// Heart-rate mock layout: catalog plus measurement and control ``Characteristic`` handles.
    func gattCatalogMeasurementAndControl(
        delegate: HeartRatePeripheralDelegate = HeartRatePeripheralDelegate()
    ) async throws -> (CharacteristicCatalog, Characteristic, Characteristic) {
        let h = try await makeHarness(delegate: delegate)
        let catalog = try await ServiceDiscoverer.discoverAll(on: h.peripheral)
        let measurement = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
        let control = try catalog.require(MockBLEPeripheral.controlUUID, in: MockBLEPeripheral.serviceUUID)
        return (catalog, measurement, control)
    }
}
