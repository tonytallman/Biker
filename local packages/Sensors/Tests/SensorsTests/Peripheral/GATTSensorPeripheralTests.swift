//
//  GATTSensorPeripheralTests.swift
//  SensorsTests
//

import CoreBluetooth
import Foundation
import Sensors
import Testing

extension SensorTests {

    @Test func gatt_sensor_peripheral_has_serviceId_matchesCatalog() async throws {
        let (catalog, measurement, _) = try await gattCatalogMeasurementAndControl()
        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: nil)
        let peripheral = GATTSensorPeripheral(gatt: stub, catalog: catalog)

        #expect(await peripheral.has(serviceId: "180D"))
        #expect(await peripheral.has(serviceId: "DEAD") == false)
    }

    @Test func gatt_sensor_peripheral_read_characteristicId_returnsStubPayload() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()
        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        stub.readPayload = Data([0xAA, 0xBB])
        let peripheral = GATTSensorPeripheral(gatt: stub, catalog: catalog)

        let data = await peripheral.read(characteristicId: MockBLEPeripheral.measurementUUID.uuidString)
        #expect(data == Data([0xAA, 0xBB]))
    }

    @Test func gatt_sensor_peripheral_read_characteristicId_returnsNilWhenUnknown() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()
        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        let peripheral = GATTSensorPeripheral(gatt: stub, catalog: catalog)

        let data = await peripheral.read(characteristicId: "FFFF")
        #expect(data == nil)
    }

    @Test func gatt_sensor_peripheral_subscribeTo_enablesNotifyAndForwardsValueStream() async throws {
        let (catalog, measurement, control) = try await gattCatalogMeasurementAndControl()
        let stub = GATTPeripheralStub(catalog: catalog, primaryCharacteristic: measurement, controlCharacteristic: control)
        let peripheral = GATTSensorPeripheral(gatt: stub, catalog: catalog)

        let stream = peripheral.subscribeTo(characteristicId: MockBLEPeripheral.measurementUUID.uuidString)
        let box = ValueBox<Data>()
        let task = Task {
            for await value in stream {
                box.store(value)
                break
            }
        }
        defer { task.cancel() }

        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(stub.lastNotifyEnabled == true)

        stub.sendNotify(Data([0x01, 0x02]))
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(box.load() == Data([0x01, 0x02]))
    }
}
