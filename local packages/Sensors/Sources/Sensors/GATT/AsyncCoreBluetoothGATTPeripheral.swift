//
//  AsyncCoreBluetoothGATTPeripheral.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

package final class AsyncCoreBluetoothGATTPeripheral: GATTPeripheral {
    private let peripheral: Peripheral

    package init(_ peripheral: Peripheral) {
        self.peripheral = peripheral
    }

    package func discoverAll() async throws -> CharacteristicCatalog {
        try await ServiceDiscoverer.discoverAll(on: peripheral)
    }

    package func read(_ characteristic: Characteristic) async throws -> Data {
        do {
            return try await peripheral.readValue(for: characteristic)
        } catch {
            throw SensorError.map(error)
        }
    }

    package func write(
        _ data: Data,
        to characteristic: Characteristic,
        type: CBCharacteristicWriteType
    ) async throws {
        switch type {
        case .withResponse:
            do {
                try await peripheral.writeValueWithResponse(data, for: characteristic)
            } catch {
                throw SensorError.map(error)
            }
        case .withoutResponse:
            await peripheral.writeValueWithoutResponse(data, for: characteristic)
        @unknown default:
            await peripheral.writeValueWithoutResponse(data, for: characteristic)
        }
    }

    package func setNotify(_ enabled: Bool, for characteristic: Characteristic) async throws {
        do {
            _ = try await peripheral.setNotifyValue(enabled, for: characteristic)
        } catch {
            throw SensorError.map(error)
        }
    }

    package func valueStream(for characteristic: Characteristic) -> AsyncStream<Data> {
        NotificationCharacteristicStream.skippingCachedReplay(for: characteristic)
    }
}
