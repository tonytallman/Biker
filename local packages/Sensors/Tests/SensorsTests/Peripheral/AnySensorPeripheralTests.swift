//
//  AnySensorPeripheralTests.swift
//  SensorsTests
//

import Foundation
import Sensors
import Testing

private func acceptHRS(_ delegate: HeartRateService.Delegate) {}

private func acceptCSC(_ delegate: CyclingSpeedAndCadenceService.Delegate) {}

private func acceptFTMS(_ delegate: FitnessMachineService.Delegate) {}

@Suite(.serialized)
struct AnySensorPeripheralTests {

    @Test func forwards_has_read_subscribe() async throws {
        let stub = RecordingSensorPeripheralStub()
        stub.hasResult = true
        stub.readResult = Data([0xAB, 0xCD])

        let any = stub.eraseToAnySensorPeripheral()

        #expect(await any.has(serviceId: SensorPeripheralStubIDs.service))
        #expect(await any.read(characteristicId: SensorPeripheralStubIDs.characteristic) == Data([0xAB, 0xCD]))

        let stream = any.subscribeTo(characteristicId: SensorPeripheralStubIDs.characteristic)
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

    @Test func eraseToAnySensorPeripheral_isIdempotent() {
        let stub = RecordingSensorPeripheralStub()
        let a = stub.eraseToAnySensorPeripheral()
        let b = a.eraseToAnySensorPeripheral()
        #expect(a === b)
    }

    @Test func acts_as_each_service_delegate() {
        let stub = RecordingSensorPeripheralStub()
        let erased = stub.eraseToAnySensorPeripheral()
        acceptHRS(erased)
        acceptCSC(erased)
        acceptFTMS(erased)
    }
}
