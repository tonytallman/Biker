//
//  Sensor.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation

// MARK: - Keys

private struct NotificationKey: Hashable {
    let service: CBUUID
    let characteristic: CBUUID
}

// MARK: - Sensor actor

/// Wraps ``AsyncCoreBluetooth/Peripheral`` and exposes async read/write plus notification ``AsyncThrowingStream``s.
///
/// State is serialized through actor isolation; BLE delegate bridging lives in `AsyncCoreBluetooth`.
///
/// - Important: If multiple ``read`` calls on the same characteristic are in flight at once, completion
///   order is not guaranteed—issue reads sequentially when ordering matters.
package actor Sensor {

    nonisolated let peripheral: Peripheral

    /// Keyed by service UUID, then characteristic UUID.
    private var characteristics: [CBUUID: [CBUUID: Characteristic]] = [:]

    private var notificationContinuations: [NotificationKey: [UUID: AsyncThrowingStream<Data, Error>.Continuation]] = [:]
    private var notificationRefCount: [NotificationKey: Int] = [:]
    private var notificationListenTasks: [NotificationKey: Task<Void, Never>] = [:]

    /// Observes ``Peripheral/connectionState`` so disconnect can tear down notification pipelines.
    /// Stored `nonisolated(unsafe)` so cancellation does not require actor `deinit` access rules.
    nonisolated(unsafe) private var connectionStateTask: Task<Void, Never>?

    package init(peripheral: Peripheral) async throws {
        self.peripheral = peripheral
        startConnectionStateObservation()
        try await discoverAllServicesAndCharacteristics()
    }

    private func discoverAllServicesAndCharacteristics() async throws {
        let services = try await mapErrors { try await peripheral.discoverServices(nil) }
        var map: [CBUUID: [CBUUID: Characteristic]] = [:]
        for (serviceUUID, service) in services {
            let chars = try await mapErrors {
                try await peripheral.discoverCharacteristics(nil, for: service)
            }
            map[serviceUUID] = chars
        }
        characteristics = map
    }

    private func mapErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            throw Self.mapError(error)
        }
    }

    /// Starts (or replaces) the disconnect observer. Safe to call once from ``init(peripheral:)``.
    private func startConnectionStateObservation() {
        connectionStateTask?.cancel()
        let watchedPeripheral = peripheral
        connectionStateTask = Task {
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
                        await handleDisconnect(cbError: cbError)
                        wasConnected = false
                    }
                default:
                    break
                }
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

        for (_, task) in notificationListenTasks {
            task.cancel()
        }
        notificationListenTasks.removeAll()

        let continuations = notificationContinuations
        notificationContinuations.removeAll()
        notificationRefCount.removeAll()

        for (_, perKey) in continuations {
            for (_, continuation) in perKey {
                continuation.finish(throwing: sensorError)
            }
        }
    }

    // MARK: Lookup

    package func has(service: CBUUID) -> Bool {
        characteristics[service] != nil
    }

    package func has(characteristic: CBUUID, in service: CBUUID) -> Bool {
        characteristics[service]?[characteristic] != nil
    }

    private func requireCharacteristic(_ uuid: CBUUID, in service: CBUUID) throws -> Characteristic {
        guard characteristics[service] != nil else {
            throw SensorError.serviceNotFound(service)
        }
        guard let ch = characteristics[service]?[uuid] else {
            throw SensorError.characteristicNotFound(uuid, in: service)
        }
        return ch
    }

    // MARK: Read / write

    package func read(_ uuid: CBUUID, in service: CBUUID) async throws -> Data {
        let ch = try requireCharacteristic(uuid, in: service)
        return try await mapErrors {
            try await peripheral.readValue(for: ch)
        }
    }

    package func write(
        _ data: Data,
        to uuid: CBUUID,
        in service: CBUUID,
        type: CBCharacteristicWriteType = .withResponse
    ) async throws {
        let ch = try requireCharacteristic(uuid, in: service)
        switch type {
        case .withResponse:
            try await mapErrors {
                try await peripheral.writeValueWithResponse(data, for: ch)
            }
        case .withoutResponse:
            await peripheral.writeValueWithoutResponse(data, for: ch)
        @unknown default:
            await peripheral.writeValueWithoutResponse(data, for: ch)
        }
    }

    // MARK: Subscribe

    package func subscribe(
        to uuid: CBUUID,
        in service: CBUUID
    ) async throws -> AsyncThrowingStream<Data, Error> {
        _ = try requireCharacteristic(uuid, in: service)
        let key = NotificationKey(service: service, characteristic: uuid)
        let subscriberID = UUID()

        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(64)
        )

        let sensor = self
        continuation.onTermination = { @Sendable _ in
            Task {
                await sensor.unregisterSubscriber(id: subscriberID, key: key)
            }
        }

        notificationContinuations[key, default: [:]][subscriberID] = continuation
        do {
            try await incrementNotification(for: key)
        } catch {
            notificationContinuations[key]?.removeValue(forKey: subscriberID)
            if notificationContinuations[key]?.isEmpty == true {
                notificationContinuations.removeValue(forKey: key)
            }
            throw error
        }

        return stream
    }

    private func unregisterSubscriber(id: UUID, key: NotificationKey) async {
        notificationContinuations[key]?.removeValue(forKey: id)
        if notificationContinuations[key]?.isEmpty == true {
            notificationContinuations.removeValue(forKey: key)
        }
        await decrementNotification(for: key)
    }

    private func incrementNotification(for key: NotificationKey) async throws {
        guard let characteristic = characteristics[key.service]?[key.characteristic] else { return }

        let next = (notificationRefCount[key] ?? 0) + 1
        notificationRefCount[key] = next

        guard next == 1 else { return }

        do {
            _ = try await mapErrors {
                try await peripheral.setNotifyValue(true, for: characteristic)
            }
        } catch {
            notificationRefCount[key] = nil
            let boxed = notificationContinuations[key] ?? [:]
            notificationContinuations.removeValue(forKey: key)
            let mapped = Self.mapError(error)
            for (_, continuation) in boxed {
                continuation.finish(throwing: mapped)
            }
            throw mapped
        }

        notificationListenTasks[key] = Task {
            await self.runNotificationListeningLoop(key: key, characteristic: characteristic)
        }
    }

    private func decrementNotification(for key: NotificationKey) async {
        guard let current = notificationRefCount[key], current > 0 else { return }
        let next = current - 1
        if next == 0 {
            notificationRefCount[key] = nil
            notificationListenTasks[key]?.cancel()
            notificationListenTasks[key] = nil
            notificationContinuations.removeValue(forKey: key)

            if let characteristic = characteristics[key.service]?[key.characteristic] {
                _ = try? await peripheral.setNotifyValue(false, for: characteristic)
            }
        } else {
            notificationRefCount[key] = next
        }
    }

    private func runNotificationListeningLoop(key: NotificationKey, characteristic: Characteristic) async {
        // Give AsyncObservable/stream registration a chance to run before mock-driven updates land.
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
            let subscribers = notificationContinuations[key] ?? [:]
            for (_, continuation) in subscribers {
                continuation.yield(data)
            }
        }
    }

    // MARK: Errors

    fileprivate nonisolated static func mapError(_ error: Error) -> SensorError {
        if let existing = error as? SensorError {
            return existing
        }
        if let peripheralError = error as? PeripheralConnectionError, peripheralError == .disconnectedWhileWorking {
            return .disconnected
        }
        return .underlying(error)
    }
}
