//
//  CharacteristicCatalogTests.swift
//  SensorsTests
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation
import Sensors
import Testing

@Suite(.serialized)
struct CharacteristicCatalogTests {

    @Test func require_unknownService_throwsServiceNotFound() {
        let catalog = CharacteristicCatalog(services: [:])
        do {
            _ = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
            Issue.record("expected throw")
        } catch let error as SensorError {
            guard case .serviceNotFound = error else {
                Issue.record("unexpected SensorError \(error)")
                return
            }
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func require_unknownCharacteristic_throwsCharacteristicNotFound() {
        let emptyChars: [CBUUID: Characteristic] = [:]
        let catalog = CharacteristicCatalog(services: [MockBLEPeripheral.serviceUUID: emptyChars])
        #expect(catalog.has(service: MockBLEPeripheral.serviceUUID))
        do {
            _ = try catalog.require(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
            Issue.record("expected throw")
        } catch let error as SensorError {
            guard case .characteristicNotFound = error else {
                Issue.record("unexpected SensorError \(error)")
                return
            }
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }
}
