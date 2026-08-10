//
//  GATTSensorPeripheral.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

/// Adapts ``GATTPeripheral`` plus a discovered ``CharacteristicCatalog`` onto ``SensorPeripheral``.
///
/// ``subscribeTo(characteristicId:)`` enables notify lazily inside the returned stream and does not disable it on cancellation;
/// teardown relies on disconnect or a higher layer.
package final class GATTSensorPeripheral: SensorPeripheral, @unchecked Sendable {
    private let gatt: any GATTPeripheral
    private let catalog: CharacteristicCatalog

    package init(gatt: any GATTPeripheral, catalog: CharacteristicCatalog) {
        self.gatt = gatt
        self.catalog = catalog
    }

    package func has(serviceId: String) async -> Bool {
        catalog.has(service: CBUUID(string: serviceId))
    }

    package func read(characteristicId: String) async -> Data? {
        guard let ch = catalog.find(CBUUID(string: characteristicId)) else {
            return nil
        }
        return try? await gatt.read(ch)
    }

    package func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        AsyncStream { continuation in
            let task = Task {
                guard let ch = catalog.find(CBUUID(string: characteristicId)) else {
                    continuation.finish()
                    return
                }
                do {
                    try await gatt.setNotify(true, for: ch)
                } catch {
                    continuation.finish()
                    return
                }
                for await data in gatt.valueStream(for: ch) {
                    if Task.isCancelled {
                        break
                    }
                    continuation.yield(data)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
