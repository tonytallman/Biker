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

/// Wraps ``GATTPeripheral`` (default stack over ``AsyncCoreBluetooth/Peripheral``) for async read/write plus notification ``AsyncThrowingStream``s.
///
/// State is serialized through actor isolation; BLE delegate bridging lives in `AsyncCoreBluetooth`.
///
/// - Important: If multiple ``read`` calls on the same characteristic are in flight at once, completion
///   order is not guaranteed—issue reads sequentially when ordering matters.
package actor Sensor {
    nonisolated let peripheral: Peripheral

    private let gatt: any GATTPeripheral
    private let catalog: CharacteristicCatalog
    private let lifecycle: ConnectionLifecycleObserver

    /// Wired after discovery so ``handleDisconnect(cbError:)`` can no-op while ``multiplexer`` is still nil during actor init sequencing.
    private var multiplexer: NotificationMultiplexer<NotificationSubscriptionKey>!

    /// Consumes ``ConnectionLifecycleObserver/disconnects``; may run before ``multiplexer`` is assigned (during initialization).
    nonisolated(unsafe) private var lifecycleTask: Task<Void, Never>?

    package init(peripheral: Peripheral) async throws {
        self.peripheral = peripheral
        self.lifecycle = ConnectionLifecycleObserver(peripheral: peripheral)
        let stack = SerializedGATTPeripheral(AsyncCoreBluetoothGATTPeripheral(peripheral))
        self.gatt = stack
        self.catalog = try await stack.discoverAll()
        startLifecycleObservation()

        let catalogCapture = self.catalog
        let gattCapture = self.gatt
        multiplexer = NotificationMultiplexer<NotificationSubscriptionKey>(
            upstream: { key in
                let characteristic = try catalogCapture.require(key.characteristic, in: key.service)
                _ = try await gattCapture.setNotify(true, for: characteristic)
                return gattCapture.valueStream(for: characteristic)
            },
            teardown: { key in
                guard let characteristic = try? catalogCapture.require(key.characteristic, in: key.service) else { return }
                try? await gattCapture.setNotify(false, for: characteristic)
            }
        )
    }

    /// Injection initializer for tests and composition roots building ``gatt`` / ``catalog`` externally.
    ///
    /// - Parameters:
    ///   - gatt: Transport stack (typically ``SerializedGATTPeripheral`` wrapping ``AsyncCoreBluetoothGATTPeripheral``).
    ///   - lifecycle: Must observe the same ``peripheral`` instance as ``ConnectionLifecycleObserver/init(peripheral:)``.
    ///   - catalog: Snapshot matching characteristics reachable through ``gatt``.
    ///   - peripheral: Exposed for callers that still need ``AsyncCoreBluetooth/Peripheral`` identity.
    package init(
        gatt: any GATTPeripheral,
        lifecycle: ConnectionLifecycleObserver,
        catalog: CharacteristicCatalog,
        peripheral: Peripheral
    ) async throws {
        self.peripheral = peripheral
        self.lifecycle = lifecycle
        self.gatt = gatt
        self.catalog = catalog
        startLifecycleObservation()

        let catalogCapture = catalog
        let gattCapture = gatt
        multiplexer = NotificationMultiplexer<NotificationSubscriptionKey>(
            upstream: { key in
                let characteristic = try catalogCapture.require(key.characteristic, in: key.service)
                _ = try await gattCapture.setNotify(true, for: characteristic)
                return gattCapture.valueStream(for: characteristic)
            },
            teardown: { key in
                guard let characteristic = try? catalogCapture.require(key.characteristic, in: key.service) else { return }
                try? await gattCapture.setNotify(false, for: characteristic)
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
        return try await gatt.read(characteristic)
    }

    package func write(
        _ data: Data,
        to uuid: CBUUID,
        in service: CBUUID,
        type: CBCharacteristicWriteType = .withResponse
    ) async throws {
        let characteristic = try requireCharacteristic(uuid, in: service)
        try await gatt.write(data, to: characteristic, type: type)
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
