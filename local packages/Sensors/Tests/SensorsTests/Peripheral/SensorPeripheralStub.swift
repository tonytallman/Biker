//
//  SensorPeripheralStub.swift
//  SensorsTests
//

import Foundation
import Sensors

enum SensorPeripheralStubIDs {
    static let service = "180D"
    static let characteristic = "2A37"
}

final class OverlapDetector: @unchecked Sendable {
    private let lock = NSLock()
    private var depth = 0
    private var sawOverlap = false

    func enter() {
        lock.lock()
        depth += 1
        if depth > 1 {
            sawOverlap = true
        }
        lock.unlock()
    }

    func leave() {
        lock.lock()
        depth -= 1
        lock.unlock()
    }

    var overlapOccurred: Bool {
        lock.lock()
        defer { lock.unlock() }
        return sawOverlap
    }
}

final class RecordingSensorPeripheralStub: @unchecked Sendable {
    var hasResult = true
    var readResult: Data? = Data([0x01, 0x02])

    private let dataContinuation: AsyncStream<Data>.Continuation
    private let dataStream: AsyncStream<Data>

    private let overlapDetector: OverlapDetector?
    private let readSleepNanoseconds: UInt64?

    init(overlapDetector: OverlapDetector? = nil, readSleepNanoseconds: UInt64? = nil) {
        self.overlapDetector = overlapDetector
        self.readSleepNanoseconds = readSleepNanoseconds
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingNewest(64))
        self.dataStream = stream
        self.dataContinuation = continuation
    }

    func send(_ data: Data) {
        dataContinuation.yield(data)
    }

    deinit {
        dataContinuation.finish()
    }
}

extension RecordingSensorPeripheralStub: SensorPeripheral {
    func has(serviceId: String) async -> Bool {
        serviceId == SensorPeripheralStubIDs.service ? hasResult : false
    }

    func read(characteristicId: String) async -> Data? {
        overlapDetector?.enter()
        defer { overlapDetector?.leave() }
        if let readSleepNanoseconds {
            try? await Task.sleep(nanoseconds: readSleepNanoseconds)
        }
        return characteristicId == SensorPeripheralStubIDs.characteristic ? readResult : nil
    }

    func subscribeTo(characteristicId: String) -> AsyncStream<Data> {
        dataStream
    }
}
