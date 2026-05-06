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

        var speed: Measurement<UnitSpeed>?
        let cancellable = service.speed?.sink { speed = $0 }

        // Flags wheel; revs and ticks UInt32/UInt16 LE
        delegate.measurementData.send(
            Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        )
        delegate.measurementData.send(
            Data([0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x04])
        )
        // delta revs 1, delta ticks 1024 -> 1 s -> 2 m/s

        cancellable?.cancel()

        #expect(speed != nil)
        #expect(speed?.converted(to: .metersPerSecond).value == 2.0)
    }

    @Test func crankCadenceFromTwoSamples() async throws {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = Data([0x02, 0x00]) // crank only

        let service = try #require(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil))
        #expect(service.speed == nil)

        var cadence: Measurement<UnitFrequency>?
        let cancellable = service.cadence?.sink { cadence = $0 }

        // Flags crank; revs UInt16, ticks UInt16
        delegate.measurementData.send(Data([0x02, 0x00, 0x00, 0x00, 0x00]))
        delegate.measurementData.send(Data([0x02, 0x0A, 0x00, 0x00, 0x28]))
        // delta revs 10, delta ticks 0x2800 = 10240 -> 10 s -> 60 rpm

        cancellable?.cancel()

        #expect(cadence?.unit == .revolutionsPerMinute)
        #expect(cadence?.value == 60.0)
    }

    @Test func skipsEmissionWhenDeltaTicksZero() async throws {
        let delegate = MockCyclingSpeedAndCadenceDelegate()
        delegate.featureCharacteristicValue = Data([0x02, 0x00])
        let service = try #require(await CyclingSpeedAndCadenceService(delegate: delegate, wheelCircumference: nil))

        var count = 0
        let cancellable = service.cadence?.sink { _ in count += 1 }

        delegate.measurementData.send(Data([0x02, 0x00, 0x00, 0x00, 0x00]))
        delegate.measurementData.send(Data([0x02, 0x05, 0x00, 0x00, 0x00])) // same time ticks

        cancellable?.cancel()
        #expect(count == 0)
    }
}
