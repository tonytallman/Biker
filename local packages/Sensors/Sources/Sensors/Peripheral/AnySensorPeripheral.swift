//
//  AnySensorPeripheral.swift
//  Sensors
//

import Foundation

/// Type-erased ``SensorPeripheral`` that also satisfies the nested ``Delegate`` protocols on the sensor services.
package final class AnySensorPeripheral: SensorPeripheral {
    package let inner: any SensorPeripheral

    package init(_ inner: any SensorPeripheral) {
        self.inner = inner
    }

    package func has(serviceId: String) async -> Bool {
        await inner.has(serviceId: serviceId)
    }

    package func read(characteristicId: String) async -> Data? {
        await inner.read(characteristicId: characteristicId)
    }

    package func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        inner.subscribeTo(characteristicId: characteristicId)
    }
}

extension SensorPeripheral {
    /// Wraps `self` in ``AnySensorPeripheral``; returns `self` directly when already erased.
    package func eraseToAnySensorPeripheral() -> AnySensorPeripheral {
        if let already = self as? AnySensorPeripheral {
            return already
        }
        return AnySensorPeripheral(self)
    }
}
