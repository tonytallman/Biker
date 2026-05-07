//
//  AnyGATTPeripheral.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

/// Type-erased ``GATTPeripheral``.
package final class AnyGATTPeripheral: GATTPeripheral {
    package let inner: any GATTPeripheral

    package init(_ inner: any GATTPeripheral) {
        self.inner = inner
    }

    package func discoverAll() async throws -> CharacteristicCatalog {
        try await inner.discoverAll()
    }

    package func read(_ characteristic: Characteristic) async throws -> Data {
        try await inner.read(characteristic)
    }

    package func write(
        _ data: Data,
        to characteristic: Characteristic,
        type: CBCharacteristicWriteType
    ) async throws {
        try await inner.write(data, to: characteristic, type: type)
    }

    package func setNotify(_ enabled: Bool, for characteristic: Characteristic) async throws {
        try await inner.setNotify(enabled, for: characteristic)
    }

    package func valueStream(for characteristic: Characteristic) -> AsyncStream<Data> {
        inner.valueStream(for: characteristic)
    }
}

extension GATTPeripheral {
    /// Wraps `self` in ``AnyGATTPeripheral``; returns `self` directly when already erased.
    package func eraseToAnyGATTPeripheral() -> AnyGATTPeripheral {
        if let already = self as? AnyGATTPeripheral {
            return already
        }
        return AnyGATTPeripheral(self)
    }
}
