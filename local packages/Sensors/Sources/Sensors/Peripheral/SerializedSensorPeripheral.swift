//
//  SerializedSensorPeripheral.swift
//  Sensors
//

import Foundation

/// Decorator that serializes ``has(serviceId:)`` and ``read(characteristicId:)``.
///
/// Actor isolation alone does not serialize across `await` into ``SensorPeripheral`` implementations,
/// so operations are chained with a gate task so each call waits for the prior one to fully finish
/// (including suspension inside `inner`).
///
/// ``subscribeTo(characteristicId:)`` is forwarded without serialization so stream creation stays synchronous and non-blocking on the underlying transport.
package actor SerializedSensorPeripheral: SensorPeripheral {
    nonisolated package let inner: any SensorPeripheral

    /// Completes after all prior serialized operations have fully finished.
    private var gate: Task<Void, Never>?

    package init(_ inner: any SensorPeripheral) {
        self.inner = inner
    }

    package func has(serviceId: String) async -> Bool {
        let peripheral = inner
        return await runExclusive {
            await peripheral.has(serviceId: serviceId)
        }
    }

    package func read(characteristicId: String) async -> Data? {
        let peripheral = inner
        return await runExclusive {
            await peripheral.read(characteristicId: characteristicId)
        }
    }

    private func runExclusive<T: Sendable>(_ operation: @escaping @Sendable () async -> T) async -> T {
        let previous = gate
        let work = Task<T, Never> {
            await previous?.value
            return await operation()
        }
        gate = Task<Void, Never> {
            _ = await work.value
        }
        return await work.value
    }

    package nonisolated func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        inner.subscribeTo(characteristicId: characteristicId)
    }
}
