//
//  HeartRateServiceTests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct HeartRateServiceTests {
    @Test func initReturnsNilWhenServiceMissing() async {
        let delegate = MockHeartRateDelegate()
        delegate.hasHeartRateService = false
        let service = await HeartRateService(delegate: delegate)
        #expect(service == nil)
    }

    @Test func emitsUInt8HeartRateInBeatsPerMinute() async throws {
        let delegate = MockHeartRateDelegate()
        let service = try #require(await HeartRateService(delegate: delegate))

        let box = ValueBox<Measurement<UnitFrequency>>()
        let task = Task {
            for await value in service.heartRate {
                box.store(value)
            }
        }

        // Flags 0: UInt8 HR; value 120 at byte 1
        delegate.send(Data([0x00, 120]))

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(box.load()?.value == 120)
        #expect(box.load()?.unit == .beatsPerMinute)
    }

    @Test func emitsUInt16LittleEndianHeartRate() async throws {
        let delegate = MockHeartRateDelegate()
        let service = try #require(await HeartRateService(delegate: delegate))

        let box = ValueBox<Measurement<UnitFrequency>>()
        let task = Task {
            for await value in service.heartRate {
                box.store(value)
            }
        }

        // Flags bit0: UInt16 HR (300 = 0x012C LE)
        delegate.send(Data([0x01, 0x2C, 0x01]))

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(box.load()?.value == 300)
        #expect(box.load()?.unit == .beatsPerMinute)
    }

    @Test func ignoresEmptyPacket() async throws {
        let delegate = MockHeartRateDelegate()
        let service = try #require(await HeartRateService(delegate: delegate))

        let counter = EmissionCounter()
        let task = Task {
            for await _ in service.heartRate {
                counter.record()
            }
        }

        delegate.send(Data())
        delegate.send(Data([0x00])) // UInt8 mode but missing HR byte

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(counter.value == 0)
    }
}
