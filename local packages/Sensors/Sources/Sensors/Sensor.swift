//
//  Sensor.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

// MARK: - Sensor actor

/// Wraps ``AsyncCoreBluetooth/Peripheral`` and exposes async read/write plus notification ``AsyncThrowingStream``s.
///
/// State is serialized through actor isolation; BLE delegate bridging lives in `AsyncCoreBluetooth`.
///
/// - Important: If multiple ``read`` calls on the same characteristic are in flight at once, completion
///   order is not guaranteed—issue reads sequentially when ordering matters.
package actor Sensor {
    nonisolated let peripheral: Peripheral

    /// Starts empty so lifecycle observation can run during discovery, then is replaced by ``ServiceDiscoverer/discoverAll(on:)``.
    private var catalog: CharacteristicCatalog
    private let lifecycle: ConnectionLifecycleObserver

    /// Wired after discovery so ``handleDisconnect(cbError:)`` can no-op while ``multiplexer`` is still nil.
    private var multiplexer: NotificationMultiplexer<NotificationSubscriptionKey>!

    /// Consumes ``ConnectionLifecycleObserver/disconnects``; may run before ``multiplexer`` is assigned (during discovery).
    nonisolated(unsafe) private var lifecycleTask: Task<Void, Never>?

    package init(peripheral: Peripheral) async throws {
        self.peripheral = peripheral
        self.lifecycle = ConnectionLifecycleObserver(peripheral: peripheral)
        self.catalog = try await ServiceDiscoverer.discoverAll(on: peripheral)
        startLifecycleObservation()

        multiplexer = NotificationMultiplexer<NotificationSubscriptionKey>(
            upstream: { [peripheral, catalog] key in
                let characteristic = try catalog.require(key.characteristic, in: key.service)
                do {
                    _ = try await peripheral.setNotifyValue(true, for: characteristic)
                } catch {
                    throw SensorError.map(error)
                }
                return NotificationCharacteristicStream.skippingCachedReplay(for: characteristic)
            },
            teardown: { [peripheral, catalog] key in
                guard let characteristic = try? catalog.require(key.characteristic, in: key.service) else { return }
                _ = try? await peripheral.setNotifyValue(false, for: characteristic)
            }
        )
    }

    private func startLifecycleObservation() {
        lifecycleTask?.cancel()
        lifecycleTask = Task {
            for await cbError in lifecycle.disconnects {
                if Task.isCancelled {
                    break
                }
                await handleDisconnect(cbError: cbError)
            }
        }
    }

    private func handleDisconnect(cbError: CBError?) async {
        let sensorError: SensorError =
            if let cbError {
                .underlying(cbError)
            } else {
                .disconnected
            }

        await multiplexer?.finishAll(throwing: sensorError)
    }

    private func mapErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw SensorError.map(error)
        }
    }

    // MARK: Lookup

    package func has(service: CBUUID) -> Bool {
        catalog.has(service: service)
    }

    package func has(characteristic: CBUUID, in service: CBUUID) -> Bool {
        catalog.has(characteristic: characteristic, in: service)
    }

    private func requireCharacteristic(_ uuid: CBUUID, in service: CBUUID) throws -> Characteristic {
        try catalog.require(uuid, in: service)
    }

    // MARK: Read / write

    package func read(_ uuid: CBUUID, in service: CBUUID) async throws -> Data {
        let characteristic = try requireCharacteristic(uuid, in: service)
        return try await mapErrors {
            try await peripheral.readValue(for: characteristic)
        }
    }

    package func write(
        _ data: Data,
        to uuid: CBUUID,
        in service: CBUUID,
        type: CBCharacteristicWriteType = .withResponse
    ) async throws {
        let characteristic = try requireCharacteristic(uuid, in: service)
        switch type {
        case .withResponse:
            try await mapErrors {
                try await peripheral.writeValueWithResponse(data, for: characteristic)
            }
        case .withoutResponse:
            await peripheral.writeValueWithoutResponse(data, for: characteristic)
        @unknown default:
            await peripheral.writeValueWithoutResponse(data, for: characteristic)
        }
    }

    // MARK: Subscribe

    package func subscribe(
        to uuid: CBUUID,
        in service: CBUUID
    ) async throws -> AsyncThrowingStream<Data, Error> {
        _ = try requireCharacteristic(uuid, in: service)
        let key = NotificationSubscriptionKey(service: service, characteristic: uuid)
        return try await multiplexer.subscribe(key)
    }
}
