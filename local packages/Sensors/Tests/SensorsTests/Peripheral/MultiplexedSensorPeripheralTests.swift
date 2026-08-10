//
//  MultiplexedSensorPeripheralTests.swift
//  SensorsTests
//

import Foundation
import Sensors
import Testing

@Suite(.serialized)
struct MultiplexedSensorPeripheralTests {

    @Test func mux_forwards_has_read() async throws {
        let stub = RecordingSensorPeripheralStub()
        stub.hasResult = true
        stub.readResult = Data([0xC0, 0xFF])

        let mux = MultiplexedSensorPeripheral(stub)

        #expect(await mux.has(serviceId: SensorPeripheralStubIDs.service))
        #expect(await mux.read(characteristicId: SensorPeripheralStubIDs.characteristic) == Data([0xC0, 0xFF]))
    }

    @Test func mux_subscribeTo_fansOutToMultipleSubscribers() async throws {
        let stub = RecordingSensorPeripheralStub()
        let mux = MultiplexedSensorPeripheral(stub)

        #expect(stub.subscribeCallCount == 0)

        let box1 = ValueBox<Data>()
        let box2 = ValueBox<Data>()
        let t1 = Task {
            for await v in mux.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic) {
                box1.store(v)
                break
            }
        }
        let t2 = Task {
            for await v in mux.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic) {
                box2.store(v)
                break
            }
        }
        defer {
            t1.cancel()
            t2.cancel()
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(stub.subscribeCallCount == 1)

        let payload = Data([0x10, 0x20])
        stub.send(payload)
        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(box1.load() == payload)
        #expect(box2.load() == payload)
    }

    @Test func mux_lastSubscriberCancellation_releasesUpstream() async throws {
        let stub = RecordingSensorPeripheralStub()
        let mux = MultiplexedSensorPeripheral(stub)

        do {
            let stream = mux.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic)
            let task = Task {
                for await _ in stream {}
            }
            try await Task.sleep(nanoseconds: 30_000_000)
            task.cancel()
        }

        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(stub.subscribeCallCount == 1)

        _ = mux.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic)
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(stub.subscribeCallCount == 2)
    }
}
