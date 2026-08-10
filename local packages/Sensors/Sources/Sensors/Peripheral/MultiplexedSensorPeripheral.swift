//
//  MultiplexedSensorPeripheral.swift
//  Sensors
//

import Foundation

/// Wraps ``SensorPeripheral`` and multiplexes ``subscribeTo(characteristicId:)`` across many subscribers via ``NotificationMultiplexer``.
///
/// ``has(serviceId:)`` and ``read(characteristicId:)`` forward directly to ``inner``.
/// Last-subscriber teardown on ``SensorPeripheral`` is deferred (see ADR 0017).
package final class MultiplexedSensorPeripheral: SensorPeripheral, @unchecked Sendable {
    package let inner: any SensorPeripheral

    private let mux: NotificationMultiplexer<String>

    package init(_ inner: any SensorPeripheral) {
        self.inner = inner
        let upstream = inner
        self.mux = NotificationMultiplexer<String>(
            upstream: { characteristicId in
                upstream.subscribeTo(characteristicId: characteristicId)
            },
            teardown: { _ in }
        )
    }

    package func has(serviceId: String) async -> Bool {
        await inner.has(serviceId: serviceId)
    }

    package func read(characteristicId: String) async -> Data? {
        await inner.read(characteristicId: characteristicId)
    }

    package func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    let throwing = try await mux.subscribe(characteristicId)
                    for try await data in throwing {
                        if Task.isCancelled {
                            break
                        }
                        continuation.yield(data)
                    }
                } catch {
                    // Errors end the stream; throwing multiplex paths propagate via multiplexer.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
