//
//  GATTPeripheralStub.swift
//  SensorsTests
//

import AsyncCoreBluetooth
import CoreBluetooth
import Foundation
import Sensors

enum GATTStubSentinelError: Error {
    case wrongCharacteristicWrite
}

/// Test double backed by real ``Characteristic`` references from CoreBluetoothMock (constructed elsewhere).
final class GATTPeripheralStub: GATTPeripheral, @unchecked Sendable {

    let catalog: CharacteristicCatalog
    private let primaryCharacteristic: Characteristic
    private let controlCharacteristic: Characteristic?

    var readPayload: Data = Data([0xAA])
    var readSleepNanoseconds: UInt64?
    var overlapDetector: OverlapDetector?
    var readThrows: Error?

    private(set) var lastWritePayload: Data?
    private(set) var lastNotifyEnabled: Bool?

    private let notifyContinuation: AsyncStream<Data>.Continuation
    private let notifyStream: AsyncStream<Data>

    init(
        catalog: CharacteristicCatalog,
        primaryCharacteristic: Characteristic,
        controlCharacteristic: Characteristic? = nil
    ) {
        self.catalog = catalog
        self.primaryCharacteristic = primaryCharacteristic
        self.controlCharacteristic = controlCharacteristic
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.notifyStream = stream
        self.notifyContinuation = continuation
    }

    deinit {
        notifyContinuation.finish()
    }

    func sendNotify(_ data: Data) {
        notifyContinuation.yield(data)
    }

    func discoverAll() async throws -> CharacteristicCatalog {
        catalog
    }

    func read(_ characteristic: Characteristic) async throws -> Data {
        overlapDetector?.enter()
        defer { overlapDetector?.leave() }
        if let readSleepNanoseconds {
            try? await Task.sleep(nanoseconds: readSleepNanoseconds)
        }
        guard ObjectIdentifier(characteristic) == ObjectIdentifier(primaryCharacteristic) else {
            throw SensorError.characteristicNotFound(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
        }
        if let readThrows {
            throw readThrows
        }
        return readPayload
    }

    func write(
        _ data: Data,
        to characteristic: Characteristic,
        type: CBCharacteristicWriteType
    ) async throws {
        guard let controlCharacteristic,
              ObjectIdentifier(characteristic) == ObjectIdentifier(controlCharacteristic) else {
            throw GATTStubSentinelError.wrongCharacteristicWrite
        }
        lastWritePayload = data
        _ = type
    }

    func setNotify(_ enabled: Bool, for characteristic: Characteristic) async throws {
        guard ObjectIdentifier(characteristic) == ObjectIdentifier(primaryCharacteristic) else {
            throw SensorError.characteristicNotFound(MockBLEPeripheral.measurementUUID, in: MockBLEPeripheral.serviceUUID)
        }
        lastNotifyEnabled = enabled
    }

    func valueStream(for characteristic: Characteristic) -> AsyncStream<Data> {
        guard ObjectIdentifier(characteristic) == ObjectIdentifier(primaryCharacteristic) else {
            return AsyncStream { continuation in
                continuation.finish()
            }
        }
        return notifyStream
    }
}
