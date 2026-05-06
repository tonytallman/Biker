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

        var received: Measurement<UnitFrequency>?
        let cancellable = service.heartRate.sink { received = $0 }

        // Flags 0: UInt8 HR; value 120 at byte 1
        delegate.heartRateData.send(Data([0x00, 120]))

        cancellable.cancel()

        #expect(received?.value == 120)
        #expect(received?.unit == .beatsPerMinute)
    }

    @Test func emitsUInt16LittleEndianHeartRate() async throws {
        let delegate = MockHeartRateDelegate()
        let service = try #require(await HeartRateService(delegate: delegate))

        var received: Measurement<UnitFrequency>?
        let cancellable = service.heartRate.sink { received = $0 }

        // Flags bit0: UInt16 HR (300 = 0x012C LE)
        delegate.heartRateData.send(Data([0x01, 0x2C, 0x01]))

        cancellable.cancel()

        #expect(received?.value == 300)
        #expect(received?.unit == .beatsPerMinute)
    }

    @Test func ignoresEmptyPacket() async throws {
        let delegate = MockHeartRateDelegate()
        let service = try #require(await HeartRateService(delegate: delegate))

        var count = 0
        let cancellable = service.heartRate.sink { _ in count += 1 }

        delegate.heartRateData.send(Data())
        delegate.heartRateData.send(Data([0x00])) // UInt8 mode but missing HR byte

        cancellable.cancel()

        #expect(count == 0)
    }
}
