//
//  SerializedSensorPeripheralTests.swift
//  SensorsTests
//

import Foundation
import Sensors
import Testing

@Suite(.serialized)
struct SerializedSensorPeripheralTests {

    @Test func forwards_has_read_subscribe() async throws {
        let stub = RecordingSensorPeripheralStub()
        stub.hasResult = true
        stub.readResult = Data([0xAB, 0xCD])

        let decorator = SerializedSensorPeripheral(stub)

        #expect(await decorator.has(serviceId: SensorPeripheralStubIDs.service))
        #expect(await decorator.read(characteristicId: SensorPeripheralStubIDs.characteristic) == Data([0xAB, 0xCD]))

        let stream = decorator.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic)
        let box = ValueBox<Data>()
        let task = Task {
            for await value in stream {
                box.store(value)
                break
            }
        }
        defer { task.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)
        let payload = Data([0xFE, 0xED])
        stub.send(payload)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(box.load() == payload)
    }

    @Test func serializes_concurrent_reads() async throws {
        let detector = OverlapDetector()
        let stub = RecordingSensorPeripheralStub(
            overlapDetector: detector,
            readSleepNanoseconds: 2_000_000
        )

        let decorator = SerializedSensorPeripheral(stub)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 12 {
                group.addTask {
                    _ = await decorator.read(characteristicId: SensorPeripheralStubIDs.characteristic)
                }
            }
        }

        #expect(!detector.overlapOccurred)
    }

    @Test func subscribeTo_forwards_directly() async throws {
        let stub = RecordingSensorPeripheralStub()
        let decorator = SerializedSensorPeripheral(stub)

        // `AsyncStream` is not multi-consumer; compare decorator vs stub stream separately.
        let fromDecorator = decorator.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic)
        let decoratorBox = ValueBox<Data>()
        let decoratorTask = Task {
            for await value in fromDecorator {
                decoratorBox.store(value)
                break
            }
        }
        defer { decoratorTask.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)
        stub.send(Data([0x11, 0x22]))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(decoratorBox.load() == Data([0x11, 0x22]))

        let fromStub = stub.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic)
        let stubBox = ValueBox<Data>()
        let stubTask = Task {
            for await value in fromStub {
                stubBox.store(value)
                break
            }
        }
        defer { stubTask.cancel() }

        try await Task.sleep(nanoseconds: 20_000_000)
        stub.send(Data([0x33, 0x44]))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(stubBox.load() == Data([0x33, 0x44]))
    }
}
