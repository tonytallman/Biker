//
//  CyclingSpeedAndCadenceServiceTests.swift
//  Sensors
//
//  Created by Tony Tallman on 5/6/26.
//

import Foundation
import Testing

import Sensors

struct CyclingSpeedAndCadenceServiceTests {
    /// CSC Feature: UInt16 LE, wheel=0x01, crank=0x02.
    @Test func initReturnsNilWhenFeatureMissingOrNoCapability() async {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = nil
        #expect(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil) == nil)

        delegate.featureCharacteristicValue = Data([0x00, 0x00]) // no wheel, no crank
        #expect(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil) == nil)
    }

    @Test func initReturnsNilWhenWheelRequiredButCircumferenceNil() async {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = Data([0x01, 0x00]) // wheel only
        #expect(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil) == nil)
    }

    @Test func wheelSpeedFromTwoSamples() async throws {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = Data([0x01, 0x00]) // wheel only

        let circumference = Measurement(value: 2.0, unit: UnitLength.meters)
        let service = try #require(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: circumference))
        #expect(service.cadence == nil)

        let speedStream = try #require(service.speed)
        let box = ValueBox<Measurement<UnitSpeed>>()
        let task = Task {
            for await value in speedStream {
                box.store(value)
            }
        }

        // Flags wheel; revs and ticks UInt32/UInt16 LE
        delegate.sendMeasurement(
            Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        )
        delegate.sendMeasurement(
            Data([0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x04])
        )
        // delta revs 1, delta ticks 1024 -> 1 s -> 2 m/s

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(box.load() != nil)
        #expect(box.load()?.converted(to: .metersPerSecond).value == 2.0)
    }

    @Test func crankCadenceFromTwoSamples() async throws {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = Data([0x02, 0x00]) // crank only

        let service = try #require(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil))
        #expect(service.speed == nil)

        let cadenceStream = try #require(service.cadence)
        let box = ValueBox<Measurement<UnitFrequency>>()
        let task = Task {
            for await value in cadenceStream {
                box.store(value)
            }
        }

        // Flags crank; revs UInt16, ticks UInt16
        delegate.sendMeasurement(Data([0x02, 0x00, 0x00, 0x00, 0x00]))
        delegate.sendMeasurement(Data([0x02, 0x0A, 0x00, 0x00, 0x28]))
        // delta revs 10, delta ticks 0x2800 = 10240 -> 10 s -> 60 rpm

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(box.load()?.unit == .revolutionsPerMinute)
        #expect(box.load()?.value == 60.0)
    }

    @Test func skipsEmissionWhenDeltaTicksZero() async throws {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = Data([0x02, 0x00])
        let service = try #require(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil))

        let cadenceStream = try #require(service.cadence)
        let counter = EmissionCounter()
        let task = Task {
            for await _ in cadenceStream {
                counter.record()
            }
        }

        delegate.sendMeasurement(Data([0x02, 0x00, 0x00, 0x00, 0x00]))
        delegate.sendMeasurement(Data([0x02, 0x05, 0x00, 0x00, 0x00])) // same time ticks

        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        #expect(counter.value == 0)
    }
}
