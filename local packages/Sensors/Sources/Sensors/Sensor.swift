//
//  Sensor.swift
//  Sensors
//
//  Created by Tony Tallman on 5/5/26.
//

@preconcurrency import Combine
@preconcurrency import CoreBluetooth
import Foundation

// MARK: CoreBluetooth bridging (executor handoff only)

/// Tuples bridged CoreBluetooth callbacks into ``Sensor``. Use only immediately on arrival at the actor.
private struct UnsafeCharacteristicTuples: @unchecked Sendable {
    let tuples: [(CBUUID, CBCharacteristic)]
}

/// Notification pipeline bootstrap created on the actor, then surfaced to Combine synchronously via ``@unchecked Sendable``.
private struct SubscribeBootstrap: @unchecked Sendable {
    let characteristic: CBCharacteristic
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

// MARK: - Delegate forwarder

/// Bridges CoreBluetooth's delegate callbacks (non-async, non-isolated protocol) onto the ``Sensor`` actor.
fileprivate final class Forwarder: NSObject, CBPeripheralDelegate, @unchecked Sendable {

    weak var sensor: Sensor?

    override init() {
        super.init()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let sensor else { return }
        let mappedError = error.map { Sensor.mapError($0) }
        Task {
            await sensor.handleDidDiscoverServices(error: mappedError)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let sensor else { return }
        let serviceObjectId = ObjectIdentifier(service)
        let serviceUUID = service.uuid
        let characteristics: [(CBUUID, CBCharacteristic)] = (service.characteristics ?? []).map { ($0.uuid, $0) }
        let mappedError = error.map { Sensor.mapError($0) }
        Task {
            let boxed = UnsafeCharacteristicTuples(tuples: characteristics)
            await sensor.handleDidDiscoverCharacteristics(
                serviceObjectId: serviceObjectId,
                serviceUUID: serviceUUID,
                entries: boxed,
                error: mappedError
            )
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let sensor else { return }
        let charId = ObjectIdentifier(characteristic)
        let payload = characteristic.value ?? Data()
        let mappedError = error.map { Sensor.mapError($0) }
        Task {
            await sensor.handleDidUpdateValue(characteristicId: charId, payload: payload, error: mappedError)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let sensor else { return }
        let charId = ObjectIdentifier(characteristic)
        let mappedError = error.map { Sensor.mapError($0) }
        Task {
            await sensor.handleDidWriteValue(characteristicId: charId, error: mappedError)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let sensor else { return }
        let charId = ObjectIdentifier(characteristic)
        let mappedError = error.map { Sensor.mapError($0) }
        Task {
            await sensor.handleDidUpdateNotificationState(characteristicId: charId, error: mappedError)
        }
    }
}

// MARK: - Sensor actor

/// Owns `CBPeripheral`'s delegate (via ``Forwarder``) and exposes async read/write plus Combine notifies.
///
/// State is serialized through actor isolation; no mutex is required on the Swift side.
///
/// - Important: Delegate callbacks arrive as independent `Task`s on this actor. If multiple ``read`` calls on the
///   same characteristic are in flight at once, the order in which they complete is not guaranteed—issue reads
///   sequentially when ordering matters.
package actor Sensor {

    nonisolated let peripheral: CBPeripheral
    nonisolated private let forwarder: Forwarder

    /// Keyed by service UUID, then characteristic UUID.
    private var characteristics: [CBUUID: [CBUUID: CBCharacteristic]] = [:]

    private var readContinuations: [ObjectIdentifier: [CheckedContinuation<Data, Error>]] = [:]
    private var writeContinuations: [ObjectIdentifier: [CheckedContinuation<Void, Error>]] = [:]

    private var notificationSubjects: [ObjectIdentifier: PassthroughSubject<Data, Error>] = [:]
    private var notificationRefCount: [ObjectIdentifier: Int] = [:]

    // Discovery (init)
    private var discoverServicesContinuation: CheckedContinuation<Void, Error>?
    private var discoverCharacteristicsContinuation: CheckedContinuation<Void, Error>?
    private var discoverCharacteristicsServiceId: ObjectIdentifier?

    package init(peripheral: CBPeripheral) async throws {
        self.peripheral = peripheral
        self.forwarder = Forwarder()
        forwarder.sensor = self
        peripheral.delegate = forwarder

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.discoverServicesContinuation = continuation
            peripheral.discoverServices(nil)
        }
        discoverServicesContinuation = nil

        let services = peripheral.services ?? []
        for service in services {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.discoverCharacteristicsContinuation = continuation
                self.discoverCharacteristicsServiceId = ObjectIdentifier(service)
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
        discoverCharacteristicsContinuation = nil
        discoverCharacteristicsServiceId = nil
    }

    // MARK: Lookup

    package func has(service: CBUUID) -> Bool {
        characteristics[service] != nil
    }

    package func has(characteristic: CBUUID, in service: CBUUID) -> Bool {
        characteristics[service]?[characteristic] != nil
    }

    private func requireCharacteristic(_ uuid: CBUUID, in service: CBUUID) throws -> CBCharacteristic {
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
        let id = ObjectIdentifier(ch)
        return try await withCheckedThrowingContinuation { continuation in
            readContinuations[id, default: []].append(continuation)
            peripheral.readValue(for: ch)
        }
    }

    package func write(
        _ data: Data,
        to uuid: CBUUID,
        in service: CBUUID,
        type: CBCharacteristicWriteType = .withResponse
    ) async throws {
        let ch = try requireCharacteristic(uuid, in: service)
        let id = ObjectIdentifier(ch)
        switch type {
        case .withResponse:
            try await withCheckedThrowingContinuation { continuation in
                writeContinuations[id, default: []].append(continuation)
                peripheral.writeValue(data, for: ch, type: type)
            }
        case .withoutResponse:
            peripheral.writeValue(data, for: ch, type: type)
        @unknown default:
            peripheral.writeValue(data, for: ch, type: type)
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
                            await sensor.incrementNotification(
                                for: bootstrap.characteristic,
                                subject: bootstrap.subject
                            )
                        }
                    },
                    receiveCancel: {
                        Task { await sensor.decrementNotification(for: bootstrap.characteristic) }
                    }
                )
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    /// Bundles characteristic resolution and subject registration for Combine ``subscribe``.
    fileprivate func makeSubscribeBootstrap(for uuid: CBUUID, in service: CBUUID) async throws -> SubscribeBootstrap {
        let characteristic = try requireCharacteristic(uuid, in: service)
        let subject = prepareNotificationSubject(for: characteristic)
        return SubscribeBootstrap(characteristic: characteristic, subject: subject)
    }

    /// Returns the existing subject for this characteristic, or creates and stores one so every subscriber shares the same pipeline.
    private func prepareNotificationSubject(for char: CBCharacteristic) -> PassthroughSubject<Data, Error> {
        let id = ObjectIdentifier(char)
        if let existing = notificationSubjects[id] {
            return existing
        }
        let created = PassthroughSubject<Data, Error>()
        notificationSubjects[id] = created
        return created
    }

    fileprivate func incrementNotification(for char: CBCharacteristic, subject: PassthroughSubject<Data, Error>) {
        let id = ObjectIdentifier(char)
        let next = (notificationRefCount[id] ?? 0) + 1
        notificationRefCount[id] = next
        if next == 1 {
            // Ensure the live subject is the one we're using (may already be stored by prepareNotificationSubject).
            notificationSubjects[id] = subject
            peripheral.setNotifyValue(true, for: char)
        }
    }

    fileprivate func decrementNotification(for char: CBCharacteristic) {
        let id = ObjectIdentifier(char)
        guard let current = notificationRefCount[id], current > 0 else { return }
        let next = current - 1
        if next == 0 {
            notificationRefCount[id] = nil
            notificationSubjects[id] = nil
            peripheral.setNotifyValue(false, for: char)
        } else {
            notificationRefCount[id] = next
        }
    }

    // MARK: - Continuation helpers

    fileprivate nonisolated static func mapError(_ error: Error) -> SensorError {
        if let e = error as? SensorError { return e }
        return .underlying(error)
    }

    private func dequeueReadContinuation(for id: ObjectIdentifier) -> CheckedContinuation<Data, Error>? {
        guard var queue = readContinuations[id], !queue.isEmpty else { return nil }
        let first = queue.removeFirst()
        if queue.isEmpty {
            readContinuations[id] = nil
        } else {
            readContinuations[id] = queue
        }
        return first
    }

    private func dequeueWriteContinuation(for id: ObjectIdentifier) -> CheckedContinuation<Void, Error>? {
        guard var queue = writeContinuations[id], !queue.isEmpty else { return nil }
        let first = queue.removeFirst()
        if queue.isEmpty {
            writeContinuations[id] = nil
        } else {
            writeContinuations[id] = queue
        }
        return first
    }

    // MARK: Forwarder handlers

    fileprivate func handleDidDiscoverServices(error: SensorError?) async {
        guard let continuation = discoverServicesContinuation else { return }
        discoverServicesContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    fileprivate func handleDidDiscoverCharacteristics(
        serviceObjectId: ObjectIdentifier,
        serviceUUID: CBUUID,
        entries boxed: UnsafeCharacteristicTuples,
        error: SensorError?
    ) async {
        guard discoverCharacteristicsServiceId == serviceObjectId,
              let continuation = discoverCharacteristicsContinuation else { return }

        discoverCharacteristicsContinuation = nil
        discoverCharacteristicsServiceId = nil

        if let error {
            continuation.resume(throwing: error)
            return
        }

        var byChar = characteristics[serviceUUID] ?? [:]
        for (uuid, ch) in boxed.tuples {
            byChar[uuid] = ch
        }
        characteristics[serviceUUID] = byChar
        continuation.resume()
    }

    fileprivate func handleDidUpdateValue(
        characteristicId: ObjectIdentifier,
        payload: Data,
        error: SensorError?
    ) async {
        if let error {
            if let readContinuation = dequeueReadContinuation(for: characteristicId) {
                readContinuation.resume(throwing: error)
                return
            }
            notificationSubjects[characteristicId]?.send(completion: .failure(error))
            return
        }

        if let readContinuation = dequeueReadContinuation(for: characteristicId) {
            readContinuation.resume(returning: payload)
            return
        }
        notificationSubjects[characteristicId]?.send(payload)
    }

    fileprivate func handleDidWriteValue(characteristicId: ObjectIdentifier, error: SensorError?) async {
        guard let writeContinuation = dequeueWriteContinuation(for: characteristicId) else { return }
        if let error {
            writeContinuation.resume(throwing: error)
        } else {
            writeContinuation.resume()
        }
    }

    fileprivate func handleDidUpdateNotificationState(characteristicId: ObjectIdentifier, error: SensorError?) async {
        #if DEBUG
        if let error {
            debugPrint("Sensor: notification state update failed for characteristic object \(characteristicId): \(error)")
        }
        #endif
        if let error {
            notificationSubjects[characteristicId]?.send(completion: .failure(error))
        }
    }
}
