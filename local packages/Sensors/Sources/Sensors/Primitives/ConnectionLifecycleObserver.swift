//
//  ConnectionLifecycleObserver.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

/// Observes ``Peripheral/connectionState`` and emits one disconnect payload per transition away from connected.
package final class ConnectionLifecycleObserver: Sendable {
    package let disconnects: AsyncStream<CBError?>

    private let continuation: AsyncStream<CBError?>.Continuation
    private let observerTask: Task<Void, Never>

    package init(peripheral: Peripheral) {
        let (stream, continuation) = AsyncStream<CBError?>.makeStream(bufferingPolicy: .bufferingNewest(8))
        self.disconnects = stream
        self.continuation = continuation

        let watchedPeripheral = peripheral
        self.observerTask = Task {
            defer { continuation.finish() }
            var wasConnected = false
            for await state in await watchedPeripheral.connectionState.stream {
                if Task.isCancelled {
                    break
                }
                switch state {
                case .connected:
                    wasConnected = true
                case .disconnected(let cbError):
                    if wasConnected {
                        continuation.yield(cbError)
                        wasConnected = false
                    }
                default:
                    break
                }
            }
        }
    }

    deinit {
        observerTask.cancel()
    }
}
