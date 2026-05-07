//
//  SerializedGATTPeripheral.swift
//  Sensors
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

/// Serializes ``discoverAll()``, ``read``, ``write``, and ``setNotify`` so overlapping suspensions don’t interleave on ``inner``.
///
/// ``valueStream(for:)`` is forwarded without serialization so stream wiring stays synchronous.
package actor SerializedGATTPeripheral: GATTPeripheral {
    nonisolated package let inner: any GATTPeripheral

    private var gate: Task<Void, Never>?

    package init(_ inner: any GATTPeripheral) {
        self.inner = inner
    }

    package func discoverAll() async throws -> CharacteristicCatalog {
        let g = inner
        return try await runExclusiveThrowing {
            try await g.discoverAll()
        }
    }

    package func read(_ characteristic: Characteristic) async throws -> Data {
        let g = inner
        return try await runExclusiveThrowing {
            try await g.read(characteristic)
        }
    }

    package func write(
        _ data: Data,
        to characteristic: Characteristic,
        type: CBCharacteristicWriteType
    ) async throws {
        let g = inner
        try await runExclusiveThrowing {
            try await g.write(data, to: characteristic, type: type)
        }
    }

    package func setNotify(_ enabled: Bool, for characteristic: Characteristic) async throws {
        let g = inner
        try await runExclusiveThrowing {
            try await g.setNotify(enabled, for: characteristic)
        }
    }

    package nonisolated func valueStream(for characteristic: Characteristic) -> AsyncStream<Data> {
        inner.valueStream(for: characteristic)
    }

    private func runExclusiveThrowing<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let previous = gate
        let work = Task<Result<T, Error>, Never> {
            await previous?.value
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        gate = Task<Void, Never> {
            _ = await work.value
        }
        switch await work.value {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
