//
//  FitnessMachineServiceTests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct FitnessMachineServiceTests {
    @Test func initReturnsNilWhenServiceOrFeatureMissing() async {
        let delegate = MockFitnessMachineDelegate()
        delegate.hasFitnessMachineService = false
        delegate.featureCharacteristicValue = Data([0x00, 0x00, 0x00, 0x00])
        #expect(await FitnessMachineService(delegate: delegate) == nil)

        delegate.hasFitnessMachineService = true
        delegate.featureCharacteristicValue = nil
        #expect(await FitnessMachineService(delegate: delegate) == nil)
    }

    @Test func optionalStreamsNilWhenCapabilitiesDisabled() async throws {
        let delegate = MockFitnessMachineDelegate()
        // Use word with no cadence/distance/hr/elapsed bits.
        delegate.featureCharacteristicValue = Data([0x00, 0x00, 0x00, 0x00])
        let service = try #require(await FitnessMachineService(delegate: delegate))
        #expect(service.cadence == nil)
        #expect(service.distance == nil)
        #expect(service.heartRate == nil)
        #expect(service.elapsedTime == nil)
    }

    @Test func indoorBikeInstantaneousSpeed() async throws {
        let delegate = MockFitnessMachineDelegate()
        delegate.featureCharacteristicValue = Data([0x00, 0x00, 0x00, 0x00])
        let service = try #require(await FitnessMachineService(delegate: delegate))

        let box = ValueBox<Measurement<UnitSpeed>>()
        let task = Task {
            for await value in service.speed {
                box.store(value)
            }
        }

        // Flags 0 -> speed present; 2500 raw -> 25 km/h
        delegate.sendIndoorBikeData(Data([0x00, 0x00, 0xC4, 0x09]))

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(box.load()?.value == 25.0)
        #expect(box.load()?.unit == .kilometersPerHour)
    }

    @Test func indoorBikeCadenceWhenCapabilityEnabled() async throws {
        let delegate = MockFitnessMachineDelegate()
        delegate.featureCharacteristicValue = Data([0x02, 0x00, 0x00, 0x00]) // cadence bit
        let service = try #require(await FitnessMachineService(delegate: delegate))

        let cadenceStream = try #require(service.cadence)
        let box = ValueBox<Measurement<UnitFrequency>>()
        let task = Task {
            for await value in cadenceStream {
                box.store(value)
            }
        }

        // More data (omit inst speed) + cadence: flags 0x0005 LE [0x05, 0x00]; cadence raw 100 -> 50 rpm
        delegate.sendIndoorBikeData(Data([0x05, 0x00, 0x64, 0x00]))

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(box.load()?.value == 50.0)
        #expect(box.load()?.unit == .revolutionsPerMinute)
    }

    @Test func indoorBikeDistanceHeartRateElapsed() async throws {
        let delegate = MockFitnessMachineDelegate()
        let featureWord = (1 << 2) | (1 << 10) | (1 << 12) // distance + HR + elapsed
        let featureLE = withUnsafeBytes(of: UInt32(featureWord).littleEndian, Array.init)
        delegate.featureCharacteristicValue = Data(featureLE)

        let service = try #require(await FitnessMachineService(delegate: delegate))

        let distanceBox = ValueBox<Measurement<UnitLength>>()
        let heartBox = ValueBox<Measurement<UnitFrequency>>()
        let elapsedBox = ValueBox<Measurement<UnitDuration>>()

        let distanceStream = try #require(service.distance)
        let heartStream = try #require(service.heartRate)
        let elapsedStream = try #require(service.elapsedTime)

        let dTask = Task {
            for await value in distanceStream {
                distanceBox.store(value)
            }
        }
        let hTask = Task {
            for await value in heartStream {
                heartBox.store(value)
            }
        }
        let eTask = Task {
            for await value in elapsedStream {
                elapsedBox.store(value)
            }
        }

        // Build flags: more data (0x01) | distance (0x10) | HR (0x200) | elapsed (0x800) = 0xA11
        let indoorFlags: UInt16 = 0x0001 | 0x0010 | 0x0200 | 0x0800
        var payload = Data()
        payload.append(contentsOf: withUnsafeBytes(of: indoorFlags.littleEndian, Array.init))
        // distance 250 m (3 bytes LE)
        payload.append(contentsOf: [250, 0, 0])
        // HR 140
        payload.append(140)
        // elapsed 60 s
        payload.append(contentsOf: withUnsafeBytes(of: UInt16(60).littleEndian, Array.init))

        delegate.sendIndoorBikeData(payload)

        try await Task.sleep(nanoseconds: 50_000_000)
        dTask.cancel()
        hTask.cancel()
        eTask.cancel()

        #expect(distanceBox.load()?.value == 250)
        #expect(distanceBox.load()?.unit == .meters)
        #expect(heartBox.load()?.value == 140)
        #expect(heartBox.load()?.unit == .beatsPerMinute)
        #expect(elapsedBox.load()?.value == 60)
        #expect(elapsedBox.load()?.unit == .seconds)
    }
}
