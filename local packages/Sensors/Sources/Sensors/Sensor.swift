//
//  Sensor.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

import AsyncCoreBluetooth
@preconcurrency import Combine
import CoreBluetooth
import Foundation

// MARK: - Combine bootstrap

private struct NotificationKey: Hashable {
    let service: CBUUID
    let characteristic: CBUUID
}

/// Bundles notification pipeline pieces created on the actor for Combine ``subscribe``.
private struct SubscribeBootstrap: @unchecked Sendable {
    let key: NotificationKey
    let subject: PassthroughSubject<Data, Error>
}

/// Wraps Combine's `Future.Promise` until Apple marks it `@Sendable` (Swift 6 `sending` workaround).
private final class UncheckedFutureFulfill<Output, Failure: Error>: @unchecked Sendable {

    private let body: (Result<Output, Failure>) -> Void

    init(_ body: @escaping (Result<Output, Failure>) -> Void) {
        self.body = body
    }

    func invoke(_ result: Result<Output, Failure>) {
        body(result)
    }
}

// MARK: - Sensor actor

/// Wraps ``AsyncCoreBluetooth/Peripheral`` and exposes async read/write plus Combine notifications.
///
/// State is serialized through actor isolation; BLE delegate bridging lives in `AsyncCoreBluetooth`.
///
/// - Important: If multiple ``read`` calls on the same characteristic are in flight at once, completion
///   order is not guaranteed—issue reads sequentially when ordering matters.
package actor Sensor {

    nonisolated let peripheral: Peripheral

    /// Keyed by service UUID, then characteristic UUID.
    private var characteristics: [CBUUID: [CBUUID: Characteristic]] = [:]

    private var notificationSubjects: [NotificationKey: PassthroughSubject<Data, Error>] = [:]
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

        let subjects = notificationSubjects
        notificationSubjects.removeAll()
        notificationRefCount.removeAll()

        for (_, subject) in subjects {
            subject.send(completion: .failure(sensorError))
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

    package nonisolated func subscribe(
        to uuid: CBUUID,
        in service: CBUUID
    ) -> AnyPublisher<Data, Error> {
        let sensor = self
        return Combine.Deferred {
            Future<SubscribeBootstrap, Error> { promise in
                let fulfill = UncheckedFutureFulfill(promise)
                Task {
                    do {
                        let bootstrap = try await sensor.makeSubscribeBootstrap(for: uuid, in: service)
                        fulfill.invoke(.success(bootstrap))
                    } catch {
                        fulfill.invoke(.failure(error))
                    }
                }
            }
        }
        .map { bootstrap in
            bootstrap.subject
                .handleEvents(
                    receiveSubscription: { _ in
                        Task {
                            await sensor.incrementNotification(for: bootstrap.key)
                        }
                    },
                    receiveCancel: {
                        Task { await sensor.decrementNotification(for: bootstrap.key) }
                    }
                )
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    fileprivate func makeSubscribeBootstrap(for uuid: CBUUID, in service: CBUUID) async throws -> SubscribeBootstrap {
        _ = try requireCharacteristic(uuid, in: service)
        let key = NotificationKey(service: service, characteristic: uuid)
        let subject = prepareNotificationSubject(for: key)
        return SubscribeBootstrap(key: key, subject: subject)
    }

    private func prepareNotificationSubject(for key: NotificationKey) -> PassthroughSubject<Data, Error> {
        if let existing = notificationSubjects[key] {
            return existing
        }
        let created = PassthroughSubject<Data, Error>()
        notificationSubjects[key] = created
        return created
    }

    fileprivate func incrementNotification(for key: NotificationKey) async {
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
            notificationSubjects[key]?.send(completion: .failure(error))
            notificationSubjects[key] = nil
            return
        }

        notificationListenTasks[key] = Task {
            await self.runNotificationListeningLoop(key: key, characteristic: characteristic)
        }
    }

    fileprivate func decrementNotification(for key: NotificationKey) async {
        guard let current = notificationRefCount[key], current > 0 else { return }
        let next = current - 1
        if next == 0 {
            notificationRefCount[key] = nil
            notificationListenTasks[key]?.cancel()
            notificationListenTasks[key] = nil
            notificationSubjects[key] = nil

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
            notificationSubjects[key]?.send(data)
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
