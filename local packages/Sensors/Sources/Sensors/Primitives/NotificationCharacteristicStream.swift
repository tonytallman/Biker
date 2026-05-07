//
//  NotificationCharacteristicStream.swift
//  Sensors
//

import AsyncCoreBluetooth
import Foundation

/// Bridges ``Characteristic/value`` updates into a plain ``AsyncStream`` with optional replay suppression.
package enum NotificationCharacteristicStream {
    /// Mirrors the cached-value replay skip previously implemented on ``Sensor``.
    package static func skippingCachedReplay(for characteristic: Characteristic) -> AsyncStream<Data> {
        AsyncStream { continuation in
            Task {
                await Task.yield()
                await Task.yield()

                let cachedSnapshot = await characteristic.value.raw
                var skipFirstReplayFromCache = false
                if let cachedSnapshot, !cachedSnapshot.isEmpty {
                    skipFirstReplayFromCache = true
                }

                for await data in await characteristic.value.stream {
                    if Task.isCancelled {
                        break
                    }
                    if skipFirstReplayFromCache {
                        skipFirstReplayFromCache = false
                        continue
                    }
                    continuation.yield(data)
                }
                continuation.finish()
            }
        }
    }
}
